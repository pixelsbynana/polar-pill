//
//  AddEditMedicationView.swift
//  Polar Pill
//
//  Add/edit medication form from the mockups: name, dosage, assign-to
//  segmented toggle, time picker, frequency radios (custom reveals a
//  day picker), reminders toggle, pinned save button.
//

import SwiftUI
import Supabase

struct AddEditMedicationView: View {
    @Environment(\.dismiss) private var dismiss

    let members: [FamilyMember]
    let existing: Medication?

    @State private var name: String
    @State private var dosage: String
    @State private var assignedMemberID: UUID?
    @State private var timeOfDay: Date
    @State private var frequency: MedFrequency
    @State private var selectedWeekdays: Set<Int>
    @State private var remindersEnabled: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showQRLabel = false
    @State private var showDeleteConfirmation = false

    private static let weekdayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    init(members: [FamilyMember], preselectedMember: FamilyMember? = nil, existing: Medication? = nil) {
        self.members = members
        self.existing = existing

        _name = State(initialValue: existing?.name ?? "")
        _dosage = State(initialValue: existing?.dosage ?? "")
        _assignedMemberID = State(initialValue: existing?.familyMemberID ?? preselectedMember?.id ?? members.first?.id)
        _frequency = State(initialValue: existing?.frequency ?? .daily)
        _selectedWeekdays = State(initialValue: Set(existing?.customSchedule?.weekdays ?? []))
        _remindersEnabled = State(initialValue: existing?.remindersEnabled ?? true)

        let components = existing?.timeComponents ?? (hour: 8, minute: 0)
        let date = Calendar.current.date(bySettingHour: components.hour, minute: components.minute, second: 0, of: .now) ?? .now
        _timeOfDay = State(initialValue: date)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        field("Medication name") {
                            TextField("e.g. Lisinopril", text: $name)
                                .padding(14)
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
                        }

                        field("Dosage") {
                            TextField("e.g. 10mg", text: $dosage)
                                .padding(14)
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
                        }

                        // No "Assign to" control: the form is always opened
                        // from a specific patient, so assignedMemberID comes
                        // from that context (preselected or the existing med).

                        field("Time of day") {
                            DatePicker("Time of day", selection: $timeOfDay, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
                        }

                        field("Frequency") {
                            VStack(alignment: .leading, spacing: 10) {
                                Menu {
                                    ForEach(MedFrequency.allCases, id: \.self) { option in
                                        Button {
                                            frequency = option
                                        } label: {
                                            if frequency == option {
                                                Label(option.displayName, systemImage: "checkmark")
                                            } else {
                                                Text(option.displayName)
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(frequency.displayName)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.footnote)
                                            .foregroundStyle(Theme.secondaryText)
                                    }
                                    .padding(14)
                                    .frame(minHeight: Theme.minTapTarget)
                                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
                                    .contentShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .accessibilityLabel("Frequency: \(frequency.displayName)")

                                if frequency == .custom {
                                    weekdayPicker
                                }
                            }
                        }

                        field("Reminders") {
                            HStack(spacing: 0) {
                                reminderButton(true, title: "On")
                                reminderButton(false, title: "Off")
                            }
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
                        }

                        // Printable QR label + delete (existing meds only).
                        if existing != nil {
                            SecondaryButton(title: "Print QR label", systemImage: "qrcode") {
                                showQRLabel = true
                            }
                            .padding(.top, 6)

                            Button {
                                showDeleteConfirmation = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash")
                                    Text("Delete medication")
                                        .fontWeight(.bold)
                                }
                                .foregroundStyle(Theme.danger)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: Theme.minTapTarget + 8)
                                .contentShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Theme.danger.opacity(0.5), lineWidth: 1)
                            )
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(Theme.danger)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(existing == nil ? "Add medication" : "Edit medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                // Save lives top-right, matching Cancel's style but bold + blue.
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await save() }
                        }
                        .fontWeight(.bold)
                        .foregroundStyle(canSave ? Theme.primary : Theme.secondaryText)
                        .disabled(!canSave)
                    }
                }
            }
            .confirmationDialog(
                "Delete \(existing?.name ?? "medication")?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete medication", role: .destructive) {
                    Task { await deleteMedication() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This also removes its dose history and reminders. This can't be undone.")
            }
            .sheet(isPresented: $showQRLabel) {
                if let existing {
                    MedicationQRLabelView(
                        medication: existing,
                        patientName: members.first { $0.id == existing.familyMemberID }?.displayName ?? "your family member"
                    )
                }
            }
        }
    }

    // MARK: - Subviews

    private func field(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
            content()
        }
    }

    private var weekdayPicker: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { day in
                let selected = selectedWeekdays.contains(day)
                Button {
                    if selected { selectedWeekdays.remove(day) } else { selectedWeekdays.insert(day) }
                } label: {
                    Text(Self.weekdayNames[day - 1])
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(selected ? Theme.primary : Theme.card, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.cardBorder, lineWidth: selected ? 0 : 1))
                        .foregroundStyle(selected ? .white : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private func reminderButton(_ value: Bool, title: String) -> some View {
        Button {
            remindersEnabled = value
        } label: {
            Text(title)
                .font(.body.weight(remindersEnabled == value ? .bold : .regular))
                .frame(maxWidth: .infinity)
                .frame(minHeight: Theme.minTapTarget)
                .background(
                    remindersEnabled == value ? Theme.primaryTint : .clear,
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(remindersEnabled == value ? Theme.primary : .clear, lineWidth: 1.5)
                )
                .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(remindersEnabled == value ? .isSelected : [])
    }

    // MARK: - Deleting

    private func deleteMedication() async {
        guard let client = SupabaseService.shared?.client, let existing else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await DataService(client: client).deleteMedication(id: existing.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Saving

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && assignedMemberID != nil
            && (frequency != .custom || !selectedWeekdays.isEmpty)
    }

    private func save() async {
        guard let client = SupabaseService.shared?.client,
              let memberID = assignedMemberID else { return }
        isSaving = true
        defer { isSaving = false }

        let components = Calendar.current.dateComponents([.hour, .minute], from: timeOfDay)
        let payload = DataService.MedicationPayload(
            family_member_id: memberID,
            name: name.trimmingCharacters(in: .whitespaces),
            dosage: dosage.trimmingCharacters(in: .whitespaces),
            time_of_day: String(format: "%02d:%02d:00", components.hour ?? 8, components.minute ?? 0),
            frequency: frequency.rawValue,
            custom_schedule: frequency == .daily ? nil : CustomSchedule(weekdays: selectedWeekdays.sorted()),
            reminders_enabled: remindersEnabled,
            created_by: client.auth.currentSession?.user.id
        )

        do {
            let service = DataService(client: client)
            if let existing {
                let updated = try await service.updateMedication(id: existing.id, payload)
                // Replace today's pending log so it reflects the (possibly
                // changed) schedule — avoids a stale log at the old time.
                try? await service.deletePendingDoseLogs(medicationID: updated.id)
                try? await service.ensureDoseLogs(for: [updated])
            } else {
                let medication = try await service.createMedication(payload)
                // Make today's status visible immediately.
                try? await service.ensureDoseLogs(for: [medication])
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
