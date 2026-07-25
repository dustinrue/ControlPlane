import SwiftUI
import ControlPlaneSDK

// MARK: - View

/// Displays all loaded sensors and the live readings for the selected one.
/// Each reading row has a [+] button to quickly create a rule from that value.
struct SensorsTabView: View {

    @ObservedObject var store: ControlPlaneStore
    @State private var selectedSensorID: String?
    @State private var quickCreateReading: SensorReading? = nil

    var body: some View {
        HSplitView {
            sensorList
                .frame(minWidth: 190, maxWidth: 260)

            if let id = selectedSensorID, let snapshot = store.snapshot(for: id) {
                sensorDetail(snapshot)
            } else {
                Text("Select a sensor to view its readings")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if selectedSensorID == nil {
                selectedSensorID = store.snapshots.first?.sensorID
            }
        }
        .onChange(of: store.snapshots.count) { _ in
            // Keep selection valid when snapshots update
            if let id = selectedSensorID, store.snapshot(for: id) == nil {
                selectedSensorID = store.snapshots.first?.sensorID
            }
        }
        .sheet(item: $quickCreateReading) { reading in
            if let snapshot = store.snapshot(for: selectedSensorID ?? "") {
                QuickCreateRuleView(snapshot: snapshot, reading: reading, store: store)
            }
        }
    }

    // MARK: - Sensor list

    private var sensorList: some View {
        VStack(spacing: 0) {
            List(store.snapshots, id: \.sensorID, selection: $selectedSensorID) { snapshot in
                HStack(spacing: 6) {
                    Circle()
                        .fill(snapshot.isActive ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                    Text(snapshot.displayName)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            Divider()
            HStack {
                Text("\(store.snapshots.count) sensors")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: { Task { await store.refreshSnapshots() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh sensor readings")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Sensor detail

    private func sensorDetail(_ snapshot: SensorSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.displayName).font(.headline)
                    Text(snapshot.sensorID).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(snapshot.isActive ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                    Text(snapshot.isActive ? "Active" : "Inactive")
                        .font(.caption)
                        .foregroundStyle(snapshot.isActive ? .primary : .secondary)
                }
            }
            .padding()

            Divider()

            if snapshot.readings.isEmpty {
                Text("No readings available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(snapshot.readings) {
                    TableColumn("Key") { r in
                        Text(r.key)
                            .font(.system(.body, design: .monospaced))
                    }
                    TableColumn("Label") { r in
                        Text(r.label)
                    }
                    TableColumn("Value") { r in
                        Text(r.value.description)
                            .font(.system(.body, design: .monospaced))
                    }
                    TableColumn("") { r in
                        Button {
                            quickCreateReading = r
                        } label: {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.borderless)
                        .help("Create rule from this reading")
                    }
                    .width(28)
                }
            }

            Divider()
            Text("Captured: \(snapshot.capturedAt.formatted(date: .omitted, time: .complete))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 6)
        }
    }
}
