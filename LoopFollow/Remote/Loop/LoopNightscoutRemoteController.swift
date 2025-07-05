// LoopFollow
// LoopNightscoutRemoteController.swift
// Created by Daniel Mini Johansson.

import Foundation
import HealthKit

extension Notification.Name {
    static let didUpdateTreatments = Notification.Name("didUpdateTreatments")
}

class LoopNightscoutRemoteController {
    
    private var currentLooper: Looper? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "currentLooper") else { return nil }
            return try? JSONDecoder().decode(Looper.self, from: data)
        }
    }
    
    private var otpManager: OTPManager? {
        guard let looper = currentLooper else { return nil }
        return OTPManager(otpURL: looper.nightscoutCredentials.otpURL)
    }
    
    func sendBolus(amountInUnits: Double) async throws {
        guard let looper = currentLooper else {
            throw LoopRemoteError.noLooperConfigured
        }
        
        let otpCode = otpManager?.otpCode ?? ""
        
        let bolusBody: [String: Any] = [
            "enteredBy": "LoopFollow",
            "eventType": "Bolus",
            "insulin": amountInUnits,
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "otp": otpCode
        ]

        do {
            let response: [TreatmentResponse] = try await NightscoutUtils.executePostRequest(eventType: .treatments, body: bolusBody)
            NotificationCenter.default.post(name: .didUpdateTreatments, object: nil)
            
            // Log the successful bolus
            LogManager.shared.log("Bolus sent: \(amountInUnits) units", category: .remote)
            
        } catch {
            LogManager.shared.log("Failed to send bolus: \(error.localizedDescription)", category: .remote)
            throw LoopRemoteError.failedToSendBolus(error: error)
        }
    }
    
    func sendCarbs(amountInGrams: Double, absorptionTime: TimeInterval, consumedDate: Date) async throws {
        guard let looper = currentLooper else {
            throw LoopRemoteError.noLooperConfigured
        }
        
        let otpCode = otpManager?.otpCode ?? ""
        
        let carbBody: [String: Any] = [
            "enteredBy": "LoopFollow",
            "eventType": "Carb Correction",
            "carbs": amountInGrams,
            "absorptionTime": absorptionTime,
            "created_at": ISO8601DateFormatter().string(from: consumedDate),
            "otp": otpCode
        ]

        do {
            let response: [TreatmentResponse] = try await NightscoutUtils.executePostRequest(eventType: .treatments, body: carbBody)
            NotificationCenter.default.post(name: .didUpdateTreatments, object: nil)
            
            // Log the successful carb entry
            LogManager.shared.log("Carbs sent: \(amountInGrams)g", category: .remote)
            
        } catch {
            LogManager.shared.log("Failed to send carbs: \(error.localizedDescription)", category: .remote)
            throw LoopRemoteError.failedToSendCarbs(error: error)
        }
    }
    
    func hasLooperConfigured() -> Bool {
        return currentLooper != nil
    }
    
    func getCurrentLooper() -> Looper? {
        return currentLooper
    }
}

enum LoopRemoteError: LocalizedError {
    case noLooperConfigured
    case failedToSendBolus(error: Error)
    case failedToSendCarbs(error: Error)
    
    var errorDescription: String? {
        switch self {
        case .noLooperConfigured:
            return "No looper configured. Please add a looper first."
        case .failedToSendBolus(let error):
            return "Failed to send bolus: \(error.localizedDescription)"
        case .failedToSendCarbs(let error):
            return "Failed to send carbs: \(error.localizedDescription)"
        }
    }
}

// Response types for Nightscout API
struct TreatmentResponse: Codable {
    let _id: String?
    let eventType: String?
    let created_at: String?
    let enteredBy: String?
    let insulin: Double?
    let carbs: Double?
    let absorptionTime: Double?
}

struct TreatmentCancelResponse: Codable {
    let _id: String?
    let eventType: String?
    let created_at: String?
    let enteredBy: String?
} 