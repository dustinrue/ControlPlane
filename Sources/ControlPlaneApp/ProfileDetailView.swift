import SwiftUI
import ControlPlaneSDK

/// Detail panel for a single selected profile: metadata editor + Rules/Actions tabs.
struct ProfileDetailView: View {

    let profile: Profile
    @ObservedObject var store: ControlPlaneStore

    @State private var editName: String
    @State private var editThreshold: Double
    @State private var editExclusive: Bool
    @State private var detailTab = 0

    init(profile: Profile, store: ControlPlaneStore) {
        self.profile = profile
        self.store = store
        _editName      = State(initialValue: profile.name)
        _editThreshold = State(initialValue: profile.confidenceThreshold)
        _editExclusive = State(initialValue: profile.exclusive)
    }

    private var rules:   [Rule]          { store.rules(for: profile.id) }
    private var actions: [ProfileAction] { store.actions(for: profile.id) }
    private var isActive: Bool           { store.isActive(profile.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            TabView(selection: $detailTab) {
                RulesListView(profile: profile, store: store)
                    .tabItem { Text("Rules (\(rules.count))") }
                    .tag(0)
                ActionsListView(profile: profile, store: store)
                    .tabItem { Text("Actions (\(actions.count))") }
                    .tag(1)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 20) {
            // Editable fields
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Name:")
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .trailing)
                    TextField("Profile name", text: $editName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                        .onSubmit { saveIfChanged() }
                }

                HStack {
                    Text("Threshold:")
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .trailing)
                    Slider(value: $editThreshold, in: 0.1...5.0, step: 0.1)
                        .frame(maxWidth: 180)
                    Text(String(format: "%.1f", editThreshold))
                        .monospacedDigit()
                        .frame(width: 36, alignment: .leading)
                }

                HStack {
                    Text("")
                        .frame(width: 80, alignment: .trailing)
                    Toggle("Exclusive", isOn: $editExclusive)
                        .onChange(of: editExclusive) { _ in saveIfChanged() }
                }
            }

            Spacer()

            // Status badge
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isActive ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 10, height: 10)
                    Text(isActive ? "Active" : "Inactive")
                        .font(.callout)
                        .foregroundStyle(isActive ? .primary : .secondary)
                }
                if let conf = store.confidence(for: profile.id) {
                    Text(String(format: "Confidence: %.2f", conf))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if editName != profile.name || editThreshold != profile.confidenceThreshold {
                Button("Save") { saveIfChanged() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding()
    }

    private func saveIfChanged() {
        let trimmed = editName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        Task {
            await store.updateProfile(
                profile,
                name: trimmed,
                confidenceThreshold: editThreshold,
                exclusive: editExclusive
            )
        }
    }
}
