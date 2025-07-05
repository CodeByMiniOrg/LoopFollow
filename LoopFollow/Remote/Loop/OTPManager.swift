// LoopFollow
// OTPManager.swift
// Created by Daniel Mini Johansson.

import Foundation
import OneTimePassword

class OTPManager: ObservableObject {
    weak var delegate: OTPManagerDelegate?
    let otpURL: String
    @Published var otpCode: String = "" {
        didSet {
            self.delegate?.otpDidUpdate(manager: self, otpCode: otpCode)
        }
    }
    
    private var timer: Timer?
    
    init(otpURL: String) {
        self.otpURL = otpURL
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.refreshCurrentOTP()
        }
        refreshCurrentOTP()
    }
    
    private func getOTPCode() throws -> String? {
        let token = try Token(url: URL(string: otpURL)!)
        return token.currentPassword
    }
    
    private func refreshCurrentOTP() {
        do {
            self.otpCode = try getOTPCode() ?? ""
        } catch {
            print("OTP Error: \(error)")
        }
    }
}

protocol OTPManagerDelegate: AnyObject {
    func otpDidUpdate(manager: OTPManager, otpCode: String)
} 