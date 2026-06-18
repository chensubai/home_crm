import PhotosUI
import SwiftUI
import UIKit

struct ImageInputView: View {
    private let maxUploadBytes = 5 * 1024 * 1024
    @Binding var imageData: Data?
    @State private var selectedItem: PhotosPickerItem?
    @State private var showingCamera = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            preview

            HStack {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("相册", systemImage: "photo")
                }
                .buttonStyle(.bordered)

                Button {
                    showingCamera = true
                } label: {
                    Label("拍照", systemImage: "camera")
                }
                .buttonStyle(.bordered)
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

                if imageData != nil {
                    Button(role: .destructive) {
                        imageData = nil
                        selectedItem = nil
                    } label: {
                        Label("移除", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                guard let data = try? await newItem?.loadTransferable(type: Data.self) else { return }
                imageData = compressedImageData(from: data)
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker { image in
                imageData = compressedImageData(from: image)
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemGroupedBackground))
                .frame(height: 132)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 30, weight: .semibold))
                        Text("添加图片")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                }
        }
    }

    private func compressedImageData(from data: Data) -> Data {
        guard let image = UIImage(data: data) else {
            return data
        }
        return compressedImageData(from: image) ?? data
    }

    private func compressedImageData(from image: UIImage) -> Data? {
        var maxSide: CGFloat = 1600
        var quality: CGFloat = 0.78

        while maxSide >= 800 {
            let resized = resizedImage(image, maxSide: maxSide)
            while quality >= 0.45 {
                guard let data = resized.jpegData(compressionQuality: quality) else { return nil }
                if data.count <= maxUploadBytes {
                    return data
                }
                quality -= 0.1
            }

            maxSide *= 0.8
            quality = 0.78
        }

        return resizedImage(image, maxSide: 720).jpegData(compressionQuality: 0.4)
    }

    private func resizedImage(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let originalSize = image.size
        let scale = min(1, maxSide / max(originalSize.width, originalSize.height))
        let targetSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
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
                onImage(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
