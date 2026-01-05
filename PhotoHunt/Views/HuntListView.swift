import SwiftUI
import CoreData

struct HuntListView: View {
    @ObservedObject var huntList: HuntListEntity
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest private var items: FetchedResults<HuntItemEntity>

    @State private var showCelebration = false
    @State private var celebrationMilestone = 0
    @State private var lastMilestoneHit = 0
    @State private var showSlideshowGenerator = false

    init(huntList: HuntListEntity) {
        self.huntList = huntList
        self._items = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \HuntItemEntity.sortOrder, ascending: true)],
            predicate: NSPredicate(format: "list == %@", huntList)
        )
    }

    private var foundCount: Int {
        items.filter { $0.isFound }.count
    }

    private var percentComplete: Int {
        guard items.count > 0 else { return 0 }
        return (foundCount * 100) / items.count
    }

    private var currentMilestone: Int? {
        let milestones = [25, 50, 75, 100]
        return milestones.first { percentComplete >= $0 && lastMilestoneHit < $0 }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(items) { item in
                        HuntItemRow(item: item)
                    }
                }
                .padding()
            }

            if showCelebration {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                CelebrationView(
                    milestone: celebrationMilestone,
                    isShowing: $showCelebration,
                    onCreateSlideshow: {
                        showSlideshowGenerator = true
                    }
                )
            }
        }
        .navigationTitle(huntList.name ?? "Photo Hunt")
        .toolbarBackground(Theme.lavenderLight, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // Slideshow button when complete
                    if foundCount == items.count && items.count > 0 {
                        Button {
                            showSlideshowGenerator = true
                        } label: {
                            Image(systemName: "film")
                                .foregroundStyle(Theme.accentPink)
                        }
                    }

                    ProgressIndicator(huntList: huntList)
                }
            }
        }
        .onChange(of: foundCount) { oldValue, newValue in
            if newValue > oldValue, let milestone = currentMilestone {
                celebrationMilestone = milestone
                lastMilestoneHit = milestone
                showCelebration = true
            }
        }
        .onAppear {
            // Set initial milestone so we don't celebrate on view appear
            let milestones = [100, 75, 50, 25]
            lastMilestoneHit = milestones.first { percentComplete >= $0 } ?? 0
        }
        .sheet(isPresented: $showSlideshowGenerator) {
            SlideshowGeneratorView(huntList: huntList)
        }
    }
}

struct ProgressIndicator: View {
    @ObservedObject var huntList: HuntListEntity
    @Environment(\.managedObjectContext) private var viewContext
    @State private var refreshID = UUID()

    var body: some View {
        let items = huntList.itemsArray
        let foundCount = items.filter { $0.isFound }.count
        let total = items.count
        let isComplete = foundCount == total && total > 0

        HStack(spacing: 6) {
            Text("\(foundCount)/\(total)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.textPrimary)

            if isComplete {
                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.accentPink)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.white.opacity(0.8))
        )
        .id(refreshID)
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: viewContext)) { _ in
            refreshID = UUID()
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
