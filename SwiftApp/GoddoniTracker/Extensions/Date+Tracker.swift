import Foundation

extension Date {
    var monthYearString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: self).capitalized
    }

    var dayGroupLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return "HEUTE"
        } else if calendar.isDateInYesterday(self) {
            return "GESTERN"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "de_CH")
            formatter.dateFormat = "d. MMMM yyyy"
            return formatter.string(from: self)
        }
    }

    var monthKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: self)
    }

    func adding(months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }
}
