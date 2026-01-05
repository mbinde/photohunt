import Foundation

// JSON model for loading items from server
struct HuntItemData: Codable, Identifiable {
    let id: String
    let name: String
    let hint: String?
}
