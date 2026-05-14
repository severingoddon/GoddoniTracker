import Foundation

struct CategoryBreakdown: Codable, Identifiable {
    let categoryId: Int?
    let categoryName: String
    let total: Double
    let percentage: Double

    var id: String { categoryName }
}

struct DailyCumulative: Codable, Identifiable {
    let date: String
    let cumulative: Double

    var id: String { date }

    var day: Int? {
        let parts = date.split(separator: "-")
        guard parts.count == 3 else { return nil }
        return Int(parts[2])
    }
}

struct AnalyticsSummary: Codable {
    let total: Double
    let dailyAverage: Double
    let projectedMonthly: Double
    let budget: Double?
    let budgetUsedPercent: Double?
    let categories: [CategoryBreakdown]
    let dailyCumulative: [DailyCumulative]
}
