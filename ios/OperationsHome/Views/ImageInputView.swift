import PhotosUI
import SwiftUI
import UIKit

enum AvatarImageProcessor {
    static let maxUploadBytes = 512_000

    static func squareCrop(image: UIImage, cropRect: CGRect) -> UIImage? {
        let normalized = normalizedImage(image)
        guard let cgImage = normalized.cgImage else { return nil }

        let imageScale = CGFloat(cgImage.width) / normalized.size.width
        let pixelRect = CGRect(
            x: cropRect.origin.x * imageScale,
            y: cropRect.origin.y * imageScale,
            width: cropRect.width * imageScale,
            height: cropRect.height * imageScale
        ).integral.intersection(CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))

        guard pixelRect.width > 0,
              pixelRect.height > 0,
              let cropped = cgImage.cropping(to: pixelRect) else { return nil }
        return UIImage(cgImage: cropped, scale: 1, orientation: .up)
    }

    static func compressedJPEG(from image: UIImage) -> Data? {
        let normalized = normalizedImage(image)
        var maxSide: CGFloat = 1024
        let qualities: [CGFloat] = [0.82, 0.70, 0.58, 0.46, 0.35, 0.20]

        while maxSide >= 128 {
            let resized = resizedImage(normalized, maxSide: maxSide)
            for quality in qualities {
                guard let data = resized.jpegData(compressionQuality: quality) else { continue }
                if data.count <= maxUploadBytes {
                    return data
                }
            }
            maxSide *= 0.75
        }

        let fallback = resizedImage(normalized, maxSide: 128)
        guard let data = fallback.jpegData(compressionQuality: 0.10), data.count <= maxUploadBytes else {
            return nil
        }
        return data
    }

    static func normalizedImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    static func resizedImage(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

enum ImageCropAspect {
    case space
    case item

    var ratio: CGFloat {
        switch self {
        case .space: 4 / 3
        case .item: 1
        }
    }
}

enum ImageCropProcessor {
    static let maxUploadBytes = 512_000

    static func centerCrop(image: UIImage, aspectRatio: CGFloat) -> UIImage? {
        let normalized = normalizedImage(image)
        let source = normalized.size
        guard source.width > 0, source.height > 0, aspectRatio > 0 else { return nil }

        let cropSize: CGSize
        if source.width / source.height > aspectRatio {
            cropSize = CGSize(width: source.height * aspectRatio, height: source.height)
        } else {
            cropSize = CGSize(width: source.width, height: source.width / aspectRatio)
        }
        return crop(
            image: normalized,
            cropRect: CGRect(
                x: (source.width - cropSize.width) / 2,
                y: (source.height - cropSize.height) / 2,
                width: cropSize.width,
                height: cropSize.height
            )
        )
    }

    static func crop(image: UIImage, cropRect: CGRect) -> UIImage? {
        let normalized = normalizedImage(image)
        guard let cgImage = normalized.cgImage else { return nil }
        let pixelScale = CGFloat(cgImage.width) / normalized.size.width
        let pixelRect = CGRect(
            x: cropRect.origin.x * pixelScale,
            y: cropRect.origin.y * pixelScale,
            width: cropRect.width * pixelScale,
            height: cropRect.height * pixelScale
        ).integral.intersection(CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        guard pixelRect.width > 0, pixelRect.height > 0, let cropped = cgImage.cropping(to: pixelRect) else {
            return nil
        }
        return UIImage(cgImage: cropped, scale: 1, orientation: .up)
    }

    static func compressedJPEG(from image: UIImage) -> Data? {
        let normalized = normalizedImage(image)
        var maxSide: CGFloat = 1024
        let qualities: [CGFloat] = [0.82, 0.70, 0.58, 0.46, 0.35, 0.20]
        while maxSide >= 128 {
            let resized = resizedImage(normalized, maxSide: maxSide)
            for quality in qualities {
                if let data = resized.jpegData(compressionQuality: quality), data.count <= maxUploadBytes {
                    return data
                }
            }
            maxSide *= 0.75
        }
        return nil
    }

    private static func normalizedImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
    }

    private static func resizedImage(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
}

struct ImageInputView: View {
    @Binding var imageData: Data?
    var existingImageURL: URL? = nil
    var cropAspect: ImageCropAspect
    var isUploading = false
    var onImageConfirmed: ((Data) -> Void)? = nil
    @State private var selectedItem: PhotosPickerItem?
    @State private var isShowingSourcePicker = false
    @State private var isShowingCamera = false
    @State private var isShowingCrop = false
    @State private var imageToCrop: UIImage?
    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            preview
            Button { isShowingSourcePicker = true } label: {
                Label("选择图片", systemImage: "photo.badge.plus")
            }
            .buttonStyle(.bordered)
            .disabled(isUploading)
            if !message.isEmpty {
                Text(message).font(.footnote).foregroundStyle(.red)
            }
        }
        .sheet(isPresented: $isShowingSourcePicker) {
            ImageSourcePicker(selectedItem: $selectedItem) {
                isShowingSourcePicker = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { isShowingCamera = true }
            }
            .presentationDetents([.height(210)])
        }
        .onChange(of: selectedItem) { _, item in
            guard item != nil else { return }
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    message = "图片读取失败，请选择另一张照片后重试。"
                    return
                }
                selectedItem = nil
                isShowingSourcePicker = false
                imageToCrop = image
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { isShowingCrop = true }
            }
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraPicker { image in
                imageToCrop = image
                isShowingCrop = true
            }
        }
        .sheet(isPresented: $isShowingCrop) {
            if let image = imageToCrop {
                ImageCropView(image: image, aspectRatio: cropAspect.ratio) { cropped in
                    imageData = ImageCropProcessor.compressedJPEG(from: cropped)
                    if let imageData {
                        message = ""
                        onImageConfirmed?(imageData)
                    } else {
                        message = "图片压缩失败，请选择另一张照片后重试。"
                    }
                    imageToCrop = nil
                    isShowingCrop = false
                }
            }
        }
    }

    @ViewBuilder private var preview: some View {
        if let imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image).resizable().scaledToFill()
                .aspectRatio(cropAspect.ratio, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 8))
        } else if let existingImageURL {
            AsyncImage(url: existingImageURL) { phase in
                if case let .success(image) = phase {
                    image.resizable().scaledToFill()
                        .aspectRatio(cropAspect.ratio, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 8))
                } else { placeholder }
            }
        } else { placeholder }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemGroupedBackground))
            .aspectRatio(cropAspect.ratio, contentMode: .fit)
            .overlay { Label("添加图片", systemImage: "photo.badge.plus").foregroundStyle(.secondary) }
    }
}

