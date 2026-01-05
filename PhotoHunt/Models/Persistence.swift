import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Create sample data for previews
        let sampleList = HuntListEntity(context: viewContext)
        sampleList.id = UUID()
        sampleList.name = "Backyard Adventure"
        sampleList.listDescription = "Find these things in the backyard!"
        sampleList.createdAt = Date()

        let items = ["A red flower", "A smooth rock", "A butterfly", "Something blue", "A pinecone"]
        for (index, itemName) in items.enumerated() {
            let item = HuntItemEntity(context: viewContext)
            item.id = UUID()
            item.name = itemName
            item.sortOrder = Int16(index)
            item.isFound = index < 2 // First two are "found" for preview
            item.list = sampleList
        }

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "PhotoHunt")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}
