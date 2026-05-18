import SwiftUI
import ControlPlaneSDK

/// Root view for the Settings window.
/// Tab order follows the GUI plan: Profiles → Actions → Sensors → General.
struct PreferencesView: View {

    @StateObject private var store: ControlPlaneStore

    init(store: ControlPlaneStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        TabView {
            ProfilesTabView(store: store)
                .tabItem { Label("Profiles", systemImage: "person.2") }

            ActionsTabView(store: store)
                .tabItem { Label("Actions", systemImage: "bolt") }

            SensorsTabView(store: store)
                .tabItem { Label("Sensors", systemImage: "waveform") }

            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }
        }
        .frame(minWidth: 860, minHeight: 520)
        .task { await store.refresh() }
        .alert("Error", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            if let msg = store.errorMessage { Text(msg) }
        }
    }
}
