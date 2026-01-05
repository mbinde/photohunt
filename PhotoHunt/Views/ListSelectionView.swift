import SwiftUI
import CoreData

struct ListSelectionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var dataLoader = DataLoader()

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HuntListEntity.name, ascending: true)],
        animation: .default)
    private var lists: FetchedResults<HuntListEntity>

    var body: some View {
        NavigationStack {
            Group {
                if lists.isEmpty && dataLoader.isLoading {
                    ProgressView("Loading hunts...")
                        .font(.title2)
                } else if lists.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("No Photo Hunts Yet!")
                            .font(.title)
                        Text("Pull down to refresh")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List(lists) { list in
                        NavigationLink(destination: HuntListView(huntList: list)) {
                            HuntListRow(huntList: list)
                        }
                    }
                }
            }
            .navigationTitle("Photo Hunt!")
            .refreshable {
                await dataLoader.loadLists(context: viewContext)
            }
            .task {
                if lists.isEmpty {
                    await dataLoader.loadLists(context: viewContext)
                }
            }
        }
    }
}

struct HuntListRow: View {
    @ObservedObject var huntList: HuntListEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(huntList.name ?? "Unnamed Hunt")
                .font(.headline)

            if let description = huntList.listDescription, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack {
                let items = huntList.itemsArray
                let foundCount = items.filter { $0.isFound }.count
                Text("\(foundCount)/\(items.count) found")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if foundCount == items.count && items.count > 0 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ListSelectionView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
