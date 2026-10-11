import XCTest
@testable import CCTVCore

final class MoneyFormatTests: XCTestCase {
    func testSwissNumberFormatting() {
        XCTAssertEqual(Format.chf(Decimal("1234.5")), "CHF 1’234.50")
        XCTAssertEqual(Format.chf(Decimal("1234567.891")), "CHF 1’234’567.89")
        XCTAssertEqual(Format.chf(0), "CHF 0.00")
        XCTAssertEqual(Format.chf(Decimal("-12.345")), "CHF -12.35")
        XCTAssertEqual(Format.number(Decimal("999"), fractionDigits: 0), "999")
        XCTAssertEqual(Format.percent(Decimal("8.1")), "8.1 %")
        XCTAssertEqual(Format.plain(Decimal("12345.6")), "12345.60")
    }

    func testFiveRappenRounding() {
        XCTAssertEqual(Decimal("10.02").roundedToFiveRappen, Decimal("10.00"))
        XCTAssertEqual(Decimal("10.025").roundedToFiveRappen, Decimal("10.05"))
        XCTAssertEqual(Decimal("10.074").roundedToFiveRappen, Decimal("10.05"))
        XCTAssertEqual(Decimal("10.075").roundedToFiveRappen, Decimal("10.10"))
    }

    func testRappenConversionAndParsing() {
        XCTAssertEqual(Money.rappen(12990), Decimal("129.90"))
        XCTAssertEqual(Money.toRappen(Decimal("129.905")), 12991)
        XCTAssertEqual(Money.parse("CHF 1’299.50"), Decimal("1299.50"))
        XCTAssertEqual(Money.parse("12,5"), Decimal("12.5"))
        XCTAssertNil(Money.parse(""))
        XCTAssertNil(Money.parse("abc"))
    }

    func testDateFormatting() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 12))!
        XCTAssertEqual(Format.date(date, calendar: calendar), "07.03.2026")
    }
}

final class PricingCalculatorTests: XCTestCase {
    private func material(_ sell: String, _ cost: String, qty: String = "1") -> OfferLineItem {
        OfferLineItem(kind: .material, category: "Kamera", description: "Testartikel", quantity: Decimal(qty), unit: .stueck,
                      unitPurchasePrice: Decimal(cost), unitSellPrice: Decimal(sell))
    }

    private func labor(_ hours: String, rate: String = "125", cost: String = "72") -> OfferLineItem {
        OfferLineItem(kind: .labor, category: "Arbeit", description: "Montage", quantity: Decimal(hours), unit: .stunde,
                      unitPurchasePrice: Decimal(cost), unitSellPrice: Decimal(rate))
    }

    func testSwissVATDefaultIs8Point1Percent() {
        XCTAssertEqual(CalculationSettings().vatPercent, Decimal("8.1"))
        XCTAssertEqual(PricingCalculator.vat(on: 1000, percent: CalculationSettings.swissVATPercent), Decimal("81"))
        XCTAssertEqual(PricingCalculator.vat(on: Decimal("123.45"), percent: Decimal("8.1")), Decimal("10.00"))
    }

    func testTotalsWithoutDiscount() {
        let items = [material("200", "120", qty: "2"), labor("4")]
        let totals = PricingCalculator.totals(for: items, discountPercent: 0, vatPercent: Decimal("8.1"))
        XCTAssertEqual(totals.materialNet, 400)
        XCTAssertEqual(totals.materialCost, 240)
        XCTAssertEqual(totals.laborNet, 500)
        XCTAssertEqual(totals.laborCost, 288)
        XCTAssertEqual(totals.subtotal, 900)
        XCTAssertEqual(totals.discountAmount, 0)
        XCTAssertEqual(totals.vatAmount, Decimal("72.90"))
        XCTAssertEqual(totals.totalInclVAT, Decimal("972.90"))
        XCTAssertEqual(totals.laborHours, 4)
        XCTAssertEqual(totals.materialMargin, 160)
        XCTAssertEqual(totals.materialMarginPercent, 40)
        XCTAssertEqual(totals.contributionMargin, 372)
        XCTAssertEqual(totals.contributionMarginPercent, Decimal("41.3"))
    }

    func testTotalsWithDiscountAndRappenRounding() {
        let items = [material("333.33", "200")]
        let totals = PricingCalculator.totals(for: items, discountPercent: 10, vatPercent: Decimal("8.1"))
        XCTAssertEqual(totals.discountAmount, Decimal("33.33"))
        XCTAssertEqual(totals.netAfterDiscount, Decimal("300.00"))
        XCTAssertEqual(totals.vatAmount, Decimal("24.30"))
        XCTAssertEqual(totals.totalInclVAT, Decimal("324.30"))
        XCTAssertEqual(totals.roundingDifference, 0)

        let odd = PricingCalculator.totals(for: [material("100.01", "50")], discountPercent: 0, vatPercent: Decimal("8.1"))
        // 100.01 + 8.10 = 108.11 → 108.10
        XCTAssertEqual(odd.vatAmount, Decimal("8.10"))
        XCTAssertEqual(odd.totalInclVAT, Decimal("108.10"))
        XCTAssertEqual(odd.roundingDifference, Decimal("-0.01"))
    }

    func testDiscountIsClampedToAllowedRange() {
        let items = [material("100", "50")]
        XCTAssertEqual(PricingCalculator.totals(for: items, discountPercent: 80, vatPercent: 0).discountPercent, 30)
        XCTAssertEqual(PricingCalculator.totals(for: items, discountPercent: -5, vatPercent: 0).discountAmount, 0)
    }

    func testEmptyOfferAndZeroSellPrice() {
        let totals = PricingCalculator.totals(for: [], discountPercent: 0, vatPercent: Decimal("8.1"))
        XCTAssertEqual(totals.totalInclVAT, 0)
        XCTAssertEqual(totals.contributionMarginPercent, 0)
        XCTAssertEqual(PricingCalculator.marginPercent(sell: 0, cost: 10), 0)
    }

    func testMarginAndSellPriceFromTargetMargin() {
        XCTAssertEqual(PricingCalculator.marginPercent(sell: 150, cost: 100), Decimal("33.3"))
        XCTAssertEqual(PricingCalculator.sellPrice(purchase: 100, targetMarginPercent: 40), Decimal("166.65"))
        XCTAssertEqual(PricingCalculator.sellPrice(purchase: 100, targetMarginPercent: 0), 100)
        let product = ProductRecord(manufacturer: .reolink, category: .kamera, name: "Test", purchasePrice: 60, sellPrice: 100)
        XCTAssertEqual(product.marginAmount, 40)
        XCTAssertEqual(product.marginPercent, 40)
    }

    func testLineItemNumberingPutsMaterialFirst() {
        let numbered = PricingCalculator.numbered([labor("1"), material("10", "5"), material("20", "5")])
        XCTAssertEqual(numbered.map(\.position), [1, 2, 3])
        XCTAssertEqual(numbered.map(\.kind), [.material, .material, .labor])
    }

    func testLineItemTotalsRoundToRappen() {
        let cable = OfferLineItem(kind: .material, category: "Kabel", description: "Cat. 6A", quantity: Decimal("33"), unit: .meter,
                                  unitPurchasePrice: Decimal("1.10"), unitSellPrice: Decimal("2.80"))
        XCTAssertEqual(cable.totalSell, Decimal("92.40"))
        XCTAssertEqual(cable.totalPurchase, Decimal("36.30"))
        XCTAssertEqual(cable.marginAmount, Decimal("56.10"))
    }
}
