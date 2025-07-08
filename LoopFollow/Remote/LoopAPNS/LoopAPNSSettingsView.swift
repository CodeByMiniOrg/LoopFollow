// LoopFollow
// LoopAPNSSettingsView.swift
// Created by codebymini

import SwiftUI

struct LoopAPNSSettingsView: View {
    @StateObject private var viewModel = RemoteSettingsViewModel()
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("LOOP APNS KEY ID")
                            .font(.headline)
                        TogglableSecureInput(
                            placeholder: "Enter your APNS Key ID",
                            text: $viewModel.loopAPNSKeyId,
                            style: .singleLine
                        )
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("LOOP DEVELOPER TEAM ID")
                            .font(.headline)
                        TogglableSecureInput(
                            placeholder: "Enter your Team ID (10 characters)",
                            text: $viewModel.loopDeveloperTeamId,
                            style: .singleLine
                        )
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("LOOP APNS KEY")
                            .font(.headline)
                        TogglableSecureInput(
                            placeholder: "Enter your APNS Key including -----BEGIN PRIVATE KEY----- and -----END PRIVATE KEY-----",
                            text: $viewModel.loopAPNSKey,
                            style: .multiLine
                        )
                        .frame(minHeight: 110)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("QR Code URL")
                            .font(.headline)
                        TextField("Enter QR code URL or scan from Loop app", text: $viewModel.loopAPNSQrCodeURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    Button(action: {
                        viewModel.isShowingLoopAPNSScanner = true
                    }) {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                            Text("Scan QR Code from Loop App")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Device Token")
                            .font(.headline)
                        HStack {
                            Text(viewModel.loopAPNSDeviceToken.isEmpty ? "Not configured" : viewModel.loopAPNSDeviceToken)
                                .foregroundColor(viewModel.loopAPNSDeviceToken.isEmpty ? .red : .primary)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Button(action: {
                                Task {
                                    await viewModel.refreshDeviceToken()
                                }
                            }) {
                                if viewModel.isRefreshingDeviceToken {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.blue)
                                }
                            }
                            .disabled(viewModel.isRefreshingDeviceToken)
                        }

                        // Device token status indicator
                        if !viewModel.loopAPNSDeviceToken.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Device token configured")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .padding(.top, 4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Bundle Identifier")
                            .font(.headline)
                        Text(viewModel.loopAPNSBundleIdentifier.isEmpty ? "Not configured" : viewModel.loopAPNSBundleIdentifier)
                            .foregroundColor(viewModel.loopAPNSBundleIdentifier.isEmpty ? .red : .primary)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Environment")
                            .font(.headline)
                        Toggle("Production Environment", isOn: $viewModel.productionEnvironment)
                            .toggleStyle(SwitchToggleStyle())
                        Text("Production is used for browser builders and should be switched off for Xcode builders")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // Environment status indicator
                        HStack {
                            Image(systemName: viewModel.productionEnvironment ? "checkmark.circle.fill" : "gearshape.fill")
                                .foregroundColor(viewModel.productionEnvironment ? .green : .blue)
                            Text(viewModel.productionEnvironment ? "Production Environment" : "Development Environment")
                                .font(.caption)
                                .foregroundColor(viewModel.productionEnvironment ? .green : .blue)
                        }
                        .padding(.top, 4)
                    }
                } header: {
                    Text("Loop APNS Configuration")
                }

                if let errorMessage = viewModel.loopAPNSErrorMessage, !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationBarTitle("Loop APNS Settings", displayMode: .inline)
            .sheet(isPresented: $viewModel.isShowingLoopAPNSScanner) {
                SimpleQRCodeScannerView { result in
                    viewModel.handleLoopAPNSQRCodeScanResult(result)
                }
            }
        }
    }
}

// MARK: - RemoteSettingsViewModel Extension for Loop APNS

extension RemoteSettingsViewModel {
    func saveLoopAPNSSetup() {
        DispatchQueue.main.async {
            self.isLoading = true
            self.loopAPNSErrorMessage = nil

            // Validate the setup
            guard !Storage.shared.url.value.isEmpty else {
                self.loopAPNSErrorMessage = "Please configure your Nightscout URL in the main settings"
                self.isLoading = false
                return
            }

            guard !self.loopAPNSKeyId.isEmpty else {
                self.loopAPNSErrorMessage = "Please configure your APNS Key ID"
                self.isLoading = false
                return
            }

            guard !self.loopAPNSKey.isEmpty else {
                self.loopAPNSErrorMessage = "Please configure your APNS Key"
                self.isLoading = false
                return
            }

            guard !self.loopAPNSQrCodeURL.isEmpty else {
                self.loopAPNSErrorMessage = "Please scan the QR code from your Loop app"
                self.isLoading = false
                return
            }

            // Mark setup as complete (values are already saved via bindings)
            self.loopAPNSSetup = true

            self.isLoading = false
        }
    }
}
