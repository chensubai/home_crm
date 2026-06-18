import SwiftUI

struct ProfileView: View {
    @ObservedObject var session: SessionStore

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

                        profileHero

                        VStack(spacing: 12) {
                            ProfileInfoRow(
                                icon: "person.fill",
                                title: "昵称",
                                value: session.user?.name ?? "家庭成员"
                            )
                            ProfileInfoRow(
                                icon: "iphone",
                                title: "手机号",
                                value: session.user?.phone ?? "已登录"
                            )
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.70), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.06), radius: 18, y: 10)

                        VStack(spacing: 12) {
                            ProfileActionRow(
                                icon: "house.fill",
                                title: "家庭信息",
                                subtitle: "查看家庭名称、邀请成员和成员权限"
                            )
                            ProfileActionRow(
                                icon: "person.2.fill",
                                title: "成员管理",
                                subtitle: "创建人可以邀请或移除家庭成员"
                            )
                        }

                        Button(role: .destructive) {
                            session.token = nil
                            session.user = nil
                            session.selectedFamilyId = nil
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 17, weight: .semibold))
                                Text("退出登录")
                                    .font(.headline.weight(.semibold))
                                Spacer()
                            }
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
        }
    }

    private var profileHero: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.86, green: 0.92, blue: 0.78))
                    .frame(width: 76, height: 76)
                Text(avatarText)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.20, green: 0.32, blue: 0.25))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(session.user?.name ?? "家庭成员")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("运营小家的家庭管理员")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(18)
        .background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.70), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 18, y: 10)
    }

    private var avatarText: String {
        let name = session.user?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.first.map(String.init) ?? "家"
    }
}

private struct ProfileInfoRow: View {
    var icon: String
    var title: String
    var value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(red: 0.30, green: 0.48, blue: 0.36))
                .frame(width: 38, height: 38)
                .background(Color(red: 0.86, green: 0.92, blue: 0.78), in: Circle())
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
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
