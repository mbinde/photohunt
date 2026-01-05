import SwiftUI
import CoreData

struct ListSelectionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var dataLoader = DataLoader()
    @State private var showingSettings = false
    @State private var slideshowHuntList: HuntListEntity?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HuntListEntity.name, ascending: true)],
        animation: .default)
    private var lists: FetchedResults<HuntListEntity>

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                Group {
                    if lists.isEmpty && dataLoader.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(Theme.lavender)
                            Text("Loading hunts...")
                                .font(.title2)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    } else if lists.isEmpty {
                        VStack(spacing: 20) {
                            Image("photohunt")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 100)

                            Text("No Photo Hunts Yet!")
                                .font(.title)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.textPrimary)
                            Text("Pull down to refresh")
                                .foregroundStyle(Theme.textSecondary)
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                // Logo at the top
                                Image("photohunt")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 80)
                                    .padding(.top, 8)

                                LazyVStack(spacing: 12) {
                                    ForEach(lists) { list in
                                        NavigationLink(destination: HuntListView(huntList: list)) {
                                            HuntListCard(huntList: list, onSlideshow: {
                                                slideshowHuntList = list
                                            })
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Theme.lavender)
                    }
                }
            }
            .refreshable {
                await dataLoader.loadLists(context: viewContext, forceReload: true)
            }
            .task {
                if lists.isEmpty {
                    await dataLoader.loadLists(context: viewContext)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(dataLoader: dataLoader)
            }
            .sheet(item: $slideshowHuntList) { huntList in
                SlideshowGeneratorView(huntList: huntList)
            }
        }
        .tint(Theme.lavender)
    }
}

struct HuntListCard: View {
    @ObservedObject var huntList: HuntListEntity
    @Environment(\.managedObjectContext) private var viewContext
    @State private var refreshID = UUID()
    var onSlideshow: (() -> Void)? = nil

    var body: some View {
        let items = huntList.itemsArray
        let foundItems = items.filter { $0.isFound }
        let foundCount = foundItems.count
        let isComplete = foundCount == items.count && items.count > 0
        let progress = items.count > 0 ? Double(foundCount) / Double(items.count) : 0

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(huntList.name ?? "Unnamed Hunt")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                if isComplete {
                    Button {
                        onSlideshow?()
                    } label: {
                        Image(systemName: "film")
                            .font(.title3)
                            .foregroundStyle(Theme.accentPink)
                    }

                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(Theme.accentPink)
                }
            }

            if let description = huntList.listDescription, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }

            // Photo mosaic progress bar
            HStack(spacing: 12) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.lavenderLight)

                        // Photo mosaic fill
                        if foundCount > 0 {
                            AnimatedPhotoMosaic(
                                foundItems: foundItems,
                                progress: progress,
                                totalWidth: geometry.size.width,
                                isComplete: isComplete
                            )
                        }
                    }
                }
                .frame(height: 32)

                Text("\(foundCount)/\(items.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(minWidth: 35)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: Theme.lavender.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isComplete ? Theme.found : Theme.lavenderLight, lineWidth: 2)
        )
        .id(refreshID)
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            refreshID = UUID()
        }
    }
}

class SlotCoordinator: ObservableObject {
    private var usedItemIds: Set<UUID> = []

    func claimItem(_ item: HuntItemEntity) {
        if let id = item.id {
            usedItemIds.insert(id)
        }
    }

    func releaseItem(_ item: HuntItemEntity) {
        if let id = item.id {
            usedItemIds.remove(id)
        }
    }

    func pickAvailableItem(from items: [HuntItemEntity], excluding currentItem: HuntItemEntity?) -> HuntItemEntity? {
        let currentId = currentItem?.id
        let available = items.filter { item in
            guard let id = item.id else { return false }
            // Exclude current item and items already in use by other slots
            return id != currentId && !usedItemIds.contains(id)
        }
        return available.randomElement()
    }
}

