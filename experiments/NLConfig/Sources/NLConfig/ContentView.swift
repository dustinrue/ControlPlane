import SwiftUI

struct ContentView: View {
    @StateObject private var parser = NLParser()
    @State private var input = ""

    private let examples = [
        "Start Chrome when I connect my LG monitor",
        "Lock my keychain and turn off Wi-Fi when my screen locks",
        "Mount my NAS when I connect to my home Wi-Fi",
        "Switch to my Work profile when I'm on CorpWiFi and plugged in to power",
        "Open Spotify when my AirPods connect",
        "Send a notification when my backup drive is not mounted at 9am on weekdays",
        "Quit Slack when I disconnect from the office network",
        "When I'm not at home and not at work, activate an Offline profile",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    inputSection
                    if !parser.modelAvailable, let err = parser.error {
                        unavailableView(message: err)
                    } else {
                        examplesSection
                        if parser.isLoading {
                            loadingView
                        } else if let result = parser.result {
                            resultView(result)
                        }
                        if let err = parser.error, parser.modelAvailable {
                            errorView(message: err)
                            if let attempt = parser.decodedAttempt {
                                rawResponseView(attempt, label: "Text sent to JSON decoder")
                            } else if let raw = parser.rawResponse {
                                rawResponseView(raw, label: "Raw model response")
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 800, minHeight: 700)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain")
                .font(.title)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("ControlPlane — Natural Language Config")
                    .font(.headline)
                Text("Test harness for Apple on-device AI configuration (issue #536)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            availabilityBadge
        }
        .padding(16)
        .background(.bar)
    }

    private var availabilityBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(parser.modelAvailable ? .green : .orange)
                .frame(width: 8, height: 8)
            Text(parser.modelAvailable ? "Model available" : "Model unavailable")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Describe what you want ControlPlane to do")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 8) {
                TextField("e.g. \"Start Chrome when I attach my LG monitor\"",
                          text: $input)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .disabled(!parser.modelAvailable)
                    .onSubmit { submit() }

                Button(action: submit) {
                    if parser.isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 60)
                    } else {
                        Text("Parse")
                            .frame(width: 60)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!parser.modelAvailable || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parser.isLoading)
                .keyboardShortcut(.return)
            }
        }
    }

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try an example")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            FlowLayout(spacing: 8) {
                ForEach(examples, id: \.self) { example in
                    Button(example) {
                        input = example
                        submit()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!parser.modelAvailable || parser.isLoading)
                }
            }
        }
    }

    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Running on-device model…")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private func unavailableView(message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Apple Intelligence unavailable")
                    .fontWeight(.medium)
                Text(message)
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
        .padding()
        .background(.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func errorView(message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "xmark.circle")
                .foregroundStyle(.red)
            Text(message)
                .foregroundStyle(.secondary)
                .font(.callout)
        }
        .padding()
        .background(.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func rawResponseView(_ text: String, label: String = "Raw model response") -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: "doc.plaintext")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            ScrollView(.vertical) {
                Text(text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(maxHeight: 300)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Result

    private func resultView(_ config: ParsedConfig) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()

            // Summary
            VStack(alignment: .leading, spacing: 6) {
                Label("Result", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)

                Text(config.explanation)
                    .padding(10)
                    .background(.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Assumptions
            if !config.assumptions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Assumptions", systemImage: "info.circle")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                    ForEach(config.assumptions, id: \.self) { assumption in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•").foregroundStyle(.orange)
                            Text(assumption).font(.callout)
                        }
                    }
                }
            }

            // Profile
            SectionBox(title: "Profile", icon: "person.crop.rectangle") {
                KeyValueRow(key: "Name", value: config.profileName)
                KeyValueRow(key: "Threshold", value: String(format: "%.2f", config.confidenceThreshold))
            }

            // Rules
            if !config.rules.isEmpty {
                SectionBox(title: "Rules (\(config.rules.count))", icon: "ruler") {
                    ForEach(Array(config.rules.enumerated()), id: \.offset) { i, rule in
                        if i > 0 { Divider() }
                        RuleView(rule: rule)
                    }
                }
            }

            // Actions
            if !config.actions.isEmpty {
                SectionBox(title: "Actions (\(config.actions.count))", icon: "bolt") {
                    ForEach(Array(config.actions.enumerated()), id: \.offset) { i, action in
                        if i > 0 { Divider() }
                        ActionView(action: action)
                    }
                }
            }

            // cpctl commands
            SectionBox(title: "cpctl commands", icon: "terminal") {
                Text(cpctlCommands(for: config))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - cpctl generation

    private func cpctlCommands(for config: ParsedConfig) -> String {
        var lines: [String] = []
        if config.createProfile {
            lines.append("# Create profile")
            lines.append("cpctl profiles add \"\(config.profileName)\" --threshold \(String(format: "%.2f", config.confidenceThreshold))")
        } else {
            lines.append("# Profile '\(config.profileName)' assumed to already exist")
            lines.append("# To update its threshold: cpctl profiles update \"\(config.profileName)\" --threshold \(String(format: "%.2f", config.confidenceThreshold))")
        }
        lines.append("")
        lines.append("# Add rules")
        for rule in config.rules {
            var cmd = "cpctl rules add"
            cmd += " --profile \"\(config.profileName)\""
            cmd += " --sensor \(rule.sensorID)"
            cmd += " --key \(rule.readingKey)"
            cmd += " --op \(rule.operatorID)"
            cmd += " --value \"\(rule.comparandValue)\""
            cmd += " --weight \(String(format: "%.1f", rule.weight))"
            if rule.negate { cmd += " --negate" }
            if !rule.name.isEmpty { cmd += " --name \"\(rule.name)\"" }
            lines.append(cmd)
        }
        if !config.actions.isEmpty {
            lines.append("")
            lines.append("# Get profile UUID for actions")
            lines.append("PROFILE_ID=$(cpctl profiles list --json | jq -r '.[] | select(.name==\"\(config.profileName)\") | .id')")
            lines.append("")
            lines.append("# Add actions")
            for action in config.actions {
                var cmd = "cpctl actions add"
                cmd += " --profile \"$PROFILE_ID\""
                cmd += " --action \(action.actionID)"
                cmd += " --trigger \(action.trigger)"
                for entry in action.configEntries {
                    cmd += " --config \(entry.key)=\"\(entry.value)\""
                }
                lines.append(cmd)
            }
        }
        return lines.joined(separator: "\n")
    }

    private func submit() {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Task { await parser.parse(input: input) }
    }
}

