import Foundation

struct CategoryBreakdown: Codable, Identifiable {
    let categoryId: Int?
    let categoryName: String
    let total: Double
    let percentage: Double

    var id: String { categoryName }
}

struct AnalyticsSummary: Codable {
    let total: Double
    let dailyAverage: Double
    let projectedMonthly: Double
    let budget: Double?
    let budgetUsedPercent: Double?
    let categories: [CategoryBreakdown]
}
