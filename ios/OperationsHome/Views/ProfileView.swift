import SwiftUI

struct ProfileView: View {
    @ObservedObject var session: SessionStore
    var family: FamilyDTO?
    var onFamilyUpdated: () async -> Void
    @State private var isEditingProfile = false
    @State private var isSubmittingFeedback = false

    var body: some View {
        NavigationStack {
            ZStack {
                OnboardingBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("个人中心")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(red: 0.16, green: 0.18, blue: 0.16))
                            Text("维护你的账号、家庭资料和成员协作。")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            isEditingProfile = true
                        } label: {
                            profileHero
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("编辑个人资料")

                        if let family {
                            VStack(spacing: 12) {
                                familyLink(
                                    family: family,
                                    icon: "house.fill",
                                    title: "家庭信息",
                                    subtitle: "查看家庭资料和成员",
                                    mode: .settings
                                )
                                if FamilyScreenPermissions.showsMemberManagementEntry(role: family.role) {
                                    familyLink(
                                        family: family,
                                        icon: "person.2.fill",
                                        title: "成员管理",
                                        subtitle: "邀请或移除家庭成员",
                                        mode: .memberManagement
                                    )
                                }
                            }
                        }

                        Button {
                            isSubmittingFeedback = true
                        } label: {
                            ProfileActionRow(
                                icon: "bubble.left.and.bubble.right",
                                title: "意见反馈",
                                subtitle: "告诉我们你的建议或遇到的问题"
                            )
                        }
                        .buttonStyle(.plain)

                        Button(role: .destructive) {
                            session.token = nil
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 17, weight: .semibold))
                                Text("退出登录")
                                    .font(.headline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.red)
                            .padding(16)
                            .background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Color.white.opacity(0.70), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.05), radius: 16, y: 10)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isEditingProfile) {
                ProfileEditView(session: session)
            }
            .sheet(isPresented: $isSubmittingFeedback) {
                FeedbackView(session: session)
            }
        }
    }

    private func familyLink(
        family: FamilyDTO,
        icon: String,
        title: String,
        subtitle: String,
        mode: FamilyDetailMode
    ) -> some View {
        NavigationLink {
            FamilyDetailView(
                session: session,
                familyId: family.id,
                initialFamily: family,
                mode: mode,
                onFamilyUpdated: onFamilyUpdated
            )
        } label: {
            ProfileActionRow(icon: icon, title: title, subtitle: subtitle)
        }
        .buttonStyle(.plain)
    }

    private var profileHero: some View {
        HStack(spacing: 16) {
            avatar

            VStack(alignment: .leading, spacing: 5) {
                Text(session.user?.name ?? "家庭成员")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(family?.role == "owner" ? "家庭创建人" : "家庭成员")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "pencil")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.70), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 18, y: 10)
    }

    @ViewBuilder
    private var avatar: some View {
        if let url = avatarURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    avatarFallback
                }
            }
            .frame(width: 76, height: 76)
            .clipShape(Circle())
        } else {
            avatarFallback
        }
    }

    private var avatarFallback: some View {
        Text(avatarText)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.20, green: 0.32, blue: 0.25))
            .frame(width: 76, height: 76)
            .background(Color(red: 0.86, green: 0.92, blue: 0.78), in: Circle())
    }

    private var avatarURL: URL? {
        guard let value = (session.user?.avatarThumbnailUrl ?? session.user?.avatarUrl)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return URL(string: value)
    }

    private var avatarText: String {
        let name = session.user?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.first.map(String.init) ?? "家"
    }
}

private struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: SessionStore
    @State private var content = ""
    @State private var isSubmitting = false
    @State private var message = ""

    var body: some View {
        NavigationStack {
            ZStack {
                OnboardingBackground()

                VStack(alignment: .leading, spacing: 20) {
                    FormHeaderView(
                        title: "意见反馈",
                        subtitle: "欢迎告诉我们你的建议或遇到的问题。",
                        systemImage: "bubble.left.and.bubble.right"
                    )

                    GlassSection(title: "反馈内容") {
                        TextEditor(text: $content)
                            .frame(minHeight: 180)
                            .scrollContentBackground(.hidden)
                            .overlay(alignment: .topLeading) {
                                if content.isEmpty {
                                    Text("请输入反馈内容")
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 8)
                                        .allowsHitTesting(false)
                                }
                            }
                    }

                    if !message.isEmpty {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                    }
                    .tint(Color(red: 0.20, green: 0.32, blue: 0.25))
                    .accessibilityLabel("取消")
                    .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        guard !isSubmitting else { return }
                        isSubmitting = true
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24, weight: .semibold))
                        }
                    }
                    .tint(Color(red: 0.20, green: 0.32, blue: 0.25))
                    .accessibilityLabel("提交")
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
            }
        }
    }

    private func submit() async {
        guard let token = session.token else {
            isSubmitting = false
            return
        }

        do {
            try await APIClient(token: token).submitFeedback(
                content: content.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            dismiss()
        } catch {
            message = error.localizedDescription
            isSubmitting = false
        }
    }
}

private struct ProfileActionRow: View {
    var icon: String
    var title: String
    var subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(red: 0.30, green: 0.48, blue: 0.36))
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.76), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.70), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 16, y: 10)
    }
}
