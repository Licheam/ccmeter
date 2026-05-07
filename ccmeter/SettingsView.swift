import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {

    @Bindable var store: UsageStore
    @AppStorage(CCUsageRunner.userOverrideKey) private var ccusagePath: String = ""
    @AppStorage(UsageStore.customPricingEnabledKey) private var customPricingEnabled: Bool = false
    @AppStorage(UsageStore.customPricingPathKey) private var customPricingPath: String = ""

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

            Section("Custom pricing") {
                Toggle("Use custom pricing", isOn: $customPricingEnabled)
                HStack {
                    TextField("Path to pricing JSON", text: $customPricingPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .disabled(!customPricingEnabled)
                    Button("Browse…") { browseForPricingFile() }
                        .disabled(!customPricingEnabled)
                }
                if let err = store.pricingOverridesError {
                    Text("Pricing file error: \(err)")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                } else if customPricingEnabled, let count = store.pricingOverrides?.models.count {
                    Text("Loaded \(count) model override\(count == 1 ? "" : "s").")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if customPricingEnabled {
                    Text("LiteLLM-style fields, e.g. input_cost_per_token.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button("Save example file…") { saveExampleFile() }
            }
        }
        .padding(20)
        .frame(width: 520)
        .onChange(of: ccusagePath) { _, newValue in
            store.setBinaryOverride(newValue.isEmpty ? nil : URL(fileURLWithPath: newValue))
        }
        .onChange(of: customPricingEnabled) { _, _ in
            store.setCustomPricing(enabled: customPricingEnabled, path: customPricingPath)
        }
        .onChange(of: customPricingPath) { _, _ in
            store.setCustomPricing(enabled: customPricingEnabled, path: customPricingPath)
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

    private func browseForPricingFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        panel.message = "Select a pricing JSON file"
        if panel.runModal() == .OK, let url = panel.url {
            customPricingPath = url.path
        }
    }

    private func saveExampleFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "ccmeter-pricing.json"
        panel.message = "Save an example pricing JSON file"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try PricingOverridesLoader.exampleJSON.write(to: url, atomically: true, encoding: .utf8)
                customPricingPath = url.path
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }
}
