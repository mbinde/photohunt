import Foundation

// JSON model for loading lists from server
struct HuntListData: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let items: [HuntItemData]
}

struct HuntListsResponse: Codable {
    let lists: [HuntListData]
}
