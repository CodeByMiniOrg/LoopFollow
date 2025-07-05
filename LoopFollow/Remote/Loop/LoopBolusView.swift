// LoopFollow
// LoopBolusView.swift
// Created by Daniel Mini Johansson.

import SwiftUI
import HealthKit

struct LoopBolusView: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject var nsAdmin = Storage.shared.nsWriteAuth
    
    @State private var bolusAmount: String = ""
    @State private var submissionInProgress = false
    @State private var isPresentingConfirm = false
    @State private var errorText: String?
    @State private var statusMessage: String?
    @State private var showAlert: Bool = false
    @State private var alertType: AlertType? = nil
    
    @FocusState private var bolusInputViewIsFocused: Bool
    
    private let unitFrameWidth: CGFloat = 20.0
    private let controller = LoopNightscoutRemoteController()
    
    var body: some View {
        VStack {
            if !controller.hasLooperConfigured() {
                VStack(spacing: 20) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("No Looper Configured")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("You need to add a looper first to send remote boluses. The looper setup includes scanning a QR code from the Loop app.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    NavigationLink(destination: LooperSetupView()) {
                        Text("Add Looper")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                .padding()
            } else {
                bolusInputView
            }
        }
        .navigationTitle("Remote Bolus")
        .alert(alertType?.title ?? "Error", isPresented: $showAlert) {
            Button("OK") {
                if alertType == .success {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        } message: {
            Text(alertType?.message ?? "")
        }
    }
    
    private var bolusInputView: some View {
        VStack(spacing: 20) {
            Text("Enter Bolus Amount")
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack {
                TextField("0.0", text: $bolusAmount)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($bolusInputViewIsFocused)
                
                Text("U")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            if let errorText = errorText {
                Text(errorText)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            if let statusMessage = statusMessage {
                Text(statusMessage)
                    .foregroundColor(.green)
                    .font(.caption)
            }
            
            Button(action: {
                submitBolus()
            }) {
                if submissionInProgress {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Send Bolus")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(submissionInProgress ? Color.gray : Color.blue)
            .cornerRadius(10)
            .disabled(submissionInProgress || bolusAmount.isEmpty)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    private func submitBolus() {
        guard let amount = Double(bolusAmount), amount > 0 else {
            errorText = "Please enter a valid bolus amount"
            return
        }
        
        submissionInProgress = true
        errorText = nil
        statusMessage = nil
        
        Task {
            do {
                try await controller.sendBolus(amountInUnits: amount)
                await MainActor.run {
                    statusMessage = "Bolus sent successfully!"
                    alertType = .success
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    errorText = error.localizedDescription
                    alertType = .error
                    showAlert = true
                }
            }
            
            await MainActor.run {
                submissionInProgress = false
            }
        }
    }
}

enum AlertType {
    case success
    case error
    
    var title: String {
        switch self {
        case .success:
            return "Success"
        case .error:
            return "Error"
        }
    }
    
    var message: String {
        switch self {
        case .success:
            return "Bolus sent successfully!"
        case .error:
            return "Failed to send bolus. Please try again."
        }
    }
} 