import Foundation

enum UsageCreditDisplay {
    static func currency(_ amount: Double, code: String?) -> String {
        let formatter = NumberFormatter()
        formatter.locale = L10n.locale
        formatter.numberStyle = .currency
        formatter.currencyCode = code ?? "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}

extension WindowUsage {
    var amountCaption: String? {
        guard let usedAmount else { return nil }
        let used = UsageCreditDisplay.currency(usedAmount, code: currencyCode)
        if let limitAmount {
            return L10n.tr("%@ / %@ spent", used,
                           UsageCreditDisplay.currency(limitAmount, code: currencyCode))
        }
        return L10n.tr("%@ spent · unlimited", used)
    }
}
