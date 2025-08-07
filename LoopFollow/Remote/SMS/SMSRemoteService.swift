// LoopFollow
// SMSRemoteService.swift

import Foundation
import MessageUI

class SMSRemoteService: NSObject, ObservableObject {
    private let storage = Storage.shared

    enum SMSRemoteError: Error, LocalizedError {
        case invalidConfiguration
        case invalidPhoneNumber
        case invalidOTP
        case networkError
        case invalidResponse
        case unauthorized
        case rateLimited
        case bolusTooSoon

        var errorDescription: String? {
            switch self {
            case .invalidConfiguration:
                return "SMS configuration not valid"
            case .invalidPhoneNumber:
                return "Invalid phone number"
            case .invalidOTP:
                return "Invalid OTP code"
            case .networkError:
                return "Network error occurred"
            case .invalidResponse:
                return "Invalid response from AndroidAPS"
            case .unauthorized:
                return "Unauthorized - check your phone number and OTP"
            case .rateLimited:
                return "Too many requests - please wait a few minutes"
            case .bolusTooSoon:
                return "Bolus too soon after previous bolus"
            }
        }
    }

    static let shared = SMSRemoteService()

    @Published var isEnabled = false
    @Published var lastMessage: String = ""
    @Published var messageHistory: [SMSMessage] = []

    private var messageComposer: MFMessageComposeViewController?
    private var pendingAuthRequest: AuthRequest?

    override init() {
        super.init()
        isEnabled = storage.smsEnabled.value
    }

    // MARK: - Configuration

    func validateSetup() -> Bool {
        let hasPhoneNumber = !storage.smsPhoneNumber.value.isEmpty
        let hasQrCode = !storage.smsQrCodeURL.value.isEmpty

        return hasPhoneNumber && hasQrCode
    }

    func getPhoneNumber() -> String {
        return storage.smsPhoneNumber.value
    }

    // MARK: - SMS Sending

    func sendSMS(to number: String, message: String) async throws -> Bool {
        // Note: iOS doesn't allow direct SMS sending from apps
        // In a real implementation, this would use a web service or SMS gateway
        // For now, we'll simulate the SMS sending

        LogManager.shared.log(category: .sms, message: "SMS sent to \(number): \(message)")

        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Add to message history
        let smsMessage = SMSMessage(phoneNumber: number, text: message, isReceived: false)
        await MainActor.run {
            messageHistory.append(smsMessage)
        }

        return true
    }

    // MARK: - Native Messages App Integration

    func openMessagesApp(with number: String, message: String) -> Bool {
        // Encode the message for URL
        let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Create the SMS URL
        let smsURL = URL(string: "sms:\(number)&body=\(encodedMessage)")!

        // Open the Messages app
        if UIApplication.shared.canOpenURL(smsURL) {
            UIApplication.shared.open(smsURL)
            return true
        }

        return false
    }

    func composeSMSInApp(to number: String, message: String) -> MFMessageComposeViewController? {
        guard MFMessageComposeViewController.canSendText() else {
            return nil
        }

        let messageVC = MFMessageComposeViewController()
        messageVC.recipients = [number]
        messageVC.body = message

        return messageVC
    }

    // MARK: - Command Methods

    func sendBGStatusCommand() async throws -> Bool {
        guard validateSetup() else {
            throw SMSRemoteError.invalidConfiguration
        }

        let phoneNumber = getPhoneNumber()
        let command = "BG"

        return try await sendSMS(to: phoneNumber, message: command)
    }

    func sendBolusCommand(amount: Double, isMeal: Bool, otp: String) async throws -> Bool {
        guard validateSetup() else {
            throw SMSRemoteError.invalidConfiguration
        }

        // Check bolus delay
        if let lastBolus = storage.smsLastBolusTime.value {
            let timeSinceLastBolus = Date().timeIntervalSince(lastBolus)
            let minDelay = TimeInterval(storage.smsBolusDelayMinutes.value * 60)

            if timeSinceLastBolus < minDelay {
                throw SMSRemoteError.bolusTooSoon
            }
        }

        let phoneNumber = getPhoneNumber()
        let command = isMeal ? "BOLUS \(String(format: "%.2f", amount)) MEAL" : "BOLUS \(String(format: "%.2f", amount))"

        // First send the command
        let success = try await sendSMS(to: phoneNumber, message: command)

        if success {
            // Update last bolus time
            storage.smsLastBolusTime.value = Date()

            // In a real implementation, you would wait for the response SMS
            // and then send the OTP code
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            // Send OTP code
            try await sendSMS(to: phoneNumber, message: otp)
        }

        return success
    }

