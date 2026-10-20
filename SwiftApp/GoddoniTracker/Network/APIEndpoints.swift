import Foundation

enum APIEndpoints {
    static let baseURL = "https://goddonitracker.goddoni.org"

    // Auth
    static let googleLogin = "/api/auth/google/login?platform=ios"
    static let me = "/api/auth/me"

    // Categories
    static let categories = "/api/categories"
    static func category(_ id: Int) -> String { "/api/categories/\(id)" }
    static let categoriesReorder = "/api/categories/reorder"

    // Expenses
    static let expenses = "/api/expenses"
    static func expense(_ id: Int) -> String { "/api/expenses/\(id)" }
    static let expensesSearch = "/api/expenses/search"

    // Analytics
    static let analytics = "/api/analytics"

    // Settings
    static let settings = "/api/settings"

    // Export / Import
    static let export = "/api/export"
    static let importCSV = "/api/import"
}
