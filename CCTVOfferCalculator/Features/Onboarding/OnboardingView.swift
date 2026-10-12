import SwiftUI
import CCTVCore

/// Einrichtung beim ersten Start: Firmenangaben für den Offertkopf erfassen.
///
/// Erscheint nur, solange noch keine vollständigen Firmenangaben (Firmenname und Ort) hinterlegt sind.
/// «Später erfassen» schliesst die Maske für diese Sitzung; beim nächsten Start erscheint sie wieder,
/// bis die Angaben vorhanden sind. Alle Angaben lassen sich jederzeit unter «Einstellungen» ändern.
struct OnboardingView: View {
    @Environment(SettingsStore.self) private var store
    let onFinish: () -> Void

    @State private var draft = CompanyProfile()
    @State private var didLoad = false
    @State private var showErrors = false
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case name, street, postalCode, city, phone, email, website, vat
    }

    private var trimmedName: String { draft.name.trimmingCharacters(in: .whitespaces) }
    private var trimmedCity: String { draft.city.trimmingCharacters(in: .whitespaces) }
    private var trimmedPostalCode: String { draft.postalCode.trimmingCharacters(in: .whitespaces) }
    private var trimmedEmail: String { draft.email.trimmingCharacters(in: .whitespaces) }

    private var nameError: String? { trimmedName.isEmpty ? "Bitte geben Sie den Firmennamen an." : nil }
    private var cityError: String? { trimmedCity.isEmpty ? "Bitte geben Sie den Ort an." : nil }
    private var postalCodeError: String? {
        guard !trimmedPostalCode.isEmpty else { return nil }
        return trimmedPostalCode.count == 4 && trimmedPostalCode.allSatisfy(\.isNumber)
            ? nil : "Die Postleitzahl hat vier Ziffern."
    }
    private var emailError: String? {
        guard !trimmedEmail.isEmpty else { return nil }
        return ProjectValidator.isValidEmail(trimmedEmail) ? nil : "Die E-Mail-Adresse ist ungültig."
    }
    private var isValid: Bool {
        nameError == nil && cityError == nil && postalCodeError == nil && emailError == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    header
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    TextField("Firmenname", text: $draft.name, prompt: Text("z. B. Ostsicht GmbH"))
                        .textContentType(.organizationName)
                        .focused($focus, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focus = .street }
                    if showErrors { FieldError(message: nameError) }
                    TextField("Strasse und Nummer", text: $draft.street)
                        .textContentType(.fullStreetAddress)
                        .focused($focus, equals: .street)
                        .submitLabel(.next)
                        .onSubmit { focus = .postalCode }
                    HStack {
                        TextField("PLZ", text: $draft.postalCode)
                            .keyboardType(.numberPad)
                            .textContentType(.postalCode)
                            .focused($focus, equals: .postalCode)
                            .frame(width: 90)
                        Divider()
                        TextField("Ort", text: $draft.city)
                            .textContentType(.addressCity)
                            .focused($focus, equals: .city)
                            .submitLabel(.next)
                            .onSubmit { focus = .phone }
                    }
                    if showErrors { FieldError(message: postalCodeError ?? cityError) }
                } header: {
                    Text("Firma")
                } footer: {
                    Text("Firmenname und Ort sind nötig. Alles andere können Sie später ergänzen.")
                }

                Section {
                    TextField("Telefon", text: $draft.phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .focused($focus, equals: .phone)
                    TextField("E-Mail", text: $draft.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focus = .website }
                    if showErrors || !trimmedEmail.isEmpty && focus != .email { FieldError(message: emailError) }
                    TextField("Website", text: $draft.website, prompt: Text("z. B. ostsicht.ch"))
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .website)
                        .submitLabel(.next)
                        .onSubmit { focus = .vat }
                    TextField("MWST-Nummer", text: $draft.vatNumber, prompt: Text("CHE-123.456.789 MWST"))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .vat)
                        .submitLabel(.done)
                        .onSubmit(save)
                } header: {
                    Text("Kontakt")
                } footer: {
                    Text("Erscheint im Kopf und in der Fusszeile jeder Offerte. Die Angaben bleiben auf diesem Gerät.")
                }

                Section {
                    Button(action: save) {
                        Text("Speichern und loslegen")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primaryAction)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    Button("Später erfassen", action: onFinish)
                        .font(.brand(.subheadline))
                        .foregroundStyle(Theme.grau)
                        .frame(maxWidth: .infinity, minHeight: Theme.minimumTouchTarget)
                        .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { focus = nil }
                }
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .background(Theme.background)
        }
        .interactiveDismissDisabled()
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            // Bereits teilweise erfasste Angaben übernehmen.
            draft = store.settings.company
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            OstsichtLogo(layout: .horizontal, variant: .negativ)
                .frame(height: 40)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Willkommen")
                .font(.brand(.title))
                .foregroundStyle(.white)
            Text("Erfassen Sie kurz Ihre Firmenangaben. Sie erscheinen auf jeder Offerte, die Sie mit der App erstellen.")
                .font(.brand(.subheadline))
                .foregroundStyle(Color(uiColor: OstsichtColor.gruenHell))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.gruenSolid, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func save() {
        guard isValid else {
            showErrors = true
            focus = nameError != nil ? .name : (postalCodeError != nil ? .postalCode : (cityError != nil ? .city : .email))
            return
        }
        var company = draft
        company.name = trimmedName
        company.street = company.street.trimmingCharacters(in: .whitespaces)
        company.postalCode = trimmedPostalCode
        company.city = trimmedCity
        company.phone = company.phone.trimmingCharacters(in: .whitespaces)
        company.email = trimmedEmail
        company.website = company.website.trimmingCharacters(in: .whitespaces)
        company.vatNumber = company.vatNumber.trimmingCharacters(in: .whitespaces)

        var updated = store.settings
        updated.company = company
        store.settings = updated
        onFinish()
    }
}
