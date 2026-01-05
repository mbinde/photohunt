import SwiftUI

struct ContentView: View {
    var body: some View {
        ListSelectionView()
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
