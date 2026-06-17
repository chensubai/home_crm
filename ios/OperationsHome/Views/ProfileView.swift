import SwiftUI

struct ProfileView: View {
    @ObservedObject var session: SessionStore

    var body: some View {
        NavigationStack {
            List {
                Section("账号") {
                    if let user = session.user {
                        LabeledContent("昵称", value: user.name)
                        LabeledContent("手机号", value: user.phone)
                    } else {
                        Text("已登录")
                    }
                }

                Section {
                    Button("退出登录", role: .destructive) {
                        session.token = nil
                        session.user = nil
                        session.selectedFamilyId = nil
                    }
                }
            }
            .navigationTitle("个人中心")
        }
    }
}
