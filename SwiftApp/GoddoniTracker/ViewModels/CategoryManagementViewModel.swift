import Foundation

@Observable
final class CategoryManagementViewModel {
    var categories: [CategoryModel] = []
    var isLoading = false
    var errorMessage: String?

    func load(api: APIClient) async {
        isLoading = true
        do {
            categories = try await api.getCategories()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addCategory(name: String, api: APIClient) async -> Bool {
        do {
            let cat = try await api.createCategory(name)
            categories.append(cat)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func renameCategory(id: Int, name: String, api: APIClient) async -> Bool {
        do {
            let updated = try await api.updateCategory(id, name: name)
            if let idx = categories.firstIndex(where: { $0.id == id }) {
                categories[idx] = updated
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteCategory(id: Int, api: APIClient) async -> Bool {
        do {
            try await api.deleteCategory(id)
            categories.removeAll { $0.id == id }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
    }

    func saveOrder(api: APIClient) async {
        let order = categories.map(\.id)
        try? await api.reorderCategories(order)
    }
}
