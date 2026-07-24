import SwiftUI

@MainActor
struct NFCWriteView: View {
    let spaceName: String
    let url: URL?
    let onClose: () -> Void

    @StateObject private var model: NFCWriteViewModel
    @State private var writeTask: Task<Void, Never>?
    private let writerIsAvailable: Bool

    init(
        spaceName: String,
        url: URL?,
        writer: NFCWriting,
        onClose: @escaping () -> Void
    ) {
        self.spaceName = spaceName
        self.url = url
        self.onClose = onClose
        self.writerIsAvailable = writer.isAvailable
        self._model = StateObject(
            wrappedValue: NFCWriteViewModel(writer: writer)
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OnboardingBackground()

                VStack(spacing: 24) {
                    Spacer(minLength: 28)

                    VStack(spacing: 8) {
                        Text("写入 NFC 贴纸")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.16, green: 0.18, blue: 0.16))
                        Text(spaceName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    GlassSection(title: "NFC 贴纸") {
                        VStack(spacing: 24) {
                            Image(systemName: "wave.3.right.circle.fill")
                                .font(.system(size: 64, weight: .semibold))
                                .foregroundStyle(Color(red: 0.20, green: 0.48, blue: 0.30))

                            stateContent
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 148)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                    }

                    Spacer(minLength: 28)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color(red: 0.20, green: 0.32, blue: 0.25))
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("关闭")
                }
            }
        }
        .onDisappear {
            writeTask?.cancel()
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch displayedState {
        case .ready:
            VStack(spacing: 20) {
                statusText("将 iPhone 顶部靠近 NFC 贴纸")
                writeButton
            }
        case .writing:
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(Color(red: 0.20, green: 0.48, blue: 0.30))
                statusText("正在写入，请保持 iPhone 靠近贴纸。")
            }
        case .success:
            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(.green)
                statusText("NFC 贴纸已写入。")
            }
        case .domainUnavailable:
            statusText("配置正式 HTTPS 域名后即可写入 NFC 贴纸。")
        case .deviceUnavailable:
            statusText("请使用支持 NFC 的 iPhone 写入贴纸。")
        case let .failed(message):
            VStack(spacing: 18) {
                statusText(message)
                writeButton
            }
        }
    }

    private var displayedState: NFCWriteState {
        guard model.state == .ready else { return model.state }
        guard url != nil else { return .domainUnavailable }
        guard writerIsAvailable else { return .deviceUnavailable }
        return .ready
    }

    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(.body.weight(.medium))
            .foregroundStyle(Color(red: 0.22, green: 0.25, blue: 0.22))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .padding(.horizontal, 8)
    }

    private var writeButton: some View {
        Button(action: beginWrite) {
            Image(systemName: "wave.3.right")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 96, height: 96)
                .background(
                    Color(red: 0.18, green: 0.52, blue: 0.30),
                    in: Circle()
                )
                .shadow(
                    color: Color(red: 0.18, green: 0.52, blue: 0.30).opacity(0.24),
                    radius: 18,
                    y: 10
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("写入 NFC 贴纸")
    }

    private func beginWrite() {
        writeTask?.cancel()
        writeTask = Task {
            await model.write(url: url)
            writeTask = nil
        }
    }

    private func close() {
        writeTask?.cancel()
        onClose()
    }
}
