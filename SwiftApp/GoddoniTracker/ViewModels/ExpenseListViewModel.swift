import Foundation

@Observable
final class ExpenseListViewModel {
    var monthExpenses: MonthExpenses?
    var isLoading = false
    var errorMessage: String?
    var searchText = ""
    var searchResults: [ExpenseModel] = []
    var isSearching = false
    var currentMonth = Date()

    var monthLabel: String {
        currentMonth.monthYearString
    }

    var monthKey: String {
        currentMonth.monthKey
    }

    func load(api: APIClient) async {
        isLoading = true
        errorMessage = nil
        do {
            monthExpenses = try await api.getExpenses(month: monthKey)
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

    func search(api: APIClient) async {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        do {
            searchResults = try await api.searchExpenses(query: searchText)
        } catch {
            searchResults = []
        }
    }

    func deleteExpense(_ id: Int, api: APIClient) async -> Bool {
        do {
            try await api.deleteExpense(id)
            await load(api: api)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
