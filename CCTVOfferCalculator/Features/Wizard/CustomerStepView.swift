import SwiftUI
import CCTVCore

struct CustomerStepView: View {
    @Bindable var viewModel: WizardViewModel

    var body: some View {
        Form {
            if !viewModel.stepIssues(.kunde).isEmpty {
                Section {
                    ValidationBanner(issues: viewModel.stepIssues(.kunde))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            Section("Kunde") {
                TextField("Firma", text: $viewModel.draft.customer.company)
                    .textContentType(.organizationName)
                    .frame(minHeight: 44)
                TextField("Ansprechpartner", text: $viewModel.draft.customer.contactPerson)
                    .textContentType(.name)
                    .frame(minHeight: 44)
                FieldError(message: viewModel.message(for: "customer"))
                TextField("Telefon, z. B. +41 44 123 45 67", text: $viewModel.draft.customer.phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .frame(minHeight: 44)
                FieldError(message: viewModel.message(for: "phone"))
                TextField("E-Mail", text: $viewModel.draft.customer.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .frame(minHeight: 44)
                FieldError(message: viewModel.message(for: "email"))
            }

            Section("Objekt") {
                TextField("Strasse und Nummer", text: $viewModel.draft.siteStreet)
                    .textContentType(.fullStreetAddress)
                    .frame(minHeight: 44)
                HStack(spacing: 12) {
                    TextField("PLZ", text: $viewModel.draft.sitePostalCode)
                        .keyboardType(.numberPad)
                        .textContentType(.postalCode)
                        .frame(width: 90)
                    Divider()
                    TextField("Ort", text: $viewModel.draft.siteCity)
                        .textContentType(.addressCity)
                }
                .frame(minHeight: 44)
                FieldError(message: viewModel.message(for: "sitePostalCode"))
                FieldError(message: viewModel.message(for: "siteCity"))
                OptionPicker(title: "Objektart", selection: $viewModel.draft.objectType)
            }

            Section("Projekt") {
                TextField("Projektname oder Referenz", text: $viewModel.draft.reference)
                    .frame(minHeight: 44)
                FieldError(message: viewModel.message(for: "reference"))
                DatePicker("Datum der Begehung", selection: $viewModel.draft.surveyDate, displayedComponents: .date)
                    .frame(minHeight: 44)
                TextField("Notizen (z. B. Wünsche des Kunden, Zufahrt, Schlüssel)", text: $viewModel.draft.notes, axis: .vertical)
                    .lineLimit(3...8)
            }
        }
        .formStyle(.grouped)
        .scrollDismissesKeyboard(.interactively)
    }
}
