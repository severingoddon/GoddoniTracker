import Foundation

@Observable
final class APIClient {
    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)

            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
                "yyyy-MM-dd'T'HH:mm:ss.SSS",
                "yyyy-MM-dd HH:mm:ss",
            ]
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US_POSIX")
            for format in formats {
                fmt.dateFormat = format
                if let date = fmt.date(from: str) { return date }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(str)")
        }
        return d
    }()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        e.dateEncodingStrategy = .formatted(formatter)
        return e
    }()

    var authManager: AuthManager?

    private func makeURL(_ path: String, queryItems: [URLQueryItem]? = nil) throws -> URL {
        var components = URLComponents(string: APIEndpoints.baseURL + path)!
        components.queryItems = queryItems
        guard let url = components.url else { throw APIError.invalidURL }
        return url
    }

    private func makeRequest(_ method: String, path: String, body: Data? = nil, queryItems: [URLQueryItem]? = nil) throws -> URLRequest {
        let url = try makeURL(path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authManager?.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = body
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if http.statusCode == 401 {
            await MainActor.run { authManager?.logout() }
            throw APIError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            let detail = try? decoder.decode(APIDetailError.self, from: data)
            throw APIError.serverError(http.statusCode, detail?.detail)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func performVoid(_ request: URLRequest) async throws {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if http.statusCode == 401 {
            await MainActor.run { authManager?.logout() }
            throw APIError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            let detail = try? decoder.decode(APIDetailError.self, from: data)
            throw APIError.serverError(http.statusCode, detail?.detail)
        }
    }

    // MARK: - Auth

    func getMe() async throws -> UserInfo {
        let request = try makeRequest("GET", path: APIEndpoints.me)
        return try await perform(request)
    }

    // MARK: - Categories

    func getCategories() async throws -> [CategoryModel] {
        let request = try makeRequest("GET", path: APIEndpoints.categories)
        return try await perform(request)
    }

    func createCategory(_ name: String) async throws -> CategoryModel {
        let body = try encoder.encode(["name": name])
        let request = try makeRequest("POST", path: APIEndpoints.categories, body: body)
        return try await perform(request)
    }

    func updateCategory(_ id: Int, name: String) async throws -> CategoryModel {
        let body = try encoder.encode(["name": name])
        let request = try makeRequest("PUT", path: APIEndpoints.category(id), body: body)
        return try await perform(request)
    }

    func deleteCategory(_ id: Int) async throws {
        let request = try makeRequest("DELETE", path: APIEndpoints.category(id))
        try await performVoid(request)
    }

    func reorderCategories(_ order: [Int]) async throws {
        let body = try encoder.encode(["order": order])
        let request = try makeRequest("PUT", path: APIEndpoints.categoriesReorder, body: body)
        try await performVoid(request)
    }

    // MARK: - Expenses

    func getExpenses(month: String? = nil, categoryId: Int? = nil) async throws -> MonthExpenses {
        var queryItems: [URLQueryItem] = []
        if let month { queryItems.append(URLQueryItem(name: "month", value: month)) }
        if let categoryId { queryItems.append(URLQueryItem(name: "category_id", value: String(categoryId))) }
        let request = try makeRequest("GET", path: APIEndpoints.expenses, queryItems: queryItems.isEmpty ? nil : queryItems)
        return try await perform(request)
    }

    func getExpense(_ id: Int) async throws -> ExpenseModel {
        let request = try makeRequest("GET", path: APIEndpoints.expense(id))
        return try await perform(request)
    }

    func createExpense(_ expense: ExpenseCreate) async throws -> ExpenseModel {
        let body = try encoder.encode(expense)
        let request = try makeRequest("POST", path: APIEndpoints.expenses, body: body)
        return try await perform(request)
    }

    func updateExpense(_ id: Int, _ expense: ExpenseCreate) async throws -> ExpenseModel {
        let body = try encoder.encode(expense)
        let request = try makeRequest("PUT", path: APIEndpoints.expense(id), body: body)
        return try await perform(request)
    }

    func deleteExpense(_ id: Int) async throws {
        let request = try makeRequest("DELETE", path: APIEndpoints.expense(id))
        try await performVoid(request)
    }

    func searchExpenses(query: String) async throws -> [ExpenseModel] {
        let queryItems = [URLQueryItem(name: "q", value: query)]
        let request = try makeRequest("GET", path: APIEndpoints.expensesSearch, queryItems: queryItems)
        return try await perform(request)
    }

    // MARK: - Analytics

    func getAnalytics(month: String? = nil, period: String? = nil) async throws -> AnalyticsSummary {
        var queryItems: [URLQueryItem] = []
        if let month { queryItems.append(URLQueryItem(name: "month", value: month)) }
        if let period { queryItems.append(URLQueryItem(name: "period", value: period)) }
        let request = try makeRequest("GET", path: APIEndpoints.analytics, queryItems: queryItems.isEmpty ? nil : queryItems)
        return try await perform(request)
    }

    func getCategoryComparison(month: String, months: Int) async throws -> CategoryComparison {
        let queryItems = [
            URLQueryItem(name: "month", value: month),
            URLQueryItem(name: "months", value: String(months)),
        ]
        let request = try makeRequest("GET", path: APIEndpoints.categoryComparison, queryItems: queryItems)
        return try await perform(request)
    }

    // MARK: - Settings

    func getSettings() async throws -> UserSettingsModel {
        let request = try makeRequest("GET", path: APIEndpoints.settings)
        return try await perform(request)
    }

    func updateSettings(_ settings: UserSettingsModel) async throws -> UserSettingsModel {
        let body = try encoder.encode(settings)
        let request = try makeRequest("PUT", path: APIEndpoints.settings, body: body)
        return try await perform(request)
    }

    // MARK: - Export

    func getExportURL(dateFrom: String?, dateTo: String?) -> URL? {
        var components = URLComponents(string: APIEndpoints.baseURL + APIEndpoints.export)
        var items: [URLQueryItem] = []
        if let dateFrom { items.append(URLQueryItem(name: "date_from", value: dateFrom)) }
        if let dateTo { items.append(URLQueryItem(name: "date_to", value: dateTo)) }
        if !items.isEmpty { components?.queryItems = items }
        return components?.url
    }

    // MARK: - Import

    func importCSV(data: Data, filename: String) async throws -> APIDetailResponse {
        let boundary = UUID().uuidString
        let url = try makeURL(APIEndpoints.importCSV)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = authManager?.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: text/csv\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body
        return try await perform(request)
    }
}
