import SwiftUI
import CoreData

struct HuntListView: View {
    @ObservedObject var huntList: HuntListEntity
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        List {
            ForEach(huntList.itemsArray) { item in
                HuntItemRow(item: item)
            }
        }
        .navigationTitle(huntList.name ?? "Photo Hunt")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ProgressIndicator(huntList: huntList)
            }
        }
    }
}

struct ProgressIndicator: View {
    @ObservedObject var huntList: HuntListEntity

    var body: some View {
        let items = huntList.itemsArray
        let foundCount = items.filter { $0.isFound }.count
        let total = items.count

        HStack(spacing: 4) {
            Text("\(foundCount)/\(total)")
                .font(.subheadline)
                .fontWeight(.medium)

            if foundCount == total && total > 0 {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
            }
        }
    }
}

#Preview {
    NavigationStack {
        HuntListView(huntList: {
            let context = PersistenceController.preview.container.viewContext
            let request: NSFetchRequest<HuntListEntity> = HuntListEntity.fetchRequest()
            return try! context.fetch(request).first!
        }())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
