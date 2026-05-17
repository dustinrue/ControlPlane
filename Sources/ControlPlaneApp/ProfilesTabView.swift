import SwiftUI
import ControlPlaneSDK

/// Top-level Profiles tab: profile list on the left, detail (rules + actions) on the right.
struct ProfilesTabView: View {

    @ObservedObject var store: ControlPlaneStore
    @State private var selectedProfileID: UUID?
    @State private var showingCreateProfile = false

    private var selectedProfile: Profile? {
        store.profiles.first { $0.id == selectedProfileID }
    }

    var body: some View {
        HSplitView {
            profileList
                .frame(minWidth: 180, maxWidth: 240)

            if let profile = selectedProfile {
                ProfileDetailView(profile: profile, store: store)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "person.2")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(store.profiles.isEmpty
                         ? "Add a profile to get started"
                         : "Select a profile")
                        .foregroundStyle(.secondary)
                    if store.profiles.isEmpty {
                        Button("Add Profile") { showingCreateProfile = true }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingCreateProfile) {
            CreateProfileView { name, threshold, exclusive in
                Task {
                    await store.createProfile(
                        name: name,
                        confidenceThreshold: threshold,
                        exclusive: exclusive
                    )
                    // Select the new profile automatically
                    selectedProfileID = store.profiles.last?.id
                }
            }
        }
    }

    // MARK: - Profile list

    private var profileList: some View {
        VStack(spacing: 0) {
            List(store.profiles, id: \.id, selection: $selectedProfileID) { profile in
                profileRow(profile)
                    .contextMenu {
                        Button("Delete Profile", role: .destructive) {
                            Task {
                                await store.deleteProfile(profile)
                                if selectedProfileID == profile.id {
                                    selectedProfileID = nil
                                }
                            }
                        }
                    }
            }
            Divider()
            HStack(spacing: 0) {
                Button(action: { showingCreateProfile = true }) {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 24)
                }
                .buttonStyle(.borderless)

                Button(action: {
                    guard let profile = selectedProfile else { return }
                    Task {
                        await store.deleteProfile(profile)
                        selectedProfileID = nil
                    }
                }) {
                    Image(systemName: "minus")
                        .frame(width: 28, height: 24)
                }
                .buttonStyle(.borderless)
                .disabled(selectedProfile == nil)

                Spacer()
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func profileRow(_ profile: Profile) -> some View {
        let active = store.isActive(profile.id)
        let conf   = store.confidence(for: profile.id)

        HStack(spacing: 6) {
            Circle()
                .fill(active ? Color.green : Color.secondary.opacity(0.3))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.name)
                    .fontWeight(active ? .semibold : .regular)
                    .lineLimit(1)
                if let conf {
                    Text(String(format: "%.2f confidence", conf))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 1)
    }
}

// MARK: - Create Profile Sheet

struct CreateProfileView: View {
    let onSave: (String, Double, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var threshold = 1.0
    @State private var exclusive = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("New Profile")
                .font(.headline)

            Form {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                LabeledContent("Confidence Threshold") {
                    HStack {
                        Slider(value: $threshold, in: 0.1...5.0, step: 0.1)
                        Text(String(format: "%.1f", threshold))
                            .frame(width: 36, alignment: .trailing)
                            .monospacedDigit()
                    }
                }

                Toggle("Exclusive (deactivates other profiles)", isOn: $exclusive)
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    onSave(name, threshold, exclusive)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}
