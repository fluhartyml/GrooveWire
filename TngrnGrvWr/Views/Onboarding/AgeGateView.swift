import SwiftUI
import SwiftData

struct AgeGateView: View {
    let user: User
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @State private var birthday = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var hasPickedBirthday = false
    @State private var showParentalConsent = false
    @State private var contactMethod = ""
    @State private var contactType: ContactType = .email

    enum ContactType: String, CaseIterable {
        case email = "Email"
        case phone = "Phone"
    }

    private var computedAge: AgeCategory {
        User.computeAgeCategory(from: birthday)
    }

    private var needsContact: Bool {
        user.email == nil && user.phoneNumber == nil && contactMethod.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var canComplete: Bool {
        hasPickedBirthday && !needsContact
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 50))
                    .foregroundStyle(themeColor)

                Text("One More Thing")
                    .font(.largeTitle.bold())

                Text("GrooveWire now requires a birthday and contact method to keep our community safe.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            VStack(spacing: 16) {
                DatePicker(
                    "Birthday",
                    selection: $birthday,
                    in: Calendar.current.date(byAdding: .year, value: -120, to: Date())!...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.automatic)
                .padding(.horizontal, 32)
                .onChange(of: birthday) { _, _ in
                    hasPickedBirthday = true
                }

                if hasPickedBirthday {
                    ageCategoryNotice
                        .padding(.horizontal, 32)
                }

                // Contact method if user doesn't have one
                if user.email == nil && user.phoneNumber == nil {
                    VStack(spacing: 8) {
                        Picker("Contact Type", selection: $contactType) {
                            ForEach(ContactType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)

                        TextField(
                            contactType == .email ? "Email address" : "Phone number",
                            text: $contactMethod
                        )
                        .textFieldStyle(.roundedBorder)
                        .textContentType(contactType == .email ? .emailAddress : .telephoneNumber)
                        #if os(iOS)
                        .keyboardType(contactType == .email ? .emailAddress : .phonePad)
                        .autocapitalization(.none)
                        #endif
                    }
                    .padding(.horizontal, 32)
                }
            }

            Spacer()

            Button {
                if computedAge == .child {
                    showParentalConsent = true
                } else if computedAge == .teen {
                    showParentalConsent = true
                } else {
                    completeAgeGate(parentalConsent: false)
                }
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canComplete ? themeColor : .gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canComplete)
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .alert("Parental Notice", isPresented: $showParentalConsent) {
            Button("My parent/guardian approves") {
                completeAgeGate(parentalConsent: true)
            }
            Button("Continue without consent") {
                completeAgeGate(parentalConsent: false)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if computedAge == .child {
                Text("Users under 13 will always appear as \"Listener\" in GrooveWire Bridges. A parent or guardian must approve use of this app.")
            } else {
                Text("Users 13-17 are private by default. With parental consent, your screen name can be shown in GrooveWire Bridges.")
            }
        }
    }

    @ViewBuilder
    private var ageCategoryNotice: some View {
        switch computedAge {
        case .child:
            Label("Under 13 — profile will be private, name hidden in GrooveWire Bridges", systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(themeColor)
        case .teen:
            Label("13-17 — profile is private by default", systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(.blue)
        case .adult:
            Label("18+ — you can choose public or private profile", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.green)
        case .unknown:
            EmptyView()
        }
    }

    private func completeAgeGate(parentalConsent: Bool) {
        user.birthday = birthday
        user.hasCompletedAgeGate = true
        user.parentalConsentAcknowledged = parentalConsent
        user.privacyLevel = computedAge == .adult ? "public" : "private"

        // Save contact method if provided
        let trimmed = contactMethod.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            switch contactType {
            case .email: user.email = trimmed
            case .phone: user.phoneNumber = trimmed
            }
        }

        try? modelContext.save()
    }
}
