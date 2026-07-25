//
//  WeeklyBarChart.swift
//  Polar Pill
//
//  Mon–Sun adherence bar chart from the Weekly Report mockup:
//  fully-adherent days in steel blue, days with missed doses in gray.
//

import SwiftUI
import Charts

struct AdherenceDay: Identifiable {
    let id = UUID()
    /// Axis label, e.g. "M", "T", "W".
    let label: String
    /// Doses taken / doses scheduled (0…1); nil when nothing was scheduled.
    let ratio: Double?
    let allTaken: Bool
}

struct WeeklyBarChart: View {
    let days: [AdherenceDay]

    var body: some View {
        // Index-keyed (categorical) x values stay unique even when labels
        // repeat (M T W T F S S).
        Chart(Array(days.enumerated()), id: \.element.id) { index, day in
            BarMark(
                x: .value("Day", "\(index)"),
                // Missed days render slightly shorter, like the mockup;
                // days with no data (e.g. future days) show a small stub.
                y: .value("Adherence", day.ratio.map { max($0, 0.15) } ?? 0.05),
                width: .ratio(0.62)
            )
            .foregroundStyle(day.allTaken ? Theme.primary : Theme.chartGray)
            .cornerRadius(3)
        }
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...1)
        // Day labels as axis marks — laid out inside the chart's frame,
        // so nothing spills out of the card.
        .chartXAxis {
            AxisMarks(values: days.indices.map { "\($0)" }) { value in
                AxisValueLabel(centered: true) {
                    if let key = value.as(String.self),
                       let index = Int(key), days.indices.contains(index) {
                        Text(days[index].label)
                            .font(.caption2)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }
        }
        .frame(height: 120)
        .accessibilityLabel("Adherence chart: \(days.filter(\.allTaken).count) of \(days.count) periods fully taken")
    }
}

#Preview {
    WeeklyBarChart(days: [
        AdherenceDay(label: "M", ratio: 1, allTaken: true),
        AdherenceDay(label: "T", ratio: 0.66, allTaken: false),
        AdherenceDay(label: "W", ratio: 1, allTaken: true),
        AdherenceDay(label: "T", ratio: 1, allTaken: true),
        AdherenceDay(label: "F", ratio: 1, allTaken: true),
        AdherenceDay(label: "S", ratio: 0.5, allTaken: false),
        AdherenceDay(label: "S", ratio: 1, allTaken: true),
    ])
    .padding()
    .background(Theme.card)
}
