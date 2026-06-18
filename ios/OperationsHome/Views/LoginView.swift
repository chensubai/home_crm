import SwiftUI

struct LoginView: View {
    @ObservedObject var session: SessionStore
    @State private var phone = ""
    @State private var code = ""
    @State private var name = ""
    @State private var message = ""

    var body: some View {
        ZStack {
            OnboardingBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    hero

                    VStack(spacing: 14) {
                        OnboardingTextField(
                            title: "手机号",
                            placeholder: "输入手机号",
                            text: $phone,
                            systemImage: "iphone"
                        )
                        .keyboardType(.phonePad)

                        HStack(spacing: 10) {
                            OnboardingTextField(
                                title: "验证码",
                                placeholder: "6 位验证码",
                                text: $code,
                                systemImage: "number"
                            )
                            .keyboardType(.numberPad)

                            Button {
                                Task { await sendCode() }
                            } label: {
                                Text("发送")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(width: 72, height: 52)
                            }
                            .buttonStyle(SoftSecondaryButtonStyle())
                            .disabled(phone.isEmpty)
                        }

                        OnboardingTextField(
                            title: "昵称",
                            placeholder: "家庭成员昵称",
                            text: $name,
                            systemImage: "person"
                        )
                    }

                    VStack(spacing: 10) {
                        Button {
                            Task { await login() }
                        } label: {
                            Label("进入运营小家", systemImage: "arrow.right")
                                .labelStyle(.titleAndIcon)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                        }
                        .buttonStyle(PrimaryOnboardingButtonStyle())
                        .disabled(phone.isEmpty || code.isEmpty)

                        Text(message.isEmpty ? "开发环境验证码默认为 123456" : message)
                            .font(.footnote)
                            .foregroundStyle(message.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 40)
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.white.opacity(0.72))
                    .frame(width: 104, height: 104)
                    .shadow(color: Color(red: 0.65, green: 0.45, blue: 0.25).opacity(0.14), radius: 24, y: 14)

                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.99, green: 0.82, blue: 0.50))
                        .frame(width: 56, height: 48)
                        .offset(x: -14, y: 9)
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.48, green: 0.67, blue: 0.58))
                        .frame(width: 46, height: 62)
                        .offset(x: 17, y: -4)
                    Image(systemName: "house.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("运营小家")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.16, green: 0.18, blue: 0.16))
                Text("把柜子、抽屉和日常提醒放进一个清爽的家庭空间。")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
        }
    }

    private func sendCode() async {
        do {
            try await APIClient().sendSms(phone: phone)
            message = "验证码已发送。开发环境默认 123456。"
        } catch {
            message = error.localizedDescription
        }
    }

    private func login() async {
        do {
            let response = try await APIClient().verifySms(phone: phone, code: code, name: name.isEmpty ? nil : name)
            session.token = response.token
            session.user = response.user
        } catch {
            message = error.localizedDescription
        }
    }
}

struct OnboardingBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.95, blue: 0.88),
                Color(red: 0.94, green: 0.97, blue: 0.92),
                Color(red: 0.96, green: 0.96, blue: 0.99)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct OnboardingTextField: View {
    var title: String
    var placeholder: String
    @Binding var text: String
    var systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(red: 0.50, green: 0.59, blue: 0.48))
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.body.weight(.medium))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
        .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 18, y: 10)
    }
}

struct PrimaryOnboardingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.20, green: 0.32, blue: 0.25))
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

struct SoftSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color(red: 0.20, green: 0.32, blue: 0.25))
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.62 : 0.86))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.75), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, y: 8)
    }
}
