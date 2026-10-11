import Foundation
import SwiftData
import CCTVCore

@Model
final class Customer {
    var company: String = ""
    var contactPerson: String = ""
    var phone: String = ""
    var email: String = ""
    var project: Project?

    init() {}

    var record: CustomerRecord {
        CustomerRecord(company: company, contactPerson: contactPerson, phone: phone, email: email)
    }

    func apply(_ record: CustomerRecord) {
        company = record.company
        contactPerson = record.contactPerson
        phone = record.phone
        email = record.email
    }
}
