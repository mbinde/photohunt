import Foundation
import CoreData

@MainActor
class DataLoader: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    // TODO: Replace with actual server URL
    private let dataURL = URL(string: "https://example.com/photohunt/lists.json")

    func loadLists(context: NSManagedObjectContext) async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        // For now, load sample data since we don't have a server yet
        await loadSampleData(context: context)
    }

    private func loadSampleData(context: NSManagedObjectContext) async {
        // Check if we already have data
        let request: NSFetchRequest<HuntListEntity> = HuntListEntity.fetchRequest()
        if let count = try? context.count(for: request), count > 0 {
            return
        }

        // Sample lists for testing
        let sampleLists: [(name: String, description: String, items: [String])] = [
            (
                name: "Backyard Adventure",
                description: "Find these things in your backyard!",
                items: ["A red flower", "A smooth rock", "A butterfly", "Something blue", "A pinecone", "A feather", "A ladybug", "Clover with 3 leaves"]
            ),
            (
                name: "Nature Walk",
                description: "Things to find on a nature walk",
                items: ["A tall tree", "A bird", "A mushroom", "Something yellow", "A spider web", "A squirrel", "Moss on a rock", "A puddle"]
            ),
            (
                name: "Indoor Scavenger Hunt",
                description: "Find these things around the house!",
                items: ["Something soft", "A book with a red cover", "A clock", "Something round", "A mirror", "Something that makes noise", "A plant", "Something cold"]
            )
        ]

        for listData in sampleLists {
            let list = HuntListEntity(context: context)
            list.id = UUID()
            list.name = listData.name
            list.listDescription = listData.description
            list.createdAt = Date()

            for (index, itemName) in listData.items.enumerated() {
                let item = HuntItemEntity(context: context)
                item.id = UUID()
                item.name = itemName
                item.sortOrder = Int16(index)
                item.isFound = false
                item.list = list
            }
        }

        do {
            try context.save()
        } catch {
            errorMessage = "Failed to save data: \(error.localizedDescription)"
        }
    }

    // For future use when server is ready
    private func loadFromServer(context: NSManagedObjectContext) async {
        guard let url = dataURL else {
            errorMessage = "Invalid URL"
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(HuntListsResponse.self, from: data)

            // Clear existing data and import new
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = HuntListEntity.fetchRequest()
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try? context.execute(deleteRequest)

            for listData in response.lists {
                let list = HuntListEntity(context: context)
                list.id = UUID()
                list.name = listData.name
                list.listDescription = listData.description
                list.createdAt = Date()

                for (index, itemData) in listData.items.enumerated() {
                    let item = HuntItemEntity(context: context)
                    item.id = UUID()
                    item.name = itemData.name
                    item.hint = itemData.hint
                    item.sortOrder = Int16(index)
                    item.isFound = false
                    item.list = list
                }
            }

            try context.save()
        } catch {
            errorMessage = "Failed to load data: \(error.localizedDescription)"
        }
    }
}
