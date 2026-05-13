import Foundation

@Observable
final class SettingsViewModel {
    var monthlyBudget: String = ""
    var isLoading = false
    var errorMessage: String?

    func load(api: APIClient) async {
        isLoading = true
        do {
            let settings = try await api.getSettings()
            if let budget = settings.monthlyBudget {
                monthlyBudget = String(format: "%.0f", budget)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func saveBudget(api: APIClient) async -> Bool {
        let value = Double(monthlyBudget.replacingOccurrences(of: ",", with: "."))
        let settings = UserSettingsModel(monthlyBudget: value)
        do {
            _ = try await api.updateSettings(settings)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