struct AnimatedPhotoMosaic: View {
    let foundItems: [HuntItemEntity]
    let progress: Double
    let totalWidth: CGFloat
    let isComplete: Bool

    let maxSlots = 10
    @StateObject private var coordinator = SlotCoordinator()

    var body: some View {
        // Number of visible slots based on progress (at least 1 if we have any photos)
        let visibleSlots = max(1, Int(round(Double(maxSlots) * progress)))
        let slotWidth = totalWidth / Double(maxSlots)
        let mosaicWidth = slotWidth * Double(visibleSlots)

        // Can twinkle if we have more photos than visible slots
        let canTwinkle = foundItems.count > visibleSlots

        HStack(spacing: 0) {
            ForEach(0..<visibleSlots, id: \.self) { index in
                TwinklingPhotoSlot(
                    allPhotos: foundItems,
                    slotIndex: index,
                    width: slotWidth,
                    coordinator: coordinator,
                    canTwinkle: canTwinkle
                )
            }
        }
        .frame(width: mosaicWidth, height: 32)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isComplete ? Theme.found : Theme.lavender, lineWidth: 2)
        )
    }
}

struct TwinklingPhotoSlot: View {
    let allPhotos: [HuntItemEntity]
    let slotIndex: Int
    let width: CGFloat
    let coordinator: SlotCoordinator
    let canTwinkle: Bool

    @State private var currentItem: HuntItemEntity?
    @State private var nextItem: HuntItemEntity?
    @State private var showingNext = false

    var body: some View {
        ZStack {
            if let current = currentItem {
                PhotoSlotImage(item: current, width: width)
                    .opacity(showingNext ? 0 : 1)
            }

            if let next = nextItem {
                PhotoSlotImage(item: next, width: width)
                    .opacity(showingNext ? 1 : 0)
            }
        }
        .frame(width: width, height: 32)
        .clipped()
        .onAppear {
            pickInitialPhoto()
            if canTwinkle {
                startTwinkling()
            }
        }
    }

    private func pickInitialPhoto() {
        // For initial assignment, just pick based on slot index to avoid duplicates
        if slotIndex < allPhotos.count {
            currentItem = allPhotos[slotIndex]
            if let item = currentItem {
                coordinator.claimItem(item)
            }
        } else if !allPhotos.isEmpty {
            // More slots than photos - pick randomly
            currentItem = allPhotos.randomElement()
            if let item = currentItem {
                coordinator.claimItem(item)
            }
        }
    }

    private func startTwinkling() {
        // Each slot has its own random delay between 2 and 5 seconds
        let baseDelay = Double.random(in: 2.0...5.0)
        // Stagger initial start based on slot index
        let initialDelay = Double(slotIndex) * 0.3 + Double.random(in: 0...0.5)

        DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay) {
            scheduleTwinkle(interval: baseDelay)
        }
    }

    private func scheduleTwinkle(interval: Double) {
        // Vary the interval slightly each time for organic feel
        let nextInterval = interval + Double.random(in: -0.5...0.5)

        DispatchQueue.main.asyncAfter(deadline: .now() + max(2.0, nextInterval)) {
            // Pick a photo that's not current and not in another slot
            guard let newItem = coordinator.pickAvailableItem(from: allPhotos, excluding: currentItem) else {
                // No available items, try again later
                scheduleTwinkle(interval: nextInterval)
                return
            }

            nextItem = newItem
            coordinator.claimItem(newItem)

            withAnimation(.easeInOut(duration: 0.6)) {
                showingNext = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                // Release the old item
                if let old = currentItem {
                    coordinator.releaseItem(old)
                }
                currentItem = nextItem
                showingNext = false
                scheduleTwinkle(interval: nextInterval)
            }
        }
    }
}

struct PhotoSlotImage: View {
    let item: HuntItemEntity
    let width: CGFloat

    var body: some View {
        if let photoData = item.photoData,
           let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: 32)
                .clipped()
        }
    }
}

#Preview {
    ListSelectionView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
