//
//  ScanView.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import SwiftUI
import Vision
import VisionKit

struct ScanView: View {
    @State private var recognizedCode: String?
    @State private var scannerMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported {
                    scannerContent
                } else {
                    scannerUnavailableView(
                        title: "Scanner nicht unterstützt",
                        message: "Dieses Gerät unterstützt den nativen Code-Scanner nicht."
                    )
                }
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
            .alert(
                "Code erkannt",
                isPresented: recognizedCodeAlertBinding,
                presenting: recognizedCode
            ) { _ in
                Button("OK") {
                    recognizedCode = nil
                }
            } message: { code in
                Text(code)
            }
            .alert(
                "Scanner nicht verfügbar",
                isPresented: scannerMessageAlertBinding,
                presenting: scannerMessage
            ) { _ in
                Button("OK") {
                    scannerMessage = nil
                }
            } message: { message in
                Text(message)
            }
        }
    }

    private var scannerContent: some View {
        ZStack(alignment: .bottom) {
            BarcodeScannerView(
                isPaused: recognizedCode != nil,
                onRecognized: { code in
                    recognizedCode = code
                },
                onFailure: { message in
                    scannerMessage = message
                }
            )
            .ignoresSafeArea(edges: .bottom)

            scannerHint
        }
        .background(Color.black.ignoresSafeArea())
    }

    private var scannerHint: some View {
        VStack(spacing: 10) {
            Text("Barcode scannen")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Zum Testen wird der erkannte Code direkt als Hinweis angezeigt.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.42))
    }

    private func scannerUnavailableView(title: String, message: String) -> some View {
        ContentUnavailableView(
            title,
            systemImage: "barcode.viewfinder",
            description: Text(message)
        )
    }

    private var recognizedCodeAlertBinding: Binding<Bool> {
        Binding(
            get: { recognizedCode != nil },
            set: { isPresented in
                if !isPresented {
                    recognizedCode = nil
                }
            }
        )
    }

    private var scannerMessageAlertBinding: Binding<Bool> {
        Binding(
            get: { scannerMessage != nil },
            set: { isPresented in
                if !isPresented {
                    scannerMessage = nil
                }
            }
        )
    }
}

private struct BarcodeScannerView: UIViewControllerRepresentable {
    let isPaused: Bool
    let onRecognized: (String) -> Void
    let onFailure: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onRecognized: onRecognized, onFailure: onFailure)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [
                .barcode(symbologies: [.ean13, .ean8, .upce, .code39, .code128, .qr, .aztec, .pdf417])
            ],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        context.coordinator.attach(to: scanner)
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        context.coordinator.isPaused = isPaused
        context.coordinator.ensureScanningState(for: uiViewController)
        context.coordinator.startObservingIfNeeded()
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onRecognized: (String) -> Void
        let onFailure: (String) -> Void

        var isPaused = false
        private weak var scanner: DataScannerViewController?
        private var lastRecognizedCode: String?

        init(onRecognized: @escaping (String) -> Void, onFailure: @escaping (String) -> Void) {
            self.onRecognized = onRecognized
            self.onFailure = onFailure
        }

        func attach(to scanner: DataScannerViewController) {
            self.scanner = scanner
        }

        func startObservingIfNeeded() {
            // Delegate callbacks are sufficient for the first scanner step.
        }

        func ensureScanningState(for scanner: DataScannerViewController) {
            if isPaused {
                if scanner.isScanning {
                    scanner.stopScanning()
                }
            } else {
                lastRecognizedCode = nil
                do {
                    if !scanner.isScanning {
                        try scanner.startScanning()
                    }
                } catch {
                    onFailure(AppError.message(for: error))
                }
            }
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
        ) {
            onFailure(message(for: error))
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !isPaused else { return }
            guard let code = Self.firstBarcodePayload(in: addedItems) else { return }
            guard code != lastRecognizedCode else { return }

            lastRecognizedCode = code
            isPaused = true
            dataScanner.stopScanning()
            onRecognized(code)
        }

        private static func firstBarcodePayload(in items: [RecognizedItem]) -> String? {
            for item in items {
                if case let .barcode(barcode) = item,
                   let value = barcode.payloadStringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !value.isEmpty {
                    return value
                }
            }
            return nil
        }

        private func message(for error: DataScannerViewController.ScanningUnavailable) -> String {
            switch error {
            case .cameraRestricted:
                return "Die Kamera ist eingeschränkt und kann gerade nicht verwendet werden."
            case .unsupported:
                return "Dieses Gerät unterstützt den nativen Scanner nicht."
            @unknown default:
                return "Der Scanner ist momentan nicht verfügbar."
            }
        }
    }
}
