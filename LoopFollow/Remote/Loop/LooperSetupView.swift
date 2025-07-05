// LoopFollow
// LooperSetupView.swift
// Created by Daniel Mini Johansson.

import SwiftUI
import CodeScanner

struct LooperSetupView: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject var nsAdmin = Storage.shared.nsWriteAuth
    
    @State private var nightscoutURLFieldText: String = ""
    @State private var nameFieldText: String = ""
    @State private var apiSecretFieldText: String = ""
    @State private var qrURLFieldText: String = ""
    @State private var errorText: String?
    @State private var isShowingScanner = false
    @State private var authenticating = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack {
                inputFormView
                if authenticating {
                    ProgressView("Checking credentials...")
                }
                Spacer()
                Button("Add Looper") {
                    self.save()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding()
                .disabled(disableFormSubmission())
                if let errorText {
                    Text("\(errorText)").foregroundColor(.red)
                }
            }
            .sheet(isPresented: $isShowingScanner) {
                CodeScannerView(codeTypes: [.qr], completion: handleScan)
            }
            .navigationTitle("Add Looper")
            .alert("Error", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var inputFormView: some View {
        Form {
            Section {
                VStack {
                    Text("Name")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TextField(
                        "Required",
                        text: $nameFieldText, onCommit: {
                            self.save()
                        })
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                }
                VStack {
                    Text("Nightscout URL")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TextField(
                        "Required",
                        text: $nightscoutURLFieldText, onCommit: {
                            self.save()
                        })
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                }
                VStack {
                    Text("API Secret")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TextField(
                        "Required",
                        text: $apiSecretFieldText
                    ) {
                        self.save()
                    }
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                }
                if qrURLFieldText.isEmpty {
                    Button {
                        isShowingScanner = true
                    } label: {
                        Text("Scan QR")
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                
                    TextField(
                        "QR Scan",
                        text: $qrURLFieldText, onCommit: {
                            self.save()
                        }
                    )
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                }
            }
        }
    }
    
    private func disableFormSubmission() -> Bool {
        return !nameFieldValid() ||
        !nightscoutURLFieldValid() ||
        !apiSecretFieldValid() ||
        !qrURLFieldValid() ||
        authenticating
    }
    
    private func nightscoutURLFieldValid() -> Bool {
        return !nightscoutURLFieldText.isEmpty
    }
    
    private func nameFieldValid() -> Bool {
        return !nameFieldText.isEmpty
    }
    
    private func apiSecretFieldValid() -> Bool {
        return !apiSecretFieldText.isEmpty
    }
    
    private func qrURLFieldValid() -> Bool {
        return !qrURLFieldText.isEmpty
    }
    
    private func handleScan(result: Result<ScanResult, ScanError>) {
        isShowingScanner = false
        switch result {
        case .success(let result):
            qrURLFieldText = result.string
        case .failure(let error):
            alertMessage = "Scanning failed: \(error.localizedDescription)"
            showAlert = true
            print("Scanning failed: \(error.localizedDescription)")
        }
    }
    
    private func save() {
        Task {
            do {
                errorText = ""
                authenticating = true
                try await save(
                    nightscoutURLText: nightscoutURLFieldText,
                    name: nameFieldText,
                    apiSecret: apiSecretFieldText,
                    otpURL: qrURLFieldText
                )
                presentationMode.wrappedValue.dismiss()
            } catch {
                errorText = "\(error.localizedDescription)"
            }
            
            authenticating = false
        }
    }
    
    func save(nightscoutURLText: String?, name: String?, apiSecret: String?, otpURL: String?) async throws {
        guard let name, !name.isEmpty else {
            throw LooperSetupError.genericError(message: "Must enter Looper Name")
        }
        
        guard let nightscoutURLString = nightscoutURLText?.trimmingCharacters(in: CharacterSet(charactersIn: "/")),
              let nightscoutURL = URL(string: nightscoutURLString) else {
            throw LooperSetupError.genericError(message: "Must enter valid Nightscout URL")
        }
        
        guard let apiSecret = apiSecret?.trimmingCharacters(in: .whitespacesAndNewlines), !apiSecret.isEmpty else {
            throw LooperSetupError.genericError(message: "Must enter API Secret")
        }
        
        guard let otpURL, !otpURL.isEmpty else {
            throw LooperSetupError.genericError(message: "Must enter OTP URL")
        }
        
        let looper = Looper(
            identifier: UUID(),
            name: name,
            nightscoutCredentials: NightscoutCredentials(url: nightscoutURL, secretKey: apiSecret, otpURL: otpURL),
            lastSelectedDate: Date()
        )
        
        // Store the looper in UserDefaults for now (can be enhanced with Core Data later)
        try await storeLooper(looper)
        
        // Test the connection
        try await testConnection(looper: looper)
    }
    
    private func storeLooper(_ looper: Looper) async throws {
        // For now, store in UserDefaults. This can be enhanced with Core Data later
        let encoder = JSONEncoder()
        let data = try encoder.encode(looper)
        UserDefaults.standard.set(data, forKey: "currentLooper")
    }
    
    private func testConnection(looper: Looper) async throws {
        // Test the Nightscout connection
        let testURL = looper.nightscoutCredentials.url.appendingPathComponent("api/v1/status.json")
        var request = URLRequest(url: testURL)
        request.setValue(looper.nightscoutCredentials.secretKey, forHTTPHeaderField: "api-secret")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LooperSetupError.genericError(message: "Failed to connect to Nightscout")
        }
    }
}

enum LooperSetupError: LocalizedError {
    case genericError(message: String)
    
    var errorDescription: String? {
        switch self {
        case .genericError(let message):
            return message
        }
    }
} 