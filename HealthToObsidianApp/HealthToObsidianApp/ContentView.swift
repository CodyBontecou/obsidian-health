import SwiftUI

struct ContentView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var vaultManager = VaultManager()

    @State private var selectedDate = Date()
    @State private var showFolderPicker = false
    @State private var isExporting = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                // Health Connection Section
                Section {
                    HStack {
                        Label("Apple Health", systemImage: "heart.fill")
                            .foregroundStyle(.red)
                        Spacer()
                        Text(healthKitManager.authorizationStatus)
                            .foregroundStyle(.secondary)
                    }

                    if !healthKitManager.isAuthorized {
                        Button("Connect to Health") {
                            Task {
                                do {
                                    try await healthKitManager.requestAuthorization()
                                } catch {
                                    errorMessage = error.localizedDescription
                                    showError = true
                                }
                            }
                        }
                    }
                } header: {
                    Text("Health Connection")
                }

                // Vault Selection Section
                Section {
                    HStack {
                        Label("Vault", systemImage: "folder.fill")
                            .foregroundStyle(.purple)
                        Spacer()
                        Text(vaultManager.vaultName)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Button("Select Vault Folder") {
                        showFolderPicker = true
                    }

                    if vaultManager.vaultURL != nil {
                        Button("Clear Selection", role: .destructive) {
                            vaultManager.clearVaultFolder()
                        }
                    }
                } header: {
                    Text("Obsidian Vault")
                }

                // Export Settings Section
                Section {
                    HStack {
                        Label("Subfolder", systemImage: "folder")
                        Spacer()
                        TextField("Health", text: $vaultManager.healthSubfolder)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: vaultManager.healthSubfolder) { _, _ in
                                vaultManager.saveSubfolderSetting()
                            }
                    }

                    DatePicker(
                        selection: $selectedDate,
                        in: ...Date(),
                        displayedComponents: .date
                    ) {
                        Label("Date", systemImage: "calendar")
                    }
                } header: {
                    Text("Export Settings")
                } footer: {
                    Text("Files will be saved to: \(exportPath)")
                }

                // Export Section
                Section {
                    Button {
                        exportData()
                    } label: {
                        HStack {
                            Spacer()
                            if isExporting {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Exporting...")
                            } else {
                                Label("Export Health Data", systemImage: "square.and.arrow.up")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canExport || isExporting)

                    if let status = vaultManager.lastExportStatus {
                        HStack {
                            Image(systemName: status.starts(with: "Exported") ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundStyle(status.starts(with: "Exported") ? .green : .red)
                            Text(status)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Health to Obsidian")
            .sheet(isPresented: $showFolderPicker) {
                FolderPicker { url in
                    vaultManager.setVaultFolder(url)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .task {
                // Request health authorization on launch if not already authorized
                if healthKitManager.isHealthDataAvailable && !healthKitManager.isAuthorized {
                    do {
                        try await healthKitManager.requestAuthorization()
                    } catch {
                        // Silent fail on launch - user can tap Connect button
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var canExport: Bool {
        healthKitManager.isAuthorized && vaultManager.vaultURL != nil
    }

    private var exportPath: String {
        let subfolder = vaultManager.healthSubfolder.isEmpty ? "" : vaultManager.healthSubfolder + "/"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return "\(vaultManager.vaultName)/\(subfolder)\(dateFormatter.string(from: selectedDate)).md"
    }

    // MARK: - Export

    private func exportData() {
        isExporting = true

        Task {
            defer { isExporting = false }

            do {
                let healthData = try await healthKitManager.fetchHealthData(for: selectedDate)
                try await vaultManager.exportHealthData(healthData)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    ContentView()
}
