import SwiftUI

// MARK: - Sync Settings View (iOS)

struct SyncSettingsView: View {
    @EnvironmentObject var syncService: SyncService
    @AppStorage("syncEnabled") private var syncEnabled = false
    @AppStorage("autoSyncAfterExport") private var autoSyncAfterExport = true

    var body: some View {
        List {
            // MARK: Sync Toggle
            Section {
                Toggle("Sync to Mac", isOn: $syncEnabled)
                    .onChange(of: syncEnabled) { _, newValue in
                        if newValue {
                            syncService.startAdvertising()
                        } else {
                            syncService.stopAdvertising()
                            syncService.disconnect()
                        }
                    }
            } header: {
                Text("Mac Sync")
            } footer: {
                Text("When enabled, your Mac can discover this iPhone and request health data over your local network.")
            }

            // MARK: Connection Status
            if syncEnabled {
                Section("Connection") {
                    HStack {
                        connectionStatusIcon
                        VStack(alignment: .leading, spacing: 2) {
                            Text(connectionTitle)
                            Text(connectionSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if syncService.connectionState == .connected {
                        Toggle("Auto-sync after export", isOn: $autoSyncAfterExport)
                    }
                }
            }

            // MARK: Manual Sync
            if syncService.connectionState == .connected {
                Section {
                    Button {
                        sendAllRecentData()
                    } label: {
                        Label("Sync Last 7 Days Now", systemImage: "arrow.triangle.2.circlepath")
                    }
                } footer: {
                    Text("Sends the last 7 days of health data to your connected Mac.")
                }
            }

            // MARK: Error
            if let error = syncService.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Mac Sync")
        .onAppear {
            if syncEnabled {
                syncService.startAdvertising()
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private var connectionStatusIcon: some View {
        switch syncService.connectionState {
        case .connected:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .connecting:
            ProgressView()
                .controlSize(.small)
        case .disconnected:
            Image(systemName: "circle.dotted")
                .foregroundStyle(.secondary)
        }
    }

    private var connectionTitle: String {
        switch syncService.connectionState {
        case .connected:
            return "Connected to \(syncService.connectedPeerName ?? "Mac")"
        case .connecting:
            return "Connecting…"
        case .disconnected:
            return "Waiting for Mac"
        }
    }

    private var connectionSubtitle: String {
        switch syncService.connectionState {
        case .connected: return "Ready to sync"
        case .connecting: return "Establishing connection…"
        case .disconnected: return "Open Health.md on your Mac to connect"
        }
    }

    private func sendAllRecentData() {
        // This triggers the iOS-side handler to fetch from HealthKit and send
        // The actual data fetching is handled by the sync message handler in HealthMdApp
        let endDate = Calendar.current.startOfDay(for: Date())
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate

        var dates: [Date] = []
        var current = startDate
        while current <= endDate {
            dates.append(current)
            current = Calendar.current.date(byAdding: .day, value: 1, to: current) ?? endDate.addingTimeInterval(1)
        }

        // Send a self-request to trigger the fetch-and-send pipeline
        syncService.onMessageReceived?(.requestData(dates: dates))
    }
}
