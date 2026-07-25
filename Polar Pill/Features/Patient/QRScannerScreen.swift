//
//  QRScannerScreen.swift
//  Polar Pill
//
//  QR scan screen from the mockups: dark viewfinder with corner brackets,
//  caption, Cancel button. Uses VisionKit's DataScannerViewController.
//  In the simulator (no camera) it offers a manual confirmation fallback so
//  the flow stays testable.
//

import SwiftUI
import Vision
import VisionKit

struct QRScannerScreen: View {
    /// Called with the QR payload, or nil for a manual confirmation.
    let onConfirm: (String?) -> Void
    let onCancel: () -> Void

    @State private var hasScanned = false

    private var scannerAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 24) {
                header

                Spacer()

                viewfinder
                    .frame(width: 300, height: 300)

                Text("Point your camera at the QR code.")
                    .font(.body)
                    .foregroundStyle(Theme.secondaryText)

                // Always available: camera-free fallback for accessibility,
                // damaged QR labels, and simulator testing.
                PrimaryButton(title: "Mark as taken manually") {
                    guard !hasScanned else { return }
                    hasScanned = true
                    onConfirm(nil)
                }
                .padding(.horizontal, 40)

                Spacer()

                SecondaryButton(title: "Cancel") {
                    onCancel()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .padding(20)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button(action: onCancel) {
                Image(systemName: "arrow.left")
                    .font(.title3)
                    .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Text("Scan QR code")
                .font(.title2.bold())

            Spacer()
        }
    }

    private var viewfinder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: 0x3A3A3C))

            if scannerAvailable {
                DataScannerRepresentable { payload in
                    guard !hasScanned else { return }
                    hasScanned = true
                    onConfirm(payload)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24))
            } else {
                // Mockup-style scan line placeholder.
                Rectangle()
                    .fill(Theme.primary)
                    .frame(height: 3)
                    .padding(.horizontal, 24)
            }

            CornerBrackets()
                .stroke(.white, lineWidth: 3)
                .padding(18)
        }
        .accessibilityLabel("Camera viewfinder")
    }
}

/// The four corner brackets drawn over the viewfinder.
private struct CornerBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let length: CGFloat = 22

        // Top-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))
        // Top-right
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))
        // Bottom-left
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        // Bottom-right
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - length))

        return path
    }
}

/// VisionKit QR scanner wrapped for SwiftUI.
private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                    onScan(payload)
                    return
                }
            }
        }
    }
}

#Preview {
    QRScannerScreen(onConfirm: { _ in }, onCancel: {})
}
