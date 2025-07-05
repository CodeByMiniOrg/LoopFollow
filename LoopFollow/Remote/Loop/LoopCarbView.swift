// LoopFollow
// LoopCarbView.swift
// Created by Daniel Mini Johansson.

import SwiftUI
import HealthKit

struct LoopCarbView: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject var nsAdmin = Storage.shared.nsWriteAuth
    
    @State private var carbInput: String = ""
    @State private var foodType: String = ""
    @State private var absorption: String = "3"
    @State private var submissionInProgress = false
    @State private var isPresentingConfirm = false
    @State private var pickerConsumedDate = Date()
    @State private var showDatePickerSheet = false
    @State private var errorText: String?
    @State private var statusMessage: String?
    @State private var showAlert: Bool = false
    @State private var alertType: AlertType? = nil
    
    @FocusState private var carbInputViewIsFocused: Bool
    @FocusState private var absorptionInputFieldIsFocused: Bool
    
    private let minAbsorptionTimeInHours = 0.5
    private let maxAbsorptionTimeInHours = 8.0
    private let maxPastCarbEntryHours = 12
    private let maxFutureCarbEntryHours = 1
    private let unitFrameWidth: CGFloat = 20.0
    private let maxCarbAmount = 100.0 // Default max carb amount
    
    private let controller = LoopNightscoutRemoteController()
    
    enum AlertType {
        case confirmCommand
        case status
        case validation
        case success
        case error
    }
    
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
                    
                    Text("You need to add a looper first to send remote carbs. The looper setup includes scanning a QR code from the Loop app.")
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
                carbInputView
            }
        }
        .navigationTitle("Remote Carbs")
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
    
    private var carbInputView: some View {
        VStack(spacing: 20) {
            Text("Enter Carb Amount")
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack {
                TextField("0", text: $carbInput)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($carbInputViewIsFocused)
                
                Text("g")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Food Type (Optional)")
                    .font(.headline)
                
                TextField("e.g., Breakfast, Lunch, Snack", text: $foodType)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Absorption Time")
                    .font(.headline)
                
                Picker("Absorption Time", selection: $absorption) {
                    Text("Fast (15 min)").tag("0.25")
                    Text("Medium (3 hours)").tag("3")
                    Text("Slow (6 hours)").tag("6")
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Time Consumed")
                    .font(.headline)
                
                Button(action: {
                    showDatePickerSheet = true
                }) {
                    HStack {
                        Text(pickerConsumedDate, style: .time)
                        Spacer()
                        Image(systemName: "clock")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
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
                submitCarbs()
            }) {
                if submissionInProgress {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Send Carbs")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(submissionInProgress ? Color.gray : Color.blue)
            .cornerRadius(10)
            .disabled(submissionInProgress || carbInput.isEmpty)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showDatePickerSheet) {
            NavigationView {
                VStack {
                    DatePicker("Time Consumed", selection: $pickerConsumedDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(WheelDatePickerStyle())
                        .padding()
                    
                    Button("Done") {
                        showDatePickerSheet = false
                    }
                    .padding()
                }
                .navigationTitle("Select Time")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
    
    private func submitCarbs() {
        guard let carbAmount = Double(carbInput), carbAmount > 0 else {
            errorText = "Please enter a valid carb amount"
            return
        }
        
        guard let absorptionTime = Double(absorption) else {
            errorText = "Please select a valid absorption time"
            return
        }
        
        submissionInProgress = true
        errorText = nil
        statusMessage = nil
        
        Task {
            do {
                try await controller.sendCarbs(
                    amountInGrams: carbAmount,
                    absorptionTime: absorptionTime * 3600, // Convert to seconds
                    consumedDate: pickerConsumedDate
                )
                await MainActor.run {
                    statusMessage = "Carbs sent successfully!"
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

struct CarbInputViewFormValues {
    let amountInGrams: Double
    let absorptionInHours: Double
    let consumedDate: Date
    
    var absorptionTime: TimeInterval {
        return absorptionInHours * 60 * 60
    }
}

enum CarbInputViewError: LocalizedError {
    case invalidCarbAmount
    case exceedsMaxAllowed(maxAllowed: Int)
    case invalidAbsorptionTime(minAbsorptionTimeInHours: Double, maxAbsorptionTimeInHours: Double)
    case exceedsMaxPastHours(maxPastHours: Int)
    case exceedsMaxFutureHours(maxFutureHours: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidCarbAmount:
            return "Enter a valid carb amount in grams."
        case let .exceedsMaxAllowed(maxAllowed):
            return "Enter a carb amount up to \(maxAllowed) g."
        case let .invalidAbsorptionTime(minAbsorptionTimeInHours, maxAbsorptionTimeInHours):
            return "Enter an absorption time between \(minAbsorptionTimeInHours) and \(maxAbsorptionTimeInHours) hours"
        case let .exceedsMaxPastHours(maxPastHours):
            return "Time must be within the prior \(maxPastHours) \(pluralizeHour(count: maxPastHours))"
        case let .exceedsMaxFutureHours(maxFutureHours):
            return "Time must be within the next \(maxFutureHours) \(pluralizeHour(count: maxFutureHours))"
        }
    }
    
    func pluralizeHour(count: Int) -> String {
        return count > 1 ? "hours" : "hour"
    }
}

extension Date {
    func dateUsingCurrentSeconds() -> Date {
        let calendar = Calendar.current
        
        // Extracting components from the original date
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self)
        
        // Getting the current seconds and milliseconds
        let now = Date()
        let nowSeconds = calendar.component(.second, from: now)
        let nowMillisecond = calendar.component(.nanosecond, from: now) / 1_000_000
        
        // Setting the seconds and millisecond components
        components.second = nowSeconds
        components.nanosecond = nowMillisecond * 1_000_000
        
        // Creating a new date with these components
        return calendar.date(from: components) ?? self
    }
} 