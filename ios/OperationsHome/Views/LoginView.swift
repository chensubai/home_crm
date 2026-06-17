import SwiftUI

struct LoginView: View {
    @ObservedObject var session: SessionStore
    @State private var phone = ""
    @State private var code = ""
    @State private var name = ""
    @State private var message = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("手机号登录") {
                    TextField("手机号", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("验证码", text: $code)
                        .keyboardType(.numberPad)
                    TextField("昵称", text: $name)
                }

                Button("发送验证码") {
                    Task { await sendCode() }
                }

                Button("登录") {
                    Task { await login() }
                }
                .disabled(phone.isEmpty || code.isEmpty)

                if !message.isEmpty {
                    Text(message).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("运营小家")
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
