import Foundation

@Observable
final class AnalyticsViewModel {
    var summary: AnalyticsSummary?
    var isLoading = false
    var errorMessage: String?
    var currentMonth = Date()
    var isAllTime = false
    var is7Days = false

    var monthLabel: String {
        currentMonth.monthYearString
    }

    func load(api: APIClient) async {
        let hadData = summary != nil
        if !hadData { isLoading = true }
        errorMessage = nil
        do {
            if isAllTime {
                summary = try await api.getAnalytics()
            } else if is7Days {
                summary = try await api.getAnalytics(month: currentMonth.monthKey, period: "7days")
            } else {
                summary = try await api.getAnalytics(month: currentMonth.monthKey)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func goToPreviousMonth() {
        currentMonth = currentMonth.adding(months: -1)
    }

    func goToNextMonth() {
        currentMonth = currentMonth.adding(months: 1)
    }
}
