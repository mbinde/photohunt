import SwiftUI

struct SettingsView: View {
    @ObservedObject var dataLoader: DataLoader
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Use Server Data", isOn: $dataLoader.useServerData)
                } footer: {
                    Text("When enabled, lists are loaded from your server URL instead of sample data.")
                }

                if dataLoader.useServerData {
                    Section {
                        TextField("https://example.com/lists.json", text: $dataLoader.serverURL)
                            .textContentType(.URL)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    } header: {
                        Text("Server URL")
                    } footer: {
                        Text("Pull down on the main screen to refresh from this URL.")
                    }
                }

                if let error = dataLoader.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.lavenderLight, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Theme.lavender)
                }
            }
        }
    }
}

#Preview {
    SettingsView(dataLoader: DataLoader())
}