// MARK: - Sub-views

struct SectionBox<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.medium)
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(12)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct KeyValueRow: View {
    let key: String
    let value: String

    var body: some View {
        HStack {
            Text(key)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
            Spacer()
        }
        .font(.callout)
    }
}

struct RuleView: View {
    let rule: ParsedRule

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(rule.name.isEmpty ? "Rule" : rule.name)
                    .fontWeight(.medium)
                if rule.negate {
                    Text("NEGATED")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
                Spacer()
                Text("weight \(String(format: "%.1f", rule.weight))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Text(rule.sensorID)
                    .font(.caption)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text(rule.readingKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(rule.operatorID)
                    .font(.caption)
                    .foregroundStyle(.purple)
                Text("\"\(rule.comparandValue)\"")
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
        }
        .font(.callout)
    }
}

struct ActionView: View {
    let action: ParsedAction

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(action.actionID)
                    .fontWeight(.medium)
                    .font(.callout)
                Spacer()
                Text(action.trigger)
                    .font(.caption)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(action.trigger == "onActivate" ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .foregroundStyle(action.trigger == "onActivate" ? .green : .red)
                    .clipShape(Capsule())
            }
            ForEach(action.configEntries, id: \.key) { entry in
                HStack(spacing: 6) {
                    Text(entry.key)
                        .foregroundStyle(.secondary)
                    Text("=")
                        .foregroundStyle(.secondary)
                    Text(entry.value)
                }
                .font(.caption)
            }
        }
    }
}

// Simple flow layout for wrapping chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