    func sendCarbsCommand(amount: Double, time: String?, otp: String) async throws -> Bool {
        guard validateSetup() else {
            throw SMSRemoteError.invalidConfiguration
        }

        let phoneNumber = getPhoneNumber()
        var command = "CARBS \(Int(amount))"
        if let time = time {
            command += " \(time)"
        }

        // First send the command
        let success = try await sendSMS(to: phoneNumber, message: command)

        if success {
            // Wait for response and send OTP
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            try await sendSMS(to: phoneNumber, message: otp)
        }

        return success
    }

    func sendTargetCommand(type: String, otp: String) async throws -> Bool {
        guard validateSetup() else {
            throw SMSRemoteError.invalidConfiguration
        }

        let phoneNumber = getPhoneNumber()
        let command = "TARGET \(type.uppercased())"

        // First send the command
        let success = try await sendSMS(to: phoneNumber, message: command)

        if success {
            // Wait for response and send OTP
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            try await sendSMS(to: phoneNumber, message: otp)
        }

        return success
    }

    func sendLoopCommand(action: String, otp: String) async throws -> Bool {
        guard validateSetup() else {
            throw SMSRemoteError.invalidConfiguration
        }

        let phoneNumber = getPhoneNumber()
        let command = "LOOP \(action.uppercased())"

        // First send the command
        let success = try await sendSMS(to: phoneNumber, message: command)

        if success {
            // Wait for response and send OTP
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            try await sendSMS(to: phoneNumber, message: otp)
        }

        return success
    }

    func sendPumpCommand(action: String, otp: String) async throws -> Bool {
        guard validateSetup() else {
            throw SMSRemoteError.invalidConfiguration
        }

        let phoneNumber = getPhoneNumber()
        let command = "PUMP \(action.uppercased())"

        // First send the command
        let success = try await sendSMS(to: phoneNumber, message: command)

        if success {
            // Wait for response and send OTP
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            try await sendSMS(to: phoneNumber, message: otp)
        }

        return success
    }

    func sendProfileCommand(action: String, profile: String?, otp: String) async throws -> Bool {
        guard validateSetup() else {
            throw SMSRemoteError.invalidConfiguration
        }

        let phoneNumber = getPhoneNumber()
        var command = "PROFILE \(action.uppercased())"
        if let profile = profile {
            command += " \(profile)"
        }

        // First send the command
        let success = try await sendSMS(to: phoneNumber, message: command)

        if success {
            // Wait for response and send OTP
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            try await sendSMS(to: phoneNumber, message: otp)
        }

        return success
    }

    func sendStatusCommand() async throws -> Bool {
        guard validateSetup() else {
            throw SMSRemoteError.invalidConfiguration
        }

        let phoneNumber = getPhoneNumber()
        let command = "STATUS"

        return try await sendSMS(to: phoneNumber, message: command)
    }

    // MARK: - SMS Receiving (Simulation)

    func processIncomingSMS(from number: String, text: String) {
        let message = SMSMessage(phoneNumber: number, text: text, isReceived: true)

        DispatchQueue.main.async {
            self.messageHistory.append(message)
            self.lastMessage = text
        }

        LogManager.shared.log(category: .sms, message: "SMS received from \(number): \(text)")
    }

    // MARK: - Helper Methods

    private func validateOTP(_ otp: String) -> Bool {
        return otp.count == 6 && otp.allSatisfy { $0.isNumber }
    }
}

// MARK: - Supporting Types

struct SMSMessage: Identifiable {
    let id = UUID()
    let phoneNumber: String
    let text: String
    let timestamp: Date
    let isReceived: Bool

    init(phoneNumber: String, text: String, isReceived: Bool) {
        self.phoneNumber = phoneNumber
        self.text = text
        timestamp = Date()
        self.isReceived = isReceived
    }
}

struct AuthRequest {
    let phoneNumber: String
    let command: String
    let action: () -> Void
}
