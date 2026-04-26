import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {

    @Bindable var store: UsageStore
    @AppStorage(CCUsageRunner.userOverrideKey) private var ccusagePath: String = ""

    var body: some View {
        Form {
            Section("Display") {
                Picker("Status bar shows", selection: Binding(
                    get: { store.displayMetric },
                    set: { store.setDisplayMetric($0) }
                )) {
                    ForEach(DisplayMetric.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
                Stepper(
                    "Refresh every \(store.refreshIntervalSec)s",
                    value: Binding(
                        get: { store.refreshIntervalSec },
                        set: { store.setRefreshInterval($0) }
                    ),
                    in: 5...600,
                    step: 5
                )
            }

            Section("ccusage binary") {
                HStack {
                    TextField("Path (auto if blank)", text: $ccusagePath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Button("Browse…") { browseForBinary() }
                }
                if let resolved = CCUsageRunner.resolveBinary() {
                    Text("Resolved: \(resolved.path)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not found. Install via `npm install -g ccusage` or `brew install ccusage`.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(20)
        .frame(width: 420)
        .onChange(of: ccusagePath) { _, newValue in
            store.setBinaryOverride(newValue.isEmpty ? nil : URL(fileURLWithPath: newValue))
        }
    }

    private func browseForBinary() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.unixExecutable, .executable, .item]
        panel.message = "Select the ccusage executable"
        if panel.runModal() == .OK, let url = panel.url {
            ccusagePath = url.path
        }
    }
}
