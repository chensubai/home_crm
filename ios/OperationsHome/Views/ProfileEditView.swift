import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: SessionStore
    @State private var name: String
    @State private var avatarData: Data?
    @State private var message = ""
    @State private var isSaving = false
    @State private var isUploadingAvatar = false

    init(session: SessionStore) {
        self._session = ObservedObject(wrappedValue: session)
        self._name = State(initialValue: session.user?.name ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OnboardingBackground()

                VStack(alignment: .leading, spacing: 20) {
                    AvatarPickerView(
                        imageData: $avatarData,
                        existingImageURL: existingAvatarURL,
                        isUploading: isUploadingAvatar,
                        onImageCropped: { imageData in
                            Task { await uploadAvatar(imageData) }
                        },
                        onImageLoadFailure: {
                            message = "图片读取失败，请选择另一张照片后重试。"
                        }
                    )

                    FormHeaderView(
                        title: "编辑个人资料",
                        subtitle: "修改昵称或选择一张新的个人头像。",
                        systemImage: "person.crop.circle"
                    )

                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "iphone")
                                .foregroundStyle(Color(red: 0.30, green: 0.48, blue: 0.36))
                                .frame(width: 38, height: 38)
                                .background(Color(red: 0.86, green: 0.92, blue: 0.78), in: Circle())
                            Text("手机号")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(session.user?.phone ?? "已登录")
                                .font(.subheadline.weight(.bold))
                        }
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.70), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 18, y: 10)

                    OnboardingTextField(
                        title: "昵称",
                        placeholder: "请输入昵称",
                        text: $name,
                        systemImage: "person.fill"
                    )

                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if !message.isEmpty {
                                Text(message)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 34)
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
                    .disabled(isSaving || isUploadingAvatar)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                    }
                    .tint(Color(red: 0.20, green: 0.32, blue: 0.25))
                    .accessibilityLabel("保存")
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving || isUploadingAvatar)
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

    private func uploadAvatar(_ imageData: Data) async {
        guard let token = session.token else { return }
        isUploadingAvatar = true
        message = ""
        defer { isUploadingAvatar = false }

        do {
            session.user = try await APIClient(token: token).updateProfile(avatarData: imageData)
            avatarData = nil
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct AvatarPickerView: View {
    @Binding var imageData: Data?
    var existingImageURL: URL?
    var isUploading: Bool
    var onImageCropped: (Data) -> Void
    var onImageLoadFailure: () -> Void
    @State private var selectedItem: PhotosPickerItem?
    @State private var isShowingSourcePicker = false
    @State private var isShowingCamera = false
    @State private var isShowingCrop = false
    @State private var imageToCrop: UIImage?

    var body: some View {
        VStack(spacing: 10) {
            Button {
                isShowingSourcePicker = true
            } label: {
                avatar
                    .overlay(alignment: .bottomTrailing) {
                        Group {
                            if isUploading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                            .frame(width: 38, height: 38)
                            .background(Color(red: 0.20, green: 0.32, blue: 0.25), in: Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("更换个人头像")
            .disabled(isUploading)

            Text("点击头像更换")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $isShowingSourcePicker) {
            AvatarSourcePicker(
                selectedItem: $selectedItem,
                canRemoveImage: imageData != nil,
                onCamera: presentCamera,
                onRemove: {
                    imageData = nil
                    selectedItem = nil
                    isShowingSourcePicker = false
                }
            )
            .presentationDetents([.height(imageData == nil ? 210 : 250)])
        }
        .onChange(of: selectedItem) { _, newItem in
            guard newItem != nil else { return }
            Task {
                guard let image = await loadImage(from: newItem) else {
                    onImageLoadFailure()
                    return
                }
                selectedItem = nil
                isShowingSourcePicker = false
                imageToCrop = image
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isShowingCrop = true
                }
            }
        }
        .sheet(isPresented: $isShowingCrop) {
            if let image = imageToCrop {
                AvatarCropView(image: image) { croppedImage in
                    imageData = AvatarImageProcessor.compressedJPEG(from: croppedImage)
                    if let imageData {
                        onImageCropped(imageData)
                    }
                    imageToCrop = nil
                    isShowingCrop = false
                }
            }
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraPicker { image in
                imageToCrop = image
                isShowingCrop = true
            }
        }
    }

    private func presentCamera() {
        isShowingSourcePicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isShowingCamera = true
        }
    }

    private func loadImage(from item: PhotosPickerItem?) async -> UIImage? {
        guard let item else { return nil }

        if let transferableImage = try? await item.loadTransferable(type: AvatarTransferableImage.self) {
            return transferableImage.image
        }

        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
        return UIImage(data: data)
    }

    @ViewBuilder
    private var avatar: some View {
        if let imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 132, height: 132)
                .clipShape(Circle())
        } else if let existingImageURL {
            AsyncImage(url: existingImageURL) { phase in
                if case let .success(image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    avatarPlaceholder
                }
            }
            .frame(width: 132, height: 132)
            .clipShape(Circle())
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Image(systemName: "person.crop.circle.fill")
            .font(.system(size: 132))
            .foregroundStyle(Color(red: 0.50, green: 0.59, blue: 0.48))
            .frame(width: 132, height: 132)
            .background(Color.white.opacity(0.84), in: Circle())
    }
}

private struct AvatarSourcePicker: View {
    @Binding var selectedItem: PhotosPickerItem?
    var canRemoveImage: Bool
    var onCamera: () -> Void
    var onRemove: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("更换个人头像")
                .font(.headline)

            HStack(spacing: 14) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    AvatarSourceOption(icon: "photo.on.rectangle", title: "相册")
                }
                .buttonStyle(.plain)

                Button(action: onCamera) {
                    AvatarSourceOption(icon: "camera", title: "拍照")
                }
                .buttonStyle(.plain)
            }

            if canRemoveImage {
                Button("移除当前图片", role: .destructive, action: onRemove)
                    .font(.footnote)
            }

            Button("取消") { dismiss() }
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }
}

