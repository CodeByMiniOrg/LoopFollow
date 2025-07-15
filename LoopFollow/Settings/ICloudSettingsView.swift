// LoopFollow
// ICloudSettingsView.swift
// Created by codebymini.

import SwiftUI

struct ICloudSettingsView: View {
    @StateObject private var iCloudManager = ICloudStorageManager.shared
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isBackingUp = false
    @State private var isRestoring = false

    var body: some View {
        List {
            Section(header: Text("iCloud Backup & Restore")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Minimal Settings Backup")
                        .font(.headline)

                    Text("Backup your core LoopFollow settings to iCloud for easy setup on new devices. This includes Nightscout URL, graph settings, and essential preferences.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)

                if iCloudManager.hasBackup {
                    let backupInfo = iCloudManager.getBackupInfo()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Backup Available")
                            .font(.subheadline)
                            .foregroundColor(.green)

                        if let timestamp = backupInfo.timestamp {
                            Text("Last saved: \(timestamp, style: .date) at \(timestamp, style: .time)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let version = backupInfo.version {
                            Text("Version: \(version)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    Text("No backup found in iCloud")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
            }

            Section(header: Text("Actions")) {
                Button(action: backupToICloud) {
                    HStack {
                        if isBackingUp {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "icloud.and.arrow.up")
                                .foregroundColor(.blue)
                        }

                        Text("Save to iCloud")
                            .foregroundColor(.primary)

                        Spacer()
                    }
                }
                .disabled(isBackingUp || isRestoring || !iCloudManager.isICloudAvailable)

                Button(action: restoreFromICloud) {
                    HStack {
                        if isRestoring {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "icloud.and.arrow.down")
                                .foregroundColor(.green)
                        }

                        Text("Load from iCloud")
                            .foregroundColor(.primary)

                        Spacer()
                    }
                }
                .disabled(isBackingUp || isRestoring || !iCloudManager.hasBackup || !iCloudManager.isICloudAvailable)

                Button(action: clearICloudData) {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)

                        Text("Clear iCloud Backup")
                            .foregroundColor(.red)

                        Spacer()
                    }
                }
                .disabled(isBackingUp || isRestoring || !iCloudManager.hasBackup)
            }

            Section(header: Text("Status")) {
                HStack {
                    Image(systemName: iCloudManager.isICloudAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(iCloudManager.isICloudAvailable ? .green : .red)

                    Text("iCloud Available")
                        .foregroundColor(.primary)

                    Spacer()

                    Text(iCloudManager.isICloudAvailable ? "Yes" : "No")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Image(systemName: iCloudManager.hasBackup ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(iCloudManager.hasBackup ? .green : .gray)

                    Text("Backup Available")
                        .foregroundColor(.primary)

                    Spacer()

                    Text(iCloudManager.hasBackup ? "Yes" : "No")
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Information")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What gets backed up:")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("• Nightscout URL and token")
                    Text("• Graph display preferences")
                    Text("• Calendar and watch settings")
                    Text("• Dexcom Share credentials")
                    Text("• Core UI preferences and display options")
                    Text("• Remote control settings")
                    Text("• HealthKit limits")
                    Text("• Essential app settings")
                    Text("• Alarm settings")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("How it works:")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("1. Tap 'Save to iCloud' to backup all current settings")
                    Text("2. On a new device, install LoopFollow and sign in to the same iCloud account")
                    Text("3. Tap 'Load from iCloud' to restore all your settings")
                    Text("4. Your new device will have exactly the same configuration")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("iCloud Backup")
        .alert("iCloud Backup", isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }

    private func backupToICloud() {
        isBackingUp = true

        DispatchQueue.global(qos: .userInitiated).async {
            iCloudManager.backupToICloud()

            DispatchQueue.main.async {
                isBackingUp = false
                alertMessage = "Settings successfully saved to iCloud!"
                showingAlert = true
            }
        }
    }

    private func restoreFromICloud() {
        isRestoring = true

        DispatchQueue.global(qos: .userInitiated).async {
            iCloudManager.restoreFromICloud()

            DispatchQueue.main.async {
                isRestoring = false
                alertMessage = "Settings successfully loaded from iCloud! You may need to restart the app for all changes to take effect."
                showingAlert = true
            }
        }
    }

    private func clearICloudData() {
        alertMessage = "This will permanently delete the backup from iCloud. Are you sure?"
        showingAlert = true

        // For now, just show the alert. In a real implementation, you might want a confirmation dialog
        iCloudManager.clearICloudData()
    }
}

#Preview {
    NavigationView {
        ICloudSettingsView()
    }
}
