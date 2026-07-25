//
//  MedicationQRLabelView.swift
//  Polar Pill
//
//  Printable QR labels for medication boxes. The QR encodes
//  "polarpill://medication/<uuid>", which the patient's scanner matches to
//  confirm that exact medication. Generated fully on-device with CoreImage.
//

import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

// MARK: - QR generation

enum MedicationQR {
    /// The payload the patient-side scanner matches against.
    static func payload(for medication: Medication) -> String {
        "polarpill://medication/\(medication.id.uuidString.lowercased())"
    }

    /// Crisp QR image (nearest-neighbor upscale, no smoothing).
    static func image(for medication: Medication, scale: CGFloat = 12) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload(for: medication).utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }

        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Label sheet

struct MedicationQRLabelView: View {
    @Environment(\.dismiss) private var dismiss

    let medication: Medication
    let patientName: String

    @State private var pdfToShare: SharePayload?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        Text("Stick a label on \(patientName)'s \(medication.name) box. Scanning it with Polar Pill marks the dose as taken.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)

                        // Preview of a single label.
                        MedicationLabel(medication: medication, patientName: patientName)
                            .frame(width: 260)

                        PrimaryButton(title: "Print labels", systemImage: "printer") {
                            printLabels()
                        }

                        SecondaryButton(title: "Share as PDF", systemImage: "square.and.arrow.up") {
                            if let url = makeLabelSheetPDF() {
                                pdfToShare = SharePayload(url: url)
                            }
                        }

                        Text("Printing gives you a page of 6 labels to cut out.")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("QR label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $pdfToShare) { payload in
                ShareSheet(items: [payload.url])
            }
        }
    }

    // MARK: - Print / PDF

    /// AirPrint dialog with the label sheet.
    private func printLabels() {
        guard let url = makeLabelSheetPDF() else { return }
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "Polar Pill — \(medication.name) QR labels"

        let controller = UIPrintInteractionController.shared
        controller.printInfo = printInfo
        controller.printingItem = url
        controller.present(animated: true)
    }

    /// US Letter page with a 2×3 grid of identical cut-out labels.
    @MainActor
    private func makeLabelSheetPDF() -> URL? {
        let sheet = LabelSheet(medication: medication, patientName: patientName)
            .frame(width: 612) // US Letter width in points
        let renderer = ImageRenderer(content: sheet)

        let filename = "Polar Pill QR labels — \(medication.name).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        renderer.render { size, renderInContext in
            var mediaBox = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(url: url as CFURL),
                  let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
                return
            }
            context.beginPDFPage(nil)
            renderInContext(context)
            context.endPDFPage()
            context.closePDF()
        }

        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}

// MARK: - Single label

private struct MedicationLabel: View {
    let medication: Medication
    let patientName: String

    var body: some View {
        VStack(spacing: 8) {
            if let qr = MedicationQR.image(for: medication) {
                Image(uiImage: qr)
                    .resizable()
                    .interpolation(.none) // keep QR modules sharp
                    .scaledToFit()
                    .frame(width: 130, height: 130)
                    .accessibilityLabel("QR code for \(medication.name)")
            }

            Text(medication.name)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text("\(medication.dosage)\(medication.dosage.isEmpty ? "" : " · ")\(medication.displayTime) · \(patientName)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text("Scan with Polar Pill to mark as taken")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.white)
        .overlay(
            // Dashed border = cutting guide.
            RoundedRectangle(cornerRadius: 10)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .foregroundStyle(.gray.opacity(0.6))
        )
        .environment(\.colorScheme, .light)
    }
}

// MARK: - Printable page (2×3 grid)

private struct LabelSheet: View {
    let medication: Medication
    let patientName: String

    var body: some View {
        VStack(spacing: 24) {
            Text("Polar Pill — QR labels for \(medication.name)")
                .font(.headline)

            let columns = [GridItem(.flexible(), spacing: 24), GridItem(.flexible(), spacing: 24)]
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(0..<6, id: \.self) { _ in
                    MedicationLabel(medication: medication, patientName: patientName)
                }
            }

            Text("Cut along the dashed lines and stick a label on each medication box.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(36)
        .background(.white)
        .environment(\.colorScheme, .light)
    }
}

#Preview {
    MedicationQRLabelView(
        medication: Medication(
            id: UUID(),
            familyMemberID: UUID(),
            name: "Metformin",
            dosage: "500mg",
            timeOfDay: "08:00:00",
            frequency: .daily,
            customSchedule: nil,
            remindersEnabled: true,
            createdBy: nil,
            createdAt: .now
        ),
        patientName: "Mum"
    )
}