private struct AvatarSourceOption: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(Color(red: 0.20, green: 0.32, blue: 0.25))
        .frame(maxWidth: .infinity)
        .frame(height: 82)
        .background(Color(red: 0.86, green: 0.92, blue: 0.78), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct AvatarTransferableImage: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let image = UIImage(data: data) else {
                throw AvatarTransferableImageError.invalidImageData
            }
            return AvatarTransferableImage(image: image)
        }
    }
}

private enum AvatarTransferableImageError: Error {
    case invalidImageData
}

private struct AvatarCropView: View {
    private let minimumImageScale: CGFloat = 1
    private let maximumImageScale: CGFloat = 4
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    var onConfirm: (UIImage) -> Void
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let side = min(geometry.size.width - 40, geometry.size.height - 180)
                let baseScale = max(side / image.size.width, side / image.size.height)
                let displayedSize = CGSize(
                    width: image.size.width * baseScale * scale,
                    height: image.size.height * baseScale * scale
                )

                ZStack {
                    Color.black

                    Image(uiImage: image)
                        .resizable()
                        .frame(width: displayedSize.width, height: displayedSize.height)
                        .offset(offset)
                        .frame(width: side, height: side)
                        .clipShape(Circle())
                        .contentShape(Circle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = clampedOffset(
                                        CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        ),
                                        displayedSize: displayedSize,
                                        cropSide: side
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .simultaneousGesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    scale = min(
                                        max(lastScale * value.magnification, minimumImageScale),
                                        maximumImageScale
                                    )
                                    offset = clampedOffset(offset, displayedSize: CGSize(
                                        width: image.size.width * baseScale * scale,
                                        height: image.size.height * baseScale * scale
                                    ), cropSide: side)
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    lastOffset = offset
                                }
                        )

                    Circle()
                        .stroke(.white, lineWidth: 2)
                        .frame(width: side, height: side)
                        .allowsHitTesting(false)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipShape(Rectangle())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("使用") {
                            let cropSize = side / (baseScale * scale)
                            let cropRect = CGRect(
                                x: (image.size.width - cropSize) / 2 - offset.width / (baseScale * scale),
                                y: (image.size.height - cropSize) / 2 - offset.height / (baseScale * scale),
                                width: cropSize,
                                height: cropSize
                            )
                            if let cropped = AvatarImageProcessor.squareCrop(image: image, cropRect: cropRect) {
                                onConfirm(cropped)
                            }
                        }
                    }
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("调整头像")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func clampedOffset(_ proposed: CGSize, displayedSize: CGSize, cropSide: CGFloat) -> CGSize {
        let horizontalLimit = max(0, (displayedSize.width - cropSide) / 2)
        let verticalLimit = max(0, (displayedSize.height - cropSide) / 2)
        return CGSize(
            width: min(max(proposed.width, -horizontalLimit), horizontalLimit),
            height: min(max(proposed.height, -verticalLimit), verticalLimit)
        )
    }
}
