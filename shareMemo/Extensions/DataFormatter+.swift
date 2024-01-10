import Foundation

extension DateFormatter {
    static let shortDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        df.doesRelativeDateFormatting = true
        df.locale = Locale(identifier: "ja_JP")
        return df
    }()
}
