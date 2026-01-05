import Foundation
import CoreData

@MainActor
class DataLoader: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var useServerData: Bool {
        didSet {
            UserDefaults.standard.set(useServerData, forKey: "useServerData")
        }
    }

    @Published var serverURL: String {
        didSet {
            UserDefaults.standard.set(serverURL, forKey: "serverURL")
        }
    }

    init() {
        self.useServerData = UserDefaults.standard.bool(forKey: "useServerData")
        self.serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? "https://photohunt.motleywoods.dev/api/v1/lists.json"
    }

    func loadLists(context: NSManagedObjectContext, forceReload: Bool = false) async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        print("🔄 loadLists called - forceReload: \(forceReload), useServerData: \(useServerData), serverURL: \(serverURL)")

        if useServerData && !serverURL.isEmpty {
            print("📡 Loading from server...")
            await loadFromServer(context: context, forceReload: forceReload)
        } else {
            print("📦 Loading sample data (useServerData: \(useServerData), serverURL empty: \(serverURL.isEmpty))")
            await loadSampleData(context: context, forceReload: forceReload)
        }
    }

    private func loadSampleData(context: NSManagedObjectContext, forceReload: Bool) async {
        // Check if we already have data (unless force reload)
        if !forceReload {
            let request: NSFetchRequest<HuntListEntity> = HuntListEntity.fetchRequest()
            if let count = try? context.count(for: request), count > 0 {
                return
            }
        }

        // Sample lists for testing with stable IDs
        let sampleLists: [(id: String, name: String, description: String, items: [(id: String, name: String)])] = [
            (
                id: "backyard-adventure",
                name: "Backyard Adventure",
                description: "Find these things in your backyard!",
                items: [
                    ("ba-01", "A red flower"), ("ba-02", "A smooth rock"), ("ba-03", "A butterfly"),
                    ("ba-04", "Something blue"), ("ba-05", "A pinecone"), ("ba-06", "A feather"),
                    ("ba-07", "A ladybug"), ("ba-08", "Clover with 3 leaves"), ("ba-09", "A dandelion"),
                    ("ba-10", "An ant"), ("ba-11", "A leaf with holes"), ("ba-12", "Something prickly"),
                    ("ba-13", "A worm"), ("ba-14", "Bird poop"), ("ba-15", "A stick shaped like a Y"),
                    ("ba-16", "A fuzzy caterpillar"), ("ba-17", "Dew drops"), ("ba-18", "A spiderweb"),
                    ("ba-19", "Something purple"), ("ba-20", "A seed pod")
                ]
            ),
            (
                id: "nature-walk",
                name: "Nature Walk",
                description: "Things to find on a nature walk",
                items: [
                    ("nw-01", "A tall tree"), ("nw-02", "A bird"), ("nw-03", "A mushroom"),
                    ("nw-04", "Something yellow"), ("nw-05", "A spider web"), ("nw-06", "A squirrel"),
                    ("nw-07", "Moss on a rock"), ("nw-08", "A puddle"), ("nw-09", "Animal tracks"),
                    ("nw-10", "A fallen log"), ("nw-11", "A creek or stream"), ("nw-12", "A pine needle"),
                    ("nw-13", "Berries on a bush"), ("nw-14", "A hole in a tree"), ("nw-15", "Lichen"),
                    ("nw-16", "A fern"), ("nw-17", "An acorn"), ("nw-18", "A cool cloud shape"),
                    ("nw-19", "Something fuzzy"), ("nw-20", "A bug under a rock")
                ]
            ),
            (
                id: "indoor-scavenger",
                name: "Indoor Scavenger Hunt",
                description: "Find these things around the house!",
                items: [
                    ("is-01", "Something soft"), ("is-02", "A book with a red cover"), ("is-03", "A clock"),
                    ("is-04", "Something round"), ("is-05", "A mirror"), ("is-06", "Something that makes noise"),
                    ("is-07", "A plant"), ("is-08", "Something cold"), ("is-09", "A magnet"),
                    ("is-10", "Something striped"), ("is-11", "A button"), ("is-12", "Something you plug in"),
                    ("is-13", "A photo of a baby"), ("is-14", "Something smaller than your thumb"), ("is-15", "A rubber band"),
                    ("is-16", "Something with batteries"), ("is-17", "A fork"), ("is-18", "Something that smells good"),
                    ("is-19", "A coin"), ("is-20", "Your favorite toy")
                ]
            )
        ]

        await mergeListData(sampleLists, into: context)
    }

    private func mergeListData(_ listsData: [(id: String, name: String, description: String, items: [(id: String, name: String)])], into context: NSManagedObjectContext) async {
        for listData in listsData {
            // Find or create list by serverId
            let listRequest: NSFetchRequest<HuntListEntity> = HuntListEntity.fetchRequest()
            listRequest.predicate = NSPredicate(format: "serverId == %@", listData.id)

            let list: HuntListEntity
            if let existingList = try? context.fetch(listRequest).first {
                list = existingList
                // Update mutable fields
                list.name = listData.name
                list.listDescription = listData.description
            } else {
                list = HuntListEntity(context: context)
                list.id = UUID()
                list.serverId = listData.id
                list.name = listData.name
                list.listDescription = listData.description
                list.createdAt = Date()
            }

            // Build a map of existing items by serverId for quick lookup
            let existingItems = list.itemsArray
            var existingItemsMap: [String: HuntItemEntity] = [:]
            for item in existingItems {
                if let serverId = item.serverId {
                    existingItemsMap[serverId] = item
                }
            }

            // Track which serverIds are in the new data
            var newServerIds: Set<String> = []

            for (index, itemData) in listData.items.enumerated() {
                newServerIds.insert(itemData.id)

                if let existingItem = existingItemsMap[itemData.id] {
                    // Update existing item (preserve photo progress)
                    existingItem.name = itemData.name
                    existingItem.sortOrder = Int16(index)
                    // Keep: isFound, photoData, foundAt, latitude, longitude
                } else {
                    // Create new item
                    let item = HuntItemEntity(context: context)
                    item.id = UUID()
                    item.serverId = itemData.id
                    item.name = itemData.name
                    item.sortOrder = Int16(index)
                    item.isFound = false
                    item.list = list
                }
            }

            // Optionally: remove items that are no longer in the server data
            // (Comment out if you want to keep orphaned items)
            // for (serverId, item) in existingItemsMap {
            //     if !newServerIds.contains(serverId) {
            //         context.delete(item)
            //     }
            // }
        }

        do {
            try context.save()
        } catch {
            errorMessage = "Failed to save data: \(error.localizedDescription)"
        }
    }

    private func loadFromServer(context: NSManagedObjectContext, forceReload: Bool = false) async {
        // Check if we already have data (unless force reload)
        if !forceReload {
            let request: NSFetchRequest<HuntListEntity> = HuntListEntity.fetchRequest()
            if let count = try? context.count(for: request), count > 0 {
                print("📡 Server load skipped - already have \(count) lists and forceReload is false")
                return
            }
        }

        guard let url = URL(string: serverURL) else {
            print("❌ Invalid URL: \(serverURL)")
            errorMessage = "Invalid URL"
            return
        }

        print("📡 Fetching from: \(url)")

        // Use withCheckedContinuation to prevent SwiftUI's refreshable from cancelling the request
        let result: Result<Data, Error> = await withCheckedContinuation { continuation in
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    continuation.resume(returning: .failure(error))
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 HTTP Status: \(httpResponse.statusCode)")
                }

                if let data = data {
                    print("📡 Received \(data.count) bytes")
                    continuation.resume(returning: .success(data))
                } else {
                    continuation.resume(returning: .failure(NSError(domain: "DataLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                }
            }
            task.resume()
        }

        switch result {
        case .success(let data):
            // Debug: print raw JSON
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📡 Raw JSON (first 500 chars): \(String(jsonString.prefix(500)))")
            }

            do {
                let decoded = try JSONDecoder().decode(HuntListsResponse.self, from: data)
                print("📡 Decoded \(decoded.lists.count) lists")

                // Convert to merge format
                let listsData = decoded.lists.map { listData in
                    (
                        id: listData.id,
                        name: listData.name,
                        description: listData.description ?? "",
                        items: listData.items.map { ($0.id, $0.name) }
                    )
                }

                await mergeListData(listsData, into: context)
                print("✅ Server data merged successfully")
            } catch {
                print("❌ Error decoding JSON: \(error)")
                errorMessage = "Failed to decode data: \(error.localizedDescription)"
            }

        case .failure(let error):
            print("❌ Error loading from server: \(error)")
            errorMessage = "Failed to load data: \(error.localizedDescription)"
        }
    }
}
