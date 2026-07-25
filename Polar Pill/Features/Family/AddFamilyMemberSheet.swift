//
//  AddFamilyMemberSheet.swift
//  Polar Pill
//
//  Shared by onboarding and the caregiver dashboard.
//

import SwiftUI

struct AddFamilyMemberSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    let onAdd: (DraftFamilyMember) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name (e.g. Mum)", text: $name)
                TextField("Email for invite (optional)", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                TextField("Phone number (optional)", text: $phone)
                    .keyboardType(.phonePad)
            }
            .navigationTitle("Add family member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(DraftFamilyMember(name: name, email: email, phone: phone))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AddFamilyMemberSheet { _ in }
}
