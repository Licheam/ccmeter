import SwiftUI
import AppKit

struct PopoverContent: View {

    @Bindable var store: UsageStore
    @Bindable var updater: Updater
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if !store.binaryAvailable {
                missingBinaryView
                    .padding(16)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        todaySection
                        Divider()
                        activeBlockSection
                        Divider()
                        sessionsSection
                    }
                    .padding(16)
                }
            }
            Divider()
            footer
        }
        .frame(width: 360)
        .frame(maxHeight: 520)
        .sheet(isPresented: $showSettings) {
            VStack(spacing: 0) {
                HStack {
                    Text("Settings").font(.headline)
                    Spacer()
                    Button("Done") { showSettings = false }
                        .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                SettingsView(store: store, updater: updater)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "gauge.medium")
                .foregroundStyle(.secondary)
            Text("ccmeter")
                .font(.headline)
            Spacer()
            if store.isLoading {
                ProgressView().controlSize(.small)
            }
            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var todaySection: some View {
        let today = store.daily?.today
        return VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Today", subtitle: today?.date)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                bigNumber(Formatting.fullCost(today?.totalCost ?? 0))
                bigNumber(Formatting.fullTokens(today?.totalTokens ?? 0))
                    .foregroundStyle(.secondary)
            }
            if let models = today?.modelsUsed, !models.isEmpty {
                Text(models.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let breakdowns = today?.modelBreakdowns, breakdowns.count > 1 {
                ForEach(breakdowns, id: \.modelName) { mb in
                    HStack {
                        Text(mb.modelName).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(Formatting.fullCost(mb.cost ?? 0))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var activeBlockSection: some View {
        let block = store.blocks?.active ?? store.blocks?.lastNonGap
        return VStack(alignment: .leading, spacing: 6) {
            sectionHeader(
                block?.isActive == true ? "Active 5h Block" : "Most Recent Block",
                subtitle: block.flatMap { Formatting.relativeTime(from: $0.startTime).map { "started \($0)" } }
            )
            if let block {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    bigNumber(Formatting.fullCost(block.costUSD ?? 0))
                    bigNumber(Formatting.fullTokens(block.totalTokens ?? 0))
                        .foregroundStyle(.secondary)
                }
                if let proj = block.projection,
                   let remaining = proj.remainingMinutes {
                    Text(Formatting.remainingMinutes(remaining))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let burn = block.burnRate, let tpm = burn.tokensPerMinute {
                    Text(String(format: "Burn: %.0f tok/min · $%.2f/h",
                                tpm, burn.costPerHour ?? 0))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No usage recorded.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var sessionsSection: some View {
        let sessions = Array((store.session?.topByCost ?? []).prefix(5))
        return VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Top Sessions", subtitle: nil)
            if sessions.isEmpty {
                Text("No sessions.").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(sessions) { s in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(s.displayName).lineLimit(1).truncationMode(.middle)
                            if let last = s.lastActivity {
                                Text(last).font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        Text(Formatting.fullCost(s.totalCost ?? 0))
                            .font(.body.monospacedDigit())
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private var missingBinaryView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("ccusage not found", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("Install with one of:").font(.caption)
            VStack(alignment: .leading, spacing: 4) {
                code("npm install -g ccusage")
                code("bun add -g ccusage")
            }
            HStack {
                Button("Locate ccusage…") { showSettings = true }
                Button("Retry") {
                    CCUsageRunner.resetCache()
                    Task { await store.refresh() }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if let when = store.lastRefreshAt {
                Text("Updated \(Formatting.relativeTime(from: ISO8601DateFormatter().string(from: when)) ?? "just now")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else if let err = store.lastError {
                Text(err).font(.caption2).foregroundStyle(.red).lineLimit(1)
            }
            Spacer()
            Button("Settings…") { showSettings = true }
                .buttonStyle(.borderless)
                .font(.caption)
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
                .font(.caption)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func sectionHeader(_ title: String, subtitle: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.subheadline.weight(.semibold))
            if let subtitle {
                Text(subtitle).font(.caption).foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }

    private func bigNumber(_ s: String) -> some View {
        Text(s).font(.title2.weight(.semibold).monospacedDigit())
    }

    private func code(_ s: String) -> some View {
        Text(s)
            .font(.system(.caption, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            .textSelection(.enabled)
    }
}
