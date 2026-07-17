import SwiftUI

struct FamilyDetailView: View {
    @ObservedObject var session: SessionStore
    var familyId: Int
    var onFamilyUpdated: () async -> Void
    @State private var family: FamilyDTO?
    @State private var members: [FamilyMemberDTO] = []
    @State private var isLoading = false
    @State private var message = ""
    @State private var isEditingFamily = false
    @State private var isInvitingMember = false
    @State private var removingMember: FamilyMemberDTO?

    init(
        session: SessionStore,
        familyId: Int,
        initialFamily: FamilyDTO,
        onFamilyUpdated: @escaping () async -> Void
    ) {
        self._session = ObservedObject(wrappedValue: session)
        self.familyId = familyId
        self.onFamilyUpdated = onFamilyUpdated
        self._family = State(initialValue: initialFamily)
    }

    var body: some View {
        ZStack {
            OnboardingBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    familyHeader

                    GlassSection(title: "家庭资料") {
                        detailRow(title: "家庭名称", value: family?.name ?? "加载中")
                        Divider()
                        detailRow(title: "我的角色", value: roleTitle)
                        if let owner = members.first(where: { $0.role == "owner" }) {
                            Divider()
                            detailRow(title: "创建人", value: owner.name)
                        }
                    }

                    if isOwner {
                        HStack(spacing: 12) {
                            Button {
                                isEditingFamily = true
                            } label: {
                                Label("修改家庭名称", systemImage: "pencil")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                            }
                            .buttonStyle(SoftSecondaryButtonStyle())

                            Button {
                                isInvitingMember = true
                            } label: {
                                Label("邀请成员", systemImage: "person.badge.plus")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                            }
                            .buttonStyle(SoftSecondaryButtonStyle())
                        }
                    }

                    GlassSection(title: "家庭成员 · \(members.count)") {
                        if isLoading && members.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        } else if members.isEmpty {
                            Text("暂无成员")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        } else {
                            ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                                memberRow(member)
                                if index < members.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }

                    if !message.isEmpty {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
        }
        .navigationTitle("家庭详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .disabled(isLoading)
                .accessibilityLabel("刷新家庭成员")
            }
        }
        .task { await load() }
        .sheet(isPresented: $isEditingFamily) {
            if let family {
                FamilyNameEditView(session: session, family: family) { updatedFamily in
                    self.family = updatedFamily
                    Task { await onFamilyUpdated() }
                }
            }
        }
        .sheet(isPresented: $isInvitingMember) {
            InviteMemberView(session: session, familyId: familyId)
        }
        .alert(
            "移除成员",
            isPresented: Binding(
                get: { removingMember != nil },
                set: { if !$0 { removingMember = nil } }
            ),
            presenting: removingMember
        ) { member in
            Button("移除", role: .destructive) {
                Task { await remove(member) }
            }
            Button("取消", role: .cancel) {}
        } message: { member in
            Text("确定将“\(member.name)”移出当前家庭吗？")
        }
    }

    private var isOwner: Bool {
        family?.role == "owner"
    }

    private var roleTitle: String {
        isOwner ? "创建人" : "普通成员"
    }

    private var familyHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: "house.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color(red: 0.20, green: 0.32, blue: 0.25))
                .frame(width: 58, height: 58)
                .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(family?.name ?? "家庭")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(isOwner ? "你可以管理家庭资料和成员" : "你可以查看家庭资料和成员")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func memberRow(_ member: FamilyMemberDTO) -> some View {
        HStack(spacing: 12) {
            Text(member.name.trimmingCharacters(in: .whitespacesAndNewlines).first.map(String.init) ?? "家")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color(red: 0.20, green: 0.32, blue: 0.25))
                .frame(width: 42, height: 42)
                .background(Color(red: 0.86, green: 0.92, blue: 0.78), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(member.name)
                        .font(.headline)
                    if member.role == "owner" {
                        Text("创建人")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color(red: 0.30, green: 0.48, blue: 0.36))
                    }
                }
                Text(member.phone)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isOwner && member.role == "member" {
                Button(role: .destructive) {
                    removingMember = member
                } label: {
                    Image(systemName: "person.crop.circle.badge.minus")
                        .font(.system(size: 19, weight: .semibold))
                }
                .accessibilityLabel("移除成员 \(member.name)")
            }
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        guard let token = session.token else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let client = APIClient(token: token)
            async let familyList = client.families()
            async let memberList = client.familyMembers(familyId: familyId)
            let (families, loadedMembers) = try await (familyList, memberList)
            family = families.first(where: { $0.id == familyId }) ?? family
            members = loadedMembers
            message = ""
        } catch {
            message = error.localizedDescription
        }
    }

    private func remove(_ member: FamilyMemberDTO) async {
        guard isOwner, let token = session.token else { return }
        defer { removingMember = nil }

        do {
            try await APIClient(token: token).removeMember(familyId: familyId, memberId: member.id)
            members.removeAll { $0.id == member.id }
            message = ""
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct FamilyNameEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: SessionStore
    var family: FamilyDTO
    var onSaved: (FamilyDTO) -> Void
    @State private var name: String
    @State private var message = ""
    @State private var isSaving = false

    init(session: SessionStore, family: FamilyDTO, onSaved: @escaping (FamilyDTO) -> Void) {
        self._session = ObservedObject(wrappedValue: session)
        self.family = family
        self.onSaved = onSaved
        self._name = State(initialValue: family.name)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OnboardingBackground()
                VStack(spacing: 20) {
                    OnboardingTextField(title: "家庭名称", placeholder: "请输入家庭名称", text: $name, systemImage: "house")
                    if !message.isEmpty {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("修改家庭名称")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await save() } }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        guard let token = session.token else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let updated = try await APIClient(token: token).updateFamily(
                id: family.id,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            onSaved(updated)
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct InviteMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: SessionStore
    var familyId: Int
    @State private var phone = ""
    @State private var invite: FamilyInviteDTO?
    @State private var message = ""
    @State private var isSending = false

    var body: some View {
        NavigationStack {
            ZStack {
                OnboardingBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        FormHeaderView(
                            title: "邀请成员",
                            subtitle: "手机号可以留空。生成邀请码后，将它发给家庭成员。",
                            systemImage: "person.badge.plus"
                        )

                        OnboardingTextField(
                            title: "手机号",
                            placeholder: "可选",
                            text: $phone,
                            systemImage: "iphone"
                        )
                        .keyboardType(.phonePad)

                        Button {
                            Task { await createInvite() }
                        } label: {
                            Label(isSending ? "正在生成" : "生成邀请码", systemImage: "link.badge.plus")
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        }
                        .buttonStyle(PrimaryOnboardingButtonStyle())
                        .disabled(isSending)

                        if let invite {
                            GlassSection(title: "邀请码") {
                                Text(invite.code)
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(red: 0.20, green: 0.32, blue: 0.25))
                                    .frame(maxWidth: .infinity)
                                    .textSelection(.enabled)
                                Text("有效期至 \(InviteDateFormatter.chineseDateTime.string(from: invite.expiresAt))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        if !message.isEmpty {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func createInvite() async {
        guard let token = session.token else { return }
        isSending = true
        defer { isSending = false }

        do {
            let value = phone.trimmingCharacters(in: .whitespacesAndNewlines)
            invite = try await APIClient(token: token).inviteMember(
                familyId: familyId,
                phone: value.isEmpty ? nil : value
            )
            message = ""
        } catch {
            message = error.localizedDescription
        }
    }
}

private enum InviteDateFormatter {
    static let chineseDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter
    }()
}
