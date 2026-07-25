//
//  PatientDetailView.swift
//  Polar Pill
//
//  Patient detail from the mockups: adherence stat card, "MEDICATIONS TODAY"
//  list, and a pinned "Call [Name]" button.
//

import SwiftUI

struct PatientDetailView: View {
    let member: FamilyMember
    @Bindable var dashboard: DashboardViewModel
    @State private var weekStats: (taken: Int, scheduled: Int) = (0, 0)
    @State private var showAddMedication = false
    @State private var medicationToEdit: Medication?
    @State private var showNoPhoneAlert = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AdherenceStatCard(taken: weekStats.taken, scheduled: weekStats.scheduled)

                    Text("MEDICATIONS TODAY")
                        .font(.footnote.bold())
                        .kerning(1)
                        .foregroundStyle(Theme.primary)

                    let meds = dashboard.todaysMedications(for: member)
                    if meds.isEmpty {
                        Text("No medications scheduled today.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    } else {
                        ForEach(meds, id: \.medication.id) { item in
                            Button {
                                medicationToEdit = item.medication
                            } label: {
                                MedicationRow(
                                    name: item.medication.name,
                                    dosage: item.medication.dosage,
                                    time: item.medication.displayTime,
                                    status: item.status,
                                    takenAt: item.takenAt
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                        .stroke(Theme.cardBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 90)
            }

            VStack {
                Spacer()
                PrimaryButton(title: "Call \(member.displayName)", systemImage: "phone.fill") {
                    call()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .navigationTitle(member.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddMedication = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add medication")
            }
        }
        .sheet(isPresented: $showAddMedication, onDismiss: reload) {
            AddEditMedicationView(members: dashboard.patients, preselectedMember: member)
        }
        .sheet(item: $medicationToEdit, onDismiss: reload) { medication in
            AddEditMedicationView(members: dashboard.patients,
                                  preselectedMember: member,
                                  existing: medication)
        }
        .alert("No phone number", isPresented: $showNoPhoneAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Add a phone number for \(member.displayName) to call them from here.")
        }
        .task { await loadWeekStats() }
        .onChange(of: dashboard.todayLogByMedication) { _, _ in
            Task { await loadWeekStats() }
        }
    }

    private func call() {
        guard let phone = member.phone,
              let url = URL(string: "tel://\(phone.filter { !$0.isWhitespace })"),
              UIApplication.shared.canOpenURL(url) else {
            showNoPhoneAlert = true
            return
        }
        UIApplication.shared.open(url)
    }

    private func reload() {
        Task {
            await dashboard.load()
            await loadWeekStats()
        }
    }

    /// "18/21 doses taken this week" — uses the dashboard's normalized dose-log rules.
    private func loadWeekStats() async {
        weekStats = await dashboard.weeklyDoseStats(for: member)
    }
}
