import Foundation

struct ExpenseModel: Codable, Identifiable {
    let id: Int
    let title: String
    let date: Date
    let amount: Double
    let currency: String
    let amountInChf: Double
    let categoryId: Int?
    let categoryName: String?
    let paymentMethod: String?
    let comment: String?
    let splitApplied: Bool
    let splitFactor: Double?
}

struct ExpenseCreate: Codable {
    let title: String
    let date: Date
    let amount: Double
    let currency: String
    let amountInChf: Double
    let categoryId: Int?
    let paymentMethod: String?
    let comment: String?
    let splitApplied: Bool
    let splitFactor: Double?
}

struct DayGroup: Codable, Identifiable {
    let date: String
    let total: Double
    let expenses: [ExpenseModel]

    var id: String { date }

    var dateObject: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }
}

struct MonthExpenses: Codable {
    let month: String
    let allTimeTotal: Double
    let monthTotal: Double
    let days: [DayGroup]
}
