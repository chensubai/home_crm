import SwiftUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: SessionStore
    @State private var name: String
    @State private var avatarData: Data?
    @State private var message = ""
    @State private var isSaving = false

    init(session: SessionStore) {
        self._session = ObservedObject(wrappedValue: session)
        self._name = State(initialValue: session.user?.name ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OnboardingBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        FormHeaderView(
                            title: "编辑个人资料",
                            subtitle: "修改昵称或选择一张新的个人头像。",
                            systemImage: "person.crop.circle"
                        )

                        OnboardingTextField(
                            title: "昵称",
                            placeholder: "请输入昵称",
                            text: $name,
                            systemImage: "person.fill"
                        )

                        GlassSection(title: "个人头像") {
                            ImageInputView(imageData: $avatarData, existingImageURL: existingAvatarURL)
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
                    Button("取消") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await save() } }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }

    private var existingAvatarURL: URL? {
        guard let value = session.user?.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return URL(string: value)
    }

    private func save() async {
        guard let token = session.token else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            session.user = try await APIClient(token: token).updateProfile(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                avatarData: avatarData
            )
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}
