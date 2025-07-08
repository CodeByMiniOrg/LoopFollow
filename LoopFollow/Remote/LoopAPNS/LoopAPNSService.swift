// LoopFollow
// LoopAPNSService.swift
// Created by codebymini

import CryptoKit
import Foundation
import HealthKit
import SwiftJWT

class LoopAPNSService {
    private let storage = Storage.shared

    struct DeviceTokenResponse: Codable {
        let deviceToken: String?
        let bundleIdentifier: String?
    }

    struct Profile: Codable {
        let loopSettings: LoopSettings?
    }

    struct LoopSettings: Codable {
        let deviceToken: String?
        let bundleIdentifier: String?
    }

    struct LoopAPNSJWTClaims: Claims {
        let iss: String
        let iat: Date
    }

    enum LoopAPNSError: Error, LocalizedError {
        case invalidURL
        case networkError
        case invalidResponse
        case noDeviceToken
        case noBundleIdentifier
        case unauthorized
        case deviceTokenNotConfigured
        case bundleIdentifierNotConfigured
        case rateLimited

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid Nightscout URL"
            case .networkError:
                return "Network error occurred"
            case .invalidResponse:
                return "Invalid response from server"
            case .noDeviceToken:
                return "No device token found in profile"
            case .noBundleIdentifier:
                return "No bundle identifier found in profile"
            case .unauthorized:
                return "Unauthorized - check your API secret"
            case .deviceTokenNotConfigured:
                return "Device token not configured"
            case .bundleIdentifierNotConfigured:
                return "Bundle identifier not configured"
            case .rateLimited:
                return "Too many requests - please wait a few minutes before trying again"
            }
        }
    }

    /// Fetches the device token from Nightscout profile endpoint
    /// - Returns: A tuple containing device token and bundle identifier
    func fetchDeviceToken() async throws -> (deviceToken: String, bundleIdentifier: String) {
        let nightscoutURL = storage.url.value
        let apiSecret = storage.loopApiSecret.value

        guard !nightscoutURL.isEmpty else {
            throw LoopAPNSError.invalidURL
        }

        guard !apiSecret.isEmpty else {
            throw LoopAPNSError.unauthorized
        }

        guard let url = URL(string: "\(nightscoutURL)/api/v1/profile") else {
            throw LoopAPNSError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiSecret.sha1, forHTTPHeaderField: "api-secret")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw LoopAPNSError.networkError
            }

            switch httpResponse.statusCode {
            case 200:
                let profiles = try JSONDecoder().decode([Profile].self, from: data)

                guard let firstProfile = profiles.first,
                      let loopSettings = firstProfile.loopSettings
                else {
                    LogManager.shared.log(category: .apns, message: "Invalid response structure from Nightscout profile endpoint")
                    throw LoopAPNSError.invalidResponse
                }

                guard let deviceToken = loopSettings.deviceToken, !deviceToken.isEmpty else {
                    LogManager.shared.log(category: .apns, message: "No device token found in Nightscout profile")
                    throw LoopAPNSError.noDeviceToken
                }

                guard let bundleIdentifier = loopSettings.bundleIdentifier, !bundleIdentifier.isEmpty else {
                    LogManager.shared.log(category: .apns, message: "No bundle identifier found in Nightscout profile")
                    throw LoopAPNSError.noBundleIdentifier
                }

                LogManager.shared.log(category: .apns, message: "Successfully retrieved device token from Nightscout")
                return (deviceToken: deviceToken, bundleIdentifier: bundleIdentifier)

            case 401:
                LogManager.shared.log(category: .apns, message: "Unauthorized access to Nightscout profile endpoint")
                throw LoopAPNSError.unauthorized

            default:
                LogManager.shared.log(category: .apns, message: "HTTP error \(httpResponse.statusCode) from Nightscout profile endpoint")
                throw LoopAPNSError.networkError
            }
        } catch {
            if error is LoopAPNSError {
                throw error
            } else {
                LogManager.shared.log(category: .apns, message: "Network request failed with error: \(error.localizedDescription)")
                throw LoopAPNSError.networkError
            }
        }
    }

    /// Validates the Loop APNS setup by checking all required fields
    /// - Returns: True if setup is valid, false otherwise
    func validateSetup() -> Bool {
        let hasKeyId = !storage.loopAPNSKeyId.value.isEmpty
        let hasAPNSKey = !storage.loopAPNSKey.value.isEmpty
        let hasQrCode = !storage.loopAPNSQrCodeURL.value.isEmpty
        let hasDeviceToken = !storage.loopAPNSDeviceToken.value.isEmpty
        let hasBundleIdentifier = !storage.loopAPNSBundleIdentifier.value.isEmpty

        // For initial setup, we don't require device token and bundle identifier
        // These will be fetched when the user clicks "Refresh Device Token"
        let hasBasicSetup = hasKeyId && hasAPNSKey && hasQrCode

        // For full validation (after device token is fetched), check everything
        let hasFullSetup = hasBasicSetup && hasDeviceToken && hasBundleIdentifier

        return hasFullSetup
    }

    /// Validates the basic Loop APNS setup (without device token)
    /// - Returns: True if basic setup is valid, false otherwise
    func validateBasicSetup() -> Bool {
        let hasKeyId = !storage.loopAPNSKeyId.value.isEmpty
        let hasAPNSKey = !storage.loopAPNSKey.value.isEmpty
        let hasQrCode = !storage.loopAPNSQrCodeURL.value.isEmpty

        let isValid = hasKeyId && hasAPNSKey && hasQrCode

        // Log validation results for debugging
        LogManager.shared.log(category: .apns, message: "Basic setup validation - Key ID: \(hasKeyId), APNS Key: \(hasAPNSKey), QR Code: \(hasQrCode), Valid: \(isValid)")
        LogManager.shared.log(category: .apns, message: "QR Code URL: \(storage.loopAPNSQrCodeURL.value)")

        // Additional APNS key validation
        if hasAPNSKey {
            validateAPNSKeyFormat()
        }
        return isValid
    }

    /// Sets a test device token for testing purposes
    /// - Parameter testToken: The test device token to use
    func setTestDeviceToken(_ testToken: String) {
        storage.loopAPNSDeviceToken.value = testToken
        LogManager.shared.log(category: .apns, message: "Test device token set: \(testToken)")
    }

    /// Validates the APNS key format and provides debugging information
    private func validateAPNSKeyFormat() {
        let apnsKey = storage.loopAPNSKey.value
        let keyId = storage.loopAPNSKeyId.value
        let teamId = storage.teamId.value ?? keyId

        // Validate key format
        let hasPrivateKeyHeader = apnsKey.contains("-----BEGIN PRIVATE KEY-----")
        let hasEndHeader = apnsKey.contains("-----END PRIVATE KEY-----")
        let keyLines = apnsKey.components(separatedBy: .newlines)
        let keyLineCount = keyLines.count

        LogManager.shared.log(category: .apns, message: "APNS Key validation:")
        LogManager.shared.log(category: .apns, message: "- Has PKCS8 header: \(hasPrivateKeyHeader)")
        LogManager.shared.log(category: .apns, message: "- Has end header: \(hasEndHeader)")
        LogManager.shared.log(category: .apns, message: "- Total lines: \(keyLineCount)")
        LogManager.shared.log(category: .apns, message: "- Key ID: \(keyId)")
        LogManager.shared.log(category: .apns, message: "- Team ID: \(teamId)")

        // Validate key ID and team ID format
        let keyIdPattern = "^[A-Z0-9]{10}$"
        let teamIdPattern = "^[A-Z0-9]{10}$"
        let isValidKeyId = keyId.range(of: keyIdPattern, options: .regularExpression) != nil
        let isValidTeamId = teamId.range(of: teamIdPattern, options: .regularExpression) != nil

        LogManager.shared.log(category: .apns, message: "- Key ID format valid: \(isValidKeyId)")
        LogManager.shared.log(category: .apns, message: "- Team ID format valid: \(isValidTeamId)")

        if !isValidKeyId || !isValidTeamId {
            LogManager.shared.log(category: .apns, message: "WARNING: Key ID or Team ID format is invalid")
        }
    }

    /// Refreshes the device token from Nightscout
    /// - Returns: True if successful, false otherwise
    func refreshDeviceToken() async -> Bool {
        do {
            let (deviceToken, bundleIdentifier) = try await fetchDeviceToken()

            DispatchQueue.main.async {
                self.storage.loopAPNSDeviceToken.value = deviceToken
                self.storage.loopAPNSBundleIdentifier.value = bundleIdentifier
            }

            return true
        } catch {
            LogManager.shared.log(category: .apns, message: "Failed to refresh device token: \(error.localizedDescription)")

            // Log additional debugging information
            let nightscoutURL = storage.url.value
            let apiSecret = storage.loopApiSecret.value

            LogManager.shared.log(category: .apns, message: "Nightscout URL: \(nightscoutURL.isEmpty ? "Not configured" : nightscoutURL)")
            LogManager.shared.log(category: .apns, message: "API Secret: \(apiSecret.isEmpty ? "Not configured" : "Configured")")

            return false
        }
    }

    // Helper to ensure we have a valid device token and bundle identifier
    private func getValidDeviceTokenAndBundle() async throws -> (deviceToken: String, bundleIdentifier: String) {
        var deviceToken = storage.loopAPNSDeviceToken.value
        var bundleIdentifier = storage.loopAPNSBundleIdentifier.value
        if deviceToken.isEmpty {
            LogManager.shared.log(category: .apns, message: "Device token is empty or test token, refreshing from Nightscout...")
            let refreshSuccess = await refreshDeviceToken()
            if !refreshSuccess {
                throw LoopAPNSError.noDeviceToken
            }
            deviceToken = storage.loopAPNSDeviceToken.value
            bundleIdentifier = storage.loopAPNSBundleIdentifier.value
        }

        return (deviceToken, bundleIdentifier)
    }

    /// Sends carbs via APNS push notification
    /// - Parameter payload: The carbs payload to send
    /// - Returns: True if successful, false otherwise
    func sendCarbsViaAPNS(payload: LoopAPNSPayload) async throws -> Bool {
        guard validateSetup() else {
            throw LoopAPNSError.invalidURL
        }
        let (deviceToken, bundleIdentifier) = try await getValidDeviceTokenAndBundle()
        let keyId = storage.loopAPNSKeyId.value
        let apnsKey = storage.loopAPNSKey.value

        // Create APNS notification payload (matching Loop's expected format)
        let now = Date()
        let expiration = Date(timeIntervalSinceNow: 5 * 60) // 5 minutes from now

        // Create the complete notification payload (matching Nightscout's exact format)
        // Based on Nightscout's loop.js implementation
        let carbsAmount = payload.carbsAmount ?? 0.0
        let absorptionTime = payload.absorptionTime ?? 3.0
        var finalPayload = [
            "carbs-entry": carbsAmount,
            "absorption-time": absorptionTime,
            "otp": String(payload.otp),
            "remote-address": "LoopFollow",
            "notes": "Sent via LoopFollow APNS",
            "entered-by": "LoopFollow",
            "sent-at": formatDateForAPNS(now),
            "expiration": formatDateForAPNS(expiration),
            "start-time": formatDateForAPNS(now),
            "alert": "Remote Carbs Entry: \(String(format: "%.1f", carbsAmount)) grams\nAbsorption Time: \(String(format: "%.1f", absorptionTime)) hours",
        ] as [String: Any]

        // Log the exact carbs amount for debugging precision issues
        LogManager.shared.log(category: .apns, message: "Carbs amount - Raw: \(payload.carbsAmount ?? 0.0), Formatted: \(String(format: "%.1f", carbsAmount)), JSON: \(carbsAmount)")
        LogManager.shared.log(category: .apns, message: "Absorption time - Raw: \(payload.absorptionTime ?? 3.0), Formatted: \(String(format: "%.1f", absorptionTime)), JSON: \(absorptionTime)")

        // Log the final payload for debugging
        if let payloadData = try? JSONSerialization.data(withJSONObject: finalPayload),
           let payloadString = String(data: payloadData, encoding: .utf8)
        {
            LogManager.shared.log(category: .apns, message: "Final payload being sent: \(payloadString)")
        }
        return try await sendAPNSNotification(
            deviceToken: deviceToken,
            bundleIdentifier: bundleIdentifier,
            keyId: keyId,
            apnsKey: apnsKey,
            payload: finalPayload
        )
    }

    /// Sends bolus via APNS push notification
    /// - Parameter payload: The bolus payload to send
    /// - Returns: True if successful, false otherwise
    func sendBolusViaAPNS(payload: LoopAPNSPayload) async throws -> Bool {
        guard validateSetup() else {
            throw LoopAPNSError.invalidURL
        }
        let (deviceToken, bundleIdentifier) = try await getValidDeviceTokenAndBundle()
        let keyId = storage.loopAPNSKeyId.value
        let apnsKey = storage.loopAPNSKey.value

        // Create APNS notification payload (matching Loop's expected format)
        let now = Date()
        let expiration = Date(timeIntervalSinceNow: 5 * 60) // 5 minutes from now

        // Create the complete notification payload (matching Nightscout's exact format)
        // Based on Nightscout's loop.js implementation
        let bolusAmount = payload.bolusAmount ?? 0.0
        var finalPayload = [
            "bolus-entry": bolusAmount,
            "otp": String(payload.otp),
            "remote-address": "LoopFollow",
            "notes": "Sent via LoopFollow APNS",
            "entered-by": "LoopFollow",
            "sent-at": formatDateForAPNS(now),
            "expiration": formatDateForAPNS(expiration),
            "alert": "Remote Bolus Entry: \(String(format: "%.2f", bolusAmount)) U",
        ] as [String: Any]

        // Log the exact bolus amount for debugging precision issues
        LogManager.shared.log(category: .apns, message: "Bolus amount - Raw: \(payload.bolusAmount ?? 0.0), Formatted: \(String(format: "%.2f", bolusAmount)), JSON: \(bolusAmount)")

        // Log the final payload for debugging
        if let payloadData = try? JSONSerialization.data(withJSONObject: finalPayload),
           let payloadString = String(data: payloadData, encoding: .utf8)
        {
            LogManager.shared.log(category: .apns, message: "Final payload being sent: \(payloadString)")
        }
        return try await sendAPNSNotification(
            deviceToken: deviceToken,
            bundleIdentifier: bundleIdentifier,
            keyId: keyId,
            apnsKey: apnsKey,
            payload: finalPayload
        )
    }

    /// Sends an APNS notification
    /// - Parameters:
    ///   - deviceToken: The device token to send to
    ///   - bundleIdentifier: The bundle identifier
    ///   - keyId: The APNS key ID
    ///   - apnsKey: The APNS key
    ///   - payload: The notification payload
    /// - Returns: True if successful, false otherwise
    private func sendAPNSNotification(
        deviceToken: String,
        bundleIdentifier: String,
        keyId: String,
        apnsKey: String,
        payload: [String: Any]
    ) async throws -> Bool {
        // Create JWT token for APNS authentication
        let jwt: String
        do {
            jwt = try createAPNSJWT(keyId: keyId, apnsKey: apnsKey, bundleIdentifier: bundleIdentifier)
        } catch {
            LogManager.shared.log(category: .apns, message: "Failed to create JWT: \(error.localizedDescription)")
            throw LoopAPNSError.invalidURL
        }

        // Determine APNS environment
        let isProduction = storage.productionEnvironment.value
        let apnsEnvironment = isProduction ? "production" : "development"
        let apnsURL = isProduction ? "https://api.push.apple.com" : "https://api.sandbox.push.apple.com"
        let requestURL = URL(string: "\(apnsURL)/3/device/\(deviceToken)")!
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("bearer \(jwt)", forHTTPHeaderField: "authorization")
        request.setValue(bundleIdentifier, forHTTPHeaderField: "apns-topic")
        request.setValue("alert", forHTTPHeaderField: "apns-push-type")
        request.setValue("10", forHTTPHeaderField: "apns-priority") // High priority

        // Log request details for debugging
        LogManager.shared.log(category: .apns, message: "APNS Request URL: \(requestURL)")
        LogManager.shared.log(category: .apns, message: "APNS Request Headers - Authorization: Bearer \(jwt.prefix(50))..., Topic: \(bundleIdentifier)")

        // Validate bundle identifier format
        if !bundleIdentifier.contains(".") {
            LogManager.shared.log(category: .apns, message: "Warning: Bundle identifier may be in wrong format: \(bundleIdentifier)")
        }

        // Validate device token format (should be 64 hex characters)
        let deviceTokenLength = deviceToken.count
        let isHexToken = deviceToken.range(of: "^[0-9A-Fa-f]{64}$", options: .regularExpression) != nil
        LogManager.shared.log(category: .apns, message: "Device token validation - Length: \(deviceTokenLength), Is hex: \(isHexToken)")

        // Create the proper APNS payload structure (matching @parse/node-apn format)
        var apnsPayload: [String: Any] = [
            "aps": [
                "alert": payload["alert"] as? String ?? "",
                "content-available": 1,
                "interruption-level": "time-sensitive",
            ],
        ]

        // Add all the custom payload fields (excluding APNS-specific fields)
        for (key, value) in payload {
            if key != "alert" && key != "content-available" && key != "interruption-level" {
                apnsPayload[key] = value
            }
        }

        // Remove nil values to clean up the payload
        let cleanPayload = apnsPayload.compactMapValues { $0 }

        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: cleanPayload)
            LogManager.shared.log(category: .apns, message: "APNS payload serialized successfully, size: \(jsonData.count) bytes")

            // Log the actual payload being sent
            if let payloadString = String(data: jsonData, encoding: .utf8) {
                LogManager.shared.log(category: .apns, message: "APNS payload being sent: \(payloadString)")
            }
        } catch {
            LogManager.shared.log(category: .apns, message: "Failed to serialize APNS payload: \(error.localizedDescription)")
            throw LoopAPNSError.invalidURL
        }
        request.httpBody = jsonData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    LogManager.shared.log(category: .apns, message: "APNS notification sent successfully")
                    return true
                case 400:
                    let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
                    LogManager.shared.log(category: .apns, message: "APNS error 400: \(errorResponse)")
                    LogManager.shared.log(category: .apns, message: "BadDeviceToken error - this usually means:")
                    LogManager.shared.log(category: .apns, message: "1. Device token is expired or invalid")
                    LogManager.shared.log(category: .apns, message: "2. Device token is from different environment (dev vs prod)")
                    LogManager.shared.log(category: .apns, message: "3. Device token is not registered for this bundle identifier")
                    LogManager.shared.log(category: .apns, message: "Troubleshooting steps:")
                    LogManager.shared.log(category: .apns, message: "1. Refresh device token from Loop app")
                    LogManager.shared.log(category: .apns, message: "2. Check if Loop app is using same environment (dev/prod)")
                    LogManager.shared.log(category: .apns, message: "3. Verify device token is for bundle ID: \(bundleIdentifier)")
                    LogManager.shared.log(category: .apns, message: "4. Check if device token is from production environment")
                    LogManager.shared.log(category: .apns, message: "Current environment: \(storage.productionEnvironment.value ? "Production" : "Development")")
                    throw LoopAPNSError.invalidResponse
                case 403:
                    let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
                    LogManager.shared.log(category: .apns, message: "APNS error 403: Forbidden - \(errorResponse)")
                    LogManager.shared.log(category: .apns, message: "This usually means the APNS key doesn't have permissions for this bundle ID")
                    LogManager.shared.log(category: .apns, message: "Troubleshooting steps:")
                    LogManager.shared.log(category: .apns, message: "1. Check that APNS key \(keyId) has 'Apple Push Notifications service (APNs)' capability enabled")
                    LogManager.shared.log(category: .apns, message: "2. Check that bundle ID \(bundleIdentifier) has 'Push Notifications' capability enabled")
                    LogManager.shared.log(category: .apns, message: "3. Verify the APNS key is associated with the bundle ID in Apple Developer account")
                    throw LoopAPNSError.unauthorized
                case 410:
                    LogManager.shared.log(category: .apns, message: "APNS error 410: Device token is invalid or expired")
                    throw LoopAPNSError.noDeviceToken
                case 429:
                    let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
                    LogManager.shared.log(category: .apns, message: "APNS error 429: Too Many Requests - \(errorResponse)")
                    LogManager.shared.log(category: .apns, message: "Rate limiting error - Apple is throttling APNS requests")
                    LogManager.shared.log(category: .apns, message: "Troubleshooting steps:")
                    LogManager.shared.log(category: .apns, message: "1. Wait a few minutes before trying again")
                    LogManager.shared.log(category: .apns, message: "2. Check if you're sending too many notifications too quickly")
                    LogManager.shared.log(category: .apns, message: "3. Consider implementing exponential backoff")
                    throw LoopAPNSError.rateLimited
                default:
                    let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
                    LogManager.shared.log(category: .apns, message: "APNS error \(httpResponse.statusCode): \(errorResponse)")
                    throw LoopAPNSError.networkError
                }
            } else {
                throw LoopAPNSError.networkError
            }
        } catch {
            LogManager.shared.log(category: .apns, message: "APNS request failed: \(error.localizedDescription)")
            throw LoopAPNSError.networkError
        }
    }

    /// Creates a JWT token for APNS authentication using SwiftJWT
    /// - Parameters:
    ///   - keyId: The APNS key ID
    ///   - apnsKey: The APNS key
    ///   - bundleIdentifier: The bundle identifier
    /// - Returns: The JWT token string
    private func createAPNSJWT(keyId: String, apnsKey: String, bundleIdentifier: String) throws -> String {
        // Validate inputs
        guard !keyId.isEmpty, !apnsKey.isEmpty, !bundleIdentifier.isEmpty else {
            LogManager.shared.log(category: .apns, message: "Invalid JWT inputs - keyId: \(keyId.isEmpty), apnsKey: \(apnsKey.isEmpty), bundleIdentifier: \(bundleIdentifier.isEmpty)")
            throw LoopAPNSError.invalidURL
        }

        // Validate keyId format (should be 10 alphanumeric characters)
        let keyIdPattern = "^[A-Z0-9]{10}$"
        let isValidKeyId = keyId.range(of: keyIdPattern, options: .regularExpression) != nil
        LogManager.shared.log(category: .apns, message: "Key ID validation - Key ID: \(keyId), Is valid format: \(isValidKeyId)")

        // For APNS, the issuer should be the Team ID
        // Try to get the team ID from storage, but if not set, use the key ID (like Nightscout does)
        let teamId: String
        let storedTeamId = storage.loopDeveloperTeamId.value
        if !storedTeamId.isEmpty {
            teamId = storedTeamId
            LogManager.shared.log(category: .apns, message: "Using Loop Team ID from storage: \(teamId)")
        } else {
            teamId = keyId
            LogManager.shared.log(category: .apns, message: "No Loop Team ID in storage, using Key ID as Team ID: \(teamId)")
        }

        // Validate Team ID format (should be 10 alphanumeric characters)
        let teamIdPattern = "^[A-Z0-9]{10}$"
        let isValidTeamId = teamId.range(of: teamIdPattern, options: .regularExpression) != nil
        LogManager.shared.log(category: .apns, message: "Team ID validation - Team ID: \(teamId), Is valid format: \(isValidTeamId)")

        LogManager.shared.log(category: .apns, message: "Creating JWT with keyId: \(keyId), bundleIdentifier: \(bundleIdentifier), teamId: \(teamId)")

        // Log APNS key details for debugging (without exposing the actual key)
        let apnsKeyLines = apnsKey.components(separatedBy: .newlines)
        let apnsKeyLineCount = apnsKeyLines.count
        let hasPrivateKeyHeader = apnsKey.contains("-----BEGIN PRIVATE KEY-----")
        let hasEndHeader = apnsKey.contains("-----END PRIVATE KEY-----")
        LogManager.shared.log(category: .apns, message: "APNS Key details - Lines: \(apnsKeyLineCount), Has PKCS8 header: \(hasPrivateKeyHeader), Has end header: \(hasEndHeader)")

        do {
            // Try using CryptoKit approach for JWT creation (like our original implementation)
            LogManager.shared.log(category: .apns, message: "Creating JWT using CryptoKit approach")

            // Create JWT header
            let header: [String: String] = [
                "alg": "ES256",
                "kid": keyId,
                "typ": "JWT",
            ]

            let now = Date()
            let payload: [String: Any] = [
                "iss": teamId,
                "iat": Int(now.timeIntervalSince1970),
            ]

            // Encode header and payload as base64url
            let headerData = try JSONSerialization.data(withJSONObject: header)
            let payloadData = try JSONSerialization.data(withJSONObject: payload)

            let headerBase64 = base64urlEncode(headerData)
            let payloadBase64 = base64urlEncode(payloadData)

            // Create the signing input
            let signingInput = "\(headerBase64).\(payloadBase64)"

            // Sign the input with the APNS key using CryptoKit
            let signature = try signWithES256(signingInput: signingInput, pemKey: apnsKey)
            let signatureBase64 = base64urlEncode(signature)

            // Combine all parts
            let jwt = "\(signingInput).\(signatureBase64)"

            LogManager.shared.log(category: .apns, message: "JWT created successfully using CryptoKit")
            return jwt
        } catch {
            LogManager.shared.log(category: .apns, message: "Failed to create JWT with CryptoKit: \(error.localizedDescription)")
            throw LoopAPNSError.invalidURL
        }
    }

    /// Extracts key data from PEM format
    /// - Parameter pemString: The PEM formatted private key
    /// - Returns: The extracted key data string
    private func extractKeyData(from pemString: String) -> String? {
        let lines = pemString.components(separatedBy: "\n")
        guard let startIndex = lines.firstIndex(of: "-----BEGIN PRIVATE KEY-----"),
              let endIndex = lines.firstIndex(of: "-----END PRIVATE KEY-----"),
              startIndex < endIndex
        else {
            return nil
        }
        let keyLines = lines[(startIndex + 1) ..< endIndex]
        return keyLines.joined()
    }

    /// Base64url encodes data
    /// - Parameter data: The data to encode
    /// - Returns: Base64url encoded string
    private func base64urlEncode(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Signs data with ES256 algorithm using the APNS key
    /// - Parameters:
    ///   - signingInput: The data to sign
    ///   - pemKey: The PEM formatted private key
    /// - Returns: Base64url encoded signature
    private func signWithES256(signingInput: String, pemKey: String) throws -> Data {
        guard let inputData = signingInput.data(using: .utf8) else {
            LogManager.shared.log(category: .apns, message: "Failed to convert signing input to data")
            throw LoopAPNSError.invalidURL
        }

        do {
            // Create a P256 private key from the PEM key
            let privateKey = try P256.Signing.PrivateKey(pemRepresentation: pemKey)
            let signature = try privateKey.signature(for: inputData)
            return signature.derRepresentation
        } catch {
            LogManager.shared.log(category: .apns, message: "Failed to create signature with CryptoKit: \(error.localizedDescription)")
            throw LoopAPNSError.invalidURL
        }
    }

    // MARK: - Date Formatting Helper

    /// Creates a properly formatted ISO8601 date string with milliseconds (matching Nightscout's format)
    /// - Parameter date: The date to format
    /// - Returns: Formatted date string like "2022-12-24T21:34:02.090Z"
    private func formatDateForAPNS(_ date: Date) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return dateFormatter.string(from: date)
    }

    // MARK: - Override Methods

    func sendOverrideNotification(presetName: String, duration: TimeInterval? = nil) async throws {
        let deviceToken = Storage.shared.loopAPNSDeviceToken.value
        guard !deviceToken.isEmpty else {
            throw LoopAPNSError.deviceTokenNotConfigured
        }

        let bundleIdentifier = Storage.shared.loopAPNSBundleIdentifier.value
        guard !bundleIdentifier.isEmpty else {
            throw LoopAPNSError.bundleIdentifierNotConfigured
        }

        // Create APNS notification payload (matching Loop's expected format)
        let now = Date()
        let expiration = Date(timeIntervalSinceNow: 5 * 60) // 5 minutes from now

        // Create alert text (matching Nightscout's format)
        var alertText = "\(presetName) Temporary Override"
        if let duration = duration, duration > 0 {
            let hours = Int(duration / 3600)
            let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
            if hours > 0 {
                alertText += " (\(hours)h \(minutes)m)"
            } else {
                alertText += " (\(minutes)m)"
            }
        }

        var payload: [String: Any] = [
            "override-name": presetName,
            "remote-address": "LoopFollow",
            "entered-by": "LoopFollow",
            "sent-at": formatDateForAPNS(now),
            "expiration": formatDateForAPNS(expiration),
            "alert": alertText,
        ]

        if let duration = duration, duration > 0 {
            payload["override-duration-minutes"] = Int(duration / 60)
        }

        // Send the notification using the existing APNS infrastructure
        try await sendAPNSNotification(
            deviceToken: deviceToken,
            bundleIdentifier: bundleIdentifier,
            keyId: storage.loopAPNSKeyId.value,
            apnsKey: storage.loopAPNSKey.value,
            payload: payload
        )
    }

    func sendCancelOverrideNotification() async throws {
        let deviceToken = Storage.shared.loopAPNSDeviceToken.value
        guard !deviceToken.isEmpty else {
            throw LoopAPNSError.deviceTokenNotConfigured
        }

        let bundleIdentifier = Storage.shared.loopAPNSBundleIdentifier.value
        guard !bundleIdentifier.isEmpty else {
            throw LoopAPNSError.bundleIdentifierNotConfigured
        }

        // Create APNS notification payload (matching Loop's expected format)
        let now = Date()
        let expiration = Date(timeIntervalSinceNow: 5 * 60) // 5 minutes from now

        let payload: [String: Any] = [
            "cancel-temporary-override": "true",
            "remote-address": "LoopFollow",
            "entered-by": "LoopFollow",
            "sent-at": formatDateForAPNS(now),
            "expiration": formatDateForAPNS(expiration),
            "alert": "Cancel Temporary Override",
        ]

        // Send the notification using the existing APNS infrastructure
        try await sendAPNSNotification(
            deviceToken: deviceToken,
            bundleIdentifier: bundleIdentifier,
            keyId: storage.loopAPNSKeyId.value,
            apnsKey: storage.loopAPNSKey.value,
            payload: payload
        )
    }
}