private struct ImageSourcePicker: View {
    @Binding var selectedItem: PhotosPickerItem?
    var onCamera: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            Text("选择图片").font(.headline)
            HStack(spacing: 14) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    ImageSourceOption(icon: "photo.on.rectangle", title: "相册")
                }.buttonStyle(.plain)
                Button(action: onCamera) { ImageSourceOption(icon: "camera", title: "拍照") }.buttonStyle(.plain)
            }
            Button("取消") { dismiss() }.font(.footnote).foregroundStyle(.secondary)
        }.padding(20)
    }
}

private struct ImageSourceOption: View {
    let icon: String
    let title: String
    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: icon).font(.system(size: 24, weight: .semibold))
            Text(title).font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(Color(red: 0.20, green: 0.32, blue: 0.25))
        .frame(maxWidth: .infinity).frame(height: 82)
        .background(Color(red: 0.86, green: 0.92, blue: 0.78), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ImageCropView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    let aspectRatio: CGFloat
    var onConfirm: (UIImage) -> Void
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let maxSize = CGSize(width: geometry.size.width - 40, height: geometry.size.height - 180)
                let cropSize = cropSize(in: maxSize)
                let baseScale = max(cropSize.width / image.size.width, cropSize.height / image.size.height)
                let displayedSize = CGSize(width: image.size.width * baseScale * scale, height: image.size.height * baseScale * scale)
                ZStack {
                    Color.black
                    Image(uiImage: image).resizable()
                        .frame(width: displayedSize.width, height: displayedSize.height).offset(offset)
                        .frame(width: cropSize.width, height: cropSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .contentShape(Rectangle())
                        .gesture(DragGesture().onChanged { value in
                            offset = clampedOffset(CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height), displayedSize: displayedSize, cropSize: cropSize)
                        }.onEnded { _ in lastOffset = offset })
                        .simultaneousGesture(MagnifyGesture().onChanged { value in
                            scale = min(max(lastScale * value.magnification, 1), 4)
                            offset = clampedOffset(offset, displayedSize: CGSize(width: image.size.width * baseScale * scale, height: image.size.height * baseScale * scale), cropSize: cropSize)
                        }.onEnded { _ in lastScale = scale; lastOffset = offset })
                    RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white, lineWidth: 2)
                        .frame(width: cropSize.width, height: cropSize.height).allowsHitTesting(false)
                }
                .frame(width: geometry.size.width, height: geometry.size.height).clipShape(Rectangle())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("使用") {
                        let cropRect = CGRect(
                            x: (image.size.width - cropSize.width / (baseScale * scale)) / 2 - offset.width / (baseScale * scale),
                            y: (image.size.height - cropSize.height / (baseScale * scale)) / 2 - offset.height / (baseScale * scale),
                            width: cropSize.width / (baseScale * scale), height: cropSize.height / (baseScale * scale)
                        )
                        if let cropped = ImageCropProcessor.crop(image: image, cropRect: cropRect) { onConfirm(cropped) }
                    } }
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("调整图片").navigationBarTitleDisplayMode(.inline)
        }
    }

    private func cropSize(in maximum: CGSize) -> CGSize {
        if maximum.width / maximum.height > aspectRatio {
            return CGSize(width: maximum.height * aspectRatio, height: maximum.height)
        }
        return CGSize(width: maximum.width, height: maximum.width / aspectRatio)
    }

    private func clampedOffset(_ value: CGSize, displayedSize: CGSize, cropSize: CGSize) -> CGSize {
        CGSize(
            width: min(max(value.width, -(displayedSize.width - cropSize.width) / 2), (displayedSize.width - cropSize.width) / 2),
            height: min(max(value.height, -(displayedSize.height - cropSize.height) / 2), (displayedSize.height - cropSize.height) / 2)
        )
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var onImage: (UIImage) -> Void
        var dismiss: DismissAction

        init(onImage: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImage = onImage
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                dismiss()
                DispatchQueue.main.async {
                    self.onImage(image)
                }
                return
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
