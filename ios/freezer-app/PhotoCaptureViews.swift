@preconcurrency import AVFoundation
import Combine
import PhotosUI
import SwiftUI
import UIKit

struct CameraImagePicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> CameraPresenterViewController {
        let controller = CameraPresenterViewController()
        controller.onImagePicked = onImagePicked
        controller.onFinish = {
            dismiss()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraPresenterViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {}
}

final class CameraPresenterViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    var onImagePicked: ((UIImage) -> Void)?
    var onFinish: (() -> Void)?

    private var hasPresentedPicker = false
    private lazy var picker: UIImagePickerController = {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        picker.allowsEditing = false
        picker.modalPresentationStyle = .fullScreen
        return picker
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        picker.loadViewIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !hasPresentedPicker else { return }
        hasPresentedPicker = true
        present(picker, animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) { [weak self] in
            self?.onFinish?()
        }
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        let image = info[.originalImage] as? UIImage
        picker.dismiss(animated: true) { [weak self] in
            if let image {
                self?.onImagePicked?(image)
            }
            self?.onFinish?()
        }
    }
}

struct PhotoCropView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onComplete: (UIImage) -> Void

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var cropSide: CGFloat = 0
    @GestureState private var pinchScale: CGFloat = 1
    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let availableWidth = max(proxy.size.width - 32, 220)
                let availableHeight = max(
                    proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom - 180,
                    220
                )
                let side = min(availableWidth, availableHeight)

                VStack(spacing: 0) {
                    Spacer(minLength: 16)

                    ZStack {
                        Color.black.ignoresSafeArea()

                        cropCanvas(side: side)
                    }
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.28), radius: 30, y: 18)
                    .onAppear {
                        cropSide = side
                    }
                    .onChange(of: side) { _, newValue in
                        cropSide = newValue
                    }

                    Text("Ausschnitt wählen")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.top, 28)

                    Text("Verschieben und zoomen, dann speichern.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.top, 6)

                    Spacer(minLength: 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen", action: onCancel)
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Verwenden") {
                        onComplete(croppedImage())
                    }
                    .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private func cropCanvas(side: CGFloat) -> some View {
        let currentScale = clampedScale(scale * pinchScale)
        let currentOffset = boundedOffset(for: offset + dragOffset, scale: currentScale, side: side)

        return Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(
                width: image.size.width * baseScale(for: side) * currentScale,
                height: image.size.height * baseScale(for: side) * currentScale
            )
            .offset(currentOffset)
            .gesture(
                SimultaneousGesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation
                        }
                        .onEnded { value in
                            offset = self.boundedOffset(for: offset + value.translation, scale: currentScale, side: side)
                        },
                    MagnifyGesture()
                        .updating($pinchScale) { value, state, _ in
                            state = value.magnification
                        }
                        .onEnded { value in
                            let newScale = clampedScale(scale * value.magnification)
                            scale = newScale
                            offset = self.boundedOffset(for: offset, scale: newScale, side: side)
                        }
                )
            )
            .animation(.snappy(duration: 0.18, extraBounce: 0), value: currentOffset)
    }

    private func croppedImage() -> UIImage {
        let side = cropSide > 0 ? cropSide : min(image.size.width, image.size.height)
        let baseScale = baseScale(for: side)
        let finalScale = clampedScale(scale)
        let displayedWidth = image.size.width * baseScale * finalScale
        let displayedHeight = image.size.height * baseScale * finalScale
        let bounded = boundedOffset(for: offset, scale: finalScale, side: side)

        let cropX = ((displayedWidth - side) / 2 - bounded.width) / (baseScale * finalScale)
        let cropY = ((displayedHeight - side) / 2 - bounded.height) / (baseScale * finalScale)
        let cropSide = side / (baseScale * finalScale)

        let cropRect = CGRect(
            x: max(0, min(image.size.width - cropSide, cropX)),
            y: max(0, min(image.size.height - cropSide, cropY)),
            width: min(cropSide, image.size.width),
            height: min(cropSide, image.size.height)
        )

        guard let cgImage = image.cgImage?.cropping(to: cropRect.scaled(by: image.scale)) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private func baseScale(for side: CGFloat) -> CGFloat {
        max(side / image.size.width, side / image.size.height)
    }

    private func clampedScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, 1), 4)
    }

    private func boundedOffset(for proposed: CGSize, scale: CGFloat, side: CGFloat) -> CGSize {
        let displayedWidth = image.size.width * baseScale(for: side) * scale
        let displayedHeight = image.size.height * baseScale(for: side) * scale
        let maxX = max((displayedWidth - side) / 2, 0)
        let maxY = max((displayedHeight - side) / 2, 0)

        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }
}

