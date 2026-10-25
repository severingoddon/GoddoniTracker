import Foundation

enum AnalyticsPeriod: String, CaseIterable {
    case month = "Monat"
    case sevenDays = "7 Tage"
    case allTime = "Gesamt"
}

@Observable
final class AnalyticsViewModel {
    var summary: AnalyticsSummary?
    var isLoading = false
    var errorMessage: String?
    var currentMonth = Date()
    var period: AnalyticsPeriod = .month
    var comparison: CategoryComparison?
    var comparisonMonths = 3

    /// Month the category comparison is anchored to: the selected month, otherwise the current one.
    var comparisonAnchor: Date {
        period == .month ? currentMonth : Date()
    }

    var monthLabel: String {
        currentMonth.monthYearString
    }

    func load(api: APIClient) async {
        let hadData = summary != nil
        if !hadData { isLoading = true }
        errorMessage = nil
        do {
            switch period {
            case .allTime:
                summary = try await api.getAnalytics()
            case .sevenDays:
                summary = try await api.getAnalytics(month: currentMonth.monthKey, period: "7days")
            case .month:
                summary = try await api.getAnalytics(month: currentMonth.monthKey)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
        await loadComparison(api: api)
    }

    func loadComparison(api: APIClient) async {
        do {
            comparison = try await api.getCategoryComparison(
                month: comparisonAnchor.monthKey,
                months: comparisonMonths
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func goToPreviousMonth() {
        currentMonth = currentMonth.adding(months: -1)
    }

    func goToNextMonth() {
        currentMonth = currentMonth.adding(months: 1)
    }
}
