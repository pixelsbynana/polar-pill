//
//  ReportsView.swift
//  Polar Pill
//
//  Weekly AI health summary from the mockups: navy header, period segmented
//  control, big stat row, bar chart, AI SUMMARY card, share buttons.
//

import SwiftUI

struct ReportsView: View {
    @Bindable var dashboard: DashboardViewModel
    @State private var viewModel = ReportsViewModel()
    @State private var pdfToShare: SharePayload?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if dashboard.patients.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header

                        periodPicker

                        statRow

                        chartCard

                        summaryCard

                        buttons
                    }
                    .padding(20)
                }
                .refreshable { await reload() }
            }
        }
        .task {
            if dashboard.members.isEmpty { await dashboard.load() }
            await reload()
        }
        .onChange(of: viewModel.period) {
            Task { await reload() }
        }
        .sheet(item: $pdfToShare) { payload in
            ShareSheet(items: [payload.url])
        }
    }

    private var currentMember: FamilyMember? {
        viewModel.selectedMember ?? dashboard.patients.first
    }

    private func reload() async {
        guard let member = currentMember else { return }
        await viewModel.load(member: member)
    }

    // MARK: - Header (navy card, per mockup)

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(viewModel.period.displayName) Report")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Adherence summary · \(viewModel.periodLabel)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            // Member chip — tap to switch patients.
            Menu {
                ForEach(dashboard.patients) { member in
                    Button(member.displayName) {
                        Task { await viewModel.load(member: member) }
                    }
                }
            } label: {
                Text(currentMember?.displayName ?? "—")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.16), in: Capsule())
            }
            .accessibilityLabel("Change patient")
        }
        .padding(20)
        .background(Theme.navy, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Period picker

    private var periodPicker: some View {
        Picker("Period", selection: $viewModel.period) {
            ForEach(SummaryPeriod.allCases, id: \.self) { period in
                Text(period.displayName).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Stats

    private var statRow: some View {
        HStack(spacing: 28) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.dosesTaken)/\(viewModel.dosesScheduled)")
                    .font(.largeTitle.bold()) // scales with Dynamic Type
                Text("doses taken")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.adherencePercent)%")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.primary)
                Text("adherence")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Chart

    private var chartCard: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
            } else if viewModel.chartDays.isEmpty {
                Text("No dose data for this period yet.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                WeeklyBarChart(days: viewModel.chartDays)
                    .padding(16)
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - AI summary

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SUMMARY")
                .font(.footnote.bold())
                .kerning(1)
                .foregroundStyle(Theme.primary)

            if let summaryText = viewModel.summaryText {
                Text(summaryText)
                    .font(.body)
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(Theme.danger)
            } else {
                Text("A summary will appear once there's dose data for this period.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Bottom buttons

    private var buttons: some View {
        HStack(spacing: 12) {
            Button {
                sharePDF()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share with clinician")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: Theme.minTapTarget + 8)
                .contentShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )

            Button {
                sharePDF()
            } label: {
                Text("Download PDF")
                    .font(.body.bold())
                    .foregroundStyle(Theme.primary)
                    .frame(minHeight: Theme.minTapTarget)
                    .padding(.horizontal, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .disabled(viewModel.dosesScheduled == 0)
        .opacity(viewModel.dosesScheduled == 0 ? 0.4 : 1)
    }

    /// Renders the current report to PDF and opens the share sheet
    /// (save to Files, AirDrop, email to a clinician, …).
    private func sharePDF() {
        guard let member = currentMember else { return }
        let data = ReportData(
            memberName: member.displayName,
            periodTitle: "\(viewModel.period.displayName) Report",
            periodLabel: viewModel.periodLabel,
            dosesTaken: viewModel.dosesTaken,
            dosesScheduled: viewModel.dosesScheduled,
            adherencePercent: viewModel.adherencePercent,
            days: viewModel.chartDays,
            summaryText: viewModel.summaryText
        )
        if let url = ReportPDF.render(data: data) {
            pdfToShare = SharePayload(url: url)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.largeTitle)
                .foregroundStyle(Theme.secondaryText)
            Text("Add a family member and medications to see reports.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