struct PhotoFullscreenView: View {
    let image: UIImage

    @Environment(\.dismiss) private var dismiss
    @State private var zoomScale: CGFloat = 1
    @State private var dismissOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            Color.black
                .ignoresSafeArea()
                .opacity(backgroundOpacity)

            ZoomingImageScrollView(image: image, zoomScale: $zoomScale)
                .scaleEffect(imageScale)
                .offset(y: dismissOffset)
                .simultaneousGesture(dismissDragGesture)

            HStack {
                Button("Fertig") {
                    dismiss()
                }
                .font(.body)
                .foregroundStyle(.white)

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .opacity(chromeOpacity)
        }
    }

    private var backgroundOpacity: Double {
        let progress = min(max(abs(dismissOffset) / 240, 0), 1)
        return 1 - (progress * 0.55)
    }

    private var chromeOpacity: Double {
        let progress = min(max(abs(dismissOffset) / 180, 0), 1)
        return 1 - (progress * 0.9)
    }

    private var imageScale: CGFloat {
        let progress = min(max(abs(dismissOffset) / 700, 0), 1)
        return 1 - (progress * 0.12)
    }

    private var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard zoomScale <= 1.01 else { return }
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                dismissOffset = value.translation.height
            }
            .onEnded { value in
                guard zoomScale <= 1.01 else { return }

                if abs(value.translation.height) > 140 || abs(value.velocity.height) > 1200 {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        dismissOffset = 0
                    }
                }
            }
    }
}

private struct ZoomingImageScrollView: UIViewRepresentable {
    let image: UIImage
    @Binding var zoomScale: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(zoomScale: $zoomScale)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .black
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.decelerationRate = .fast
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.frame = scrollView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.addSubview(imageView)

        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scrollView

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
        context.coordinator.updateLayout(in: scrollView)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        @Binding var zoomScale: CGFloat
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?

        init(zoomScale: Binding<CGFloat>) {
            _zoomScale = zoomScale
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            zoomScale = scrollView.zoomScale
            centerImage(in: scrollView)
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            zoomScale = scale
            centerImage(in: scrollView)
        }

        func updateLayout(in scrollView: UIScrollView) {
            guard let imageView else { return }

            let boundsSize = scrollView.bounds.size
            guard boundsSize.width > 0, boundsSize.height > 0 else { return }

            let imageSize = imageView.image?.size ?? .zero
            guard imageSize.width > 0, imageSize.height > 0 else { return }

            let imageRatio = imageSize.width / imageSize.height
            let viewRatio = boundsSize.width / boundsSize.height

            let fittedSize: CGSize
            if imageRatio > viewRatio {
                fittedSize = CGSize(width: boundsSize.width, height: boundsSize.width / imageRatio)
            } else {
                fittedSize = CGSize(width: boundsSize.height * imageRatio, height: boundsSize.height)
            }

            imageView.frame = CGRect(origin: .zero, size: fittedSize)
            scrollView.contentSize = fittedSize

            if scrollView.zoomScale < scrollView.minimumZoomScale || scrollView.zoomScale == 1 {
                scrollView.zoomScale = 1
                zoomScale = 1
            }

            centerImage(in: scrollView)
        }

        private func centerImage(in scrollView: UIScrollView) {
            guard let imageView else { return }

            let boundsSize = scrollView.bounds.size
            var frame = imageView.frame

            frame.origin.x = frame.size.width < boundsSize.width ? (boundsSize.width - frame.size.width) / 2 : 0
            frame.origin.y = frame.size.height < boundsSize.height ? (boundsSize.height - frame.size.height) / 2 : 0

            imageView.frame = frame
        }
    }
}

private extension CGSize {
    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
}

private extension CGRect {
    nonisolated func scaled(by scale: CGFloat) -> CGRect {
        CGRect(
            x: origin.x * scale,
            y: origin.y * scale,
            width: size.width * scale,
            height: size.height * scale
        ).integral
    }
}

nonisolated private func normalizedImage(_ image: UIImage) -> UIImage? {
    guard image.imageOrientation != .up else { return image }

    let renderer = UIGraphicsImageRenderer(size: image.size)
    return renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: image.size))
    }
}

nonisolated private func centerCroppedToSquare(_ image: UIImage) -> UIImage {
    guard let cgImage = image.cgImage else { return image }

    let side = min(image.size.width, image.size.height)
    let originX = (image.size.width - side) / 2
    let originY = (image.size.height - side) / 2
    let cropRect = CGRect(x: originX, y: originY, width: side, height: side).scaled(by: image.scale)

    guard let cropped = cgImage.cropping(to: cropRect) else { return image }
    return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
}
