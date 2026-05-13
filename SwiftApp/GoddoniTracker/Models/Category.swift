import Foundation

struct CategoryModel: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let sortOrder: Int
}
