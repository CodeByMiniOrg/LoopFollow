// LoopFollow
// RemoteSettingsViewModel.swift
// Created by Jonas Björkert.

import Combine
import Foundation
import HealthKit

class RemoteSettingsViewModel: ObservableObject {
    @Published var remoteType: RemoteType
    @Published var user: String
    @Published var sharedSecret: String
    @Published var apnsKey: String
    @Published var keyId: String

    @Published var maxBolus: HKQuantity
    @Published var maxCarbs: HKQuantity
    @Published var maxProtein: HKQuantity
    @Published var maxFat: HKQuantity
    @Published var mealWithBolus: Bool
    @Published var mealWithFatProtein: Bool
    @Published var isTrioDevice: Bool = (Storage.shared.device.value == "Trio")

    // MARK: - Loop Remote Setup Properties

    @Published var loopApiSecret: String
    @Published var loopQrCodeURL: String
    @Published var loopRemoteSetup: Bool
    @Published var isShowingScanner: Bool = false
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    // MARK: - Loop APNS Setup Properties

    @Published var loopAPNSKeyId: String
    @Published var loopAPNSKey: String
    @Published var loopDeveloperTeamId: String
    @Published var loopAPNSQrCodeURL: String
    @Published var loopAPNSDeviceToken: String
    @Published var loopAPNSBundleIdentifier: String
    @Published var loopAPNSSetup: Bool
    @Published var productionEnvironment: Bool
    @Published var isShowingLoopAPNSScanner: Bool = false
    @Published var loopAPNSErrorMessage: String?
    @Published var isRefreshingDeviceToken: Bool = false

    private var storage = Storage.shared
    private var cancellables = Set<AnyCancellable>()

    init(initialRemoteType: RemoteType? = nil) {
        remoteType = initialRemoteType ?? storage.remoteType.value
        user = storage.user.value
        sharedSecret = storage.sharedSecret.value
        apnsKey = storage.apnsKey.value
        keyId = storage.keyId.value
        maxBolus = storage.maxBolus.value
        maxCarbs = storage.maxCarbs.value
        maxProtein = storage.maxProtein.value
        maxFat = storage.maxFat.value
        mealWithBolus = storage.mealWithBolus.value
        mealWithFatProtein = storage.mealWithFatProtein.value

        // Loop remote setup properties
        loopApiSecret = storage.loopApiSecret.value
        loopQrCodeURL = storage.loopQrCodeURL.value
        loopRemoteSetup = storage.loopRemoteSetup.value

        // Loop APNS setup properties
        loopAPNSKeyId = storage.loopAPNSKeyId.value
        loopAPNSKey = storage.loopAPNSKey.value
        loopDeveloperTeamId = storage.loopDeveloperTeamId.value
        loopAPNSQrCodeURL = storage.loopAPNSQrCodeURL.value
        loopAPNSDeviceToken = storage.loopAPNSDeviceToken.value
        loopAPNSBundleIdentifier = storage.loopAPNSBundleIdentifier.value
        loopAPNSSetup = storage.loopAPNSSetup.value
        productionEnvironment = storage.productionEnvironment.value

        setupBindings()

        // Validate initial state
        validateLoopRemoteSetup(apiSecret: loopApiSecret, qrCodeURL: loopQrCodeURL)
        validateLoopAPNSSetup()
    }

    private func setupBindings() {
        $remoteType
            .dropFirst()
            .sink { [weak self] in self?.storage.remoteType.value = $0 }
            .store(in: &cancellables)

        $user
            .dropFirst()
            .sink { [weak self] in self?.storage.user.value = $0 }
            .store(in: &cancellables)

        $sharedSecret
            .dropFirst()
            .sink { [weak self] in self?.storage.sharedSecret.value = $0 }
            .store(in: &cancellables)

        $apnsKey
            .dropFirst()
            .sink { [weak self] in self?.storage.apnsKey.value = $0 }
            .store(in: &cancellables)

        $keyId
            .dropFirst()
            .sink { [weak self] in self?.storage.keyId.value = $0 }
            .store(in: &cancellables)

        $maxBolus
            .dropFirst()
            .sink { [weak self] in self?.storage.maxBolus.value = $0 }
            .store(in: &cancellables)

        $maxCarbs
            .dropFirst()
            .sink { [weak self] in self?.storage.maxCarbs.value = $0 }
            .store(in: &cancellables)

        $maxProtein
            .dropFirst()
            .sink { [weak self] in self?.storage.maxProtein.value = $0 }
            .store(in: &cancellables)

        $maxFat
            .dropFirst()
            .sink { [weak self] in self?.storage.maxFat.value = $0 }
            .store(in: &cancellables)

        $mealWithBolus
            .dropFirst()
            .sink { [weak self] in self?.storage.mealWithBolus.value = $0 }
            .store(in: &cancellables)

        $mealWithFatProtein
            .dropFirst()
            .sink { [weak self] in self?.storage.mealWithFatProtein.value = $0 }
            .store(in: &cancellables)

        // Loop remote setup bindings
        $loopApiSecret
            .dropFirst()
            .sink { [weak self] in self?.storage.loopApiSecret.value = $0 }
            .store(in: &cancellables)

        $loopQrCodeURL
            .dropFirst()
            .sink { [weak self] in self?.storage.loopQrCodeURL.value = $0 }
            .store(in: &cancellables)

        $loopRemoteSetup
            .dropFirst()
            .sink { [weak self] in self?.storage.loopRemoteSetup.value = $0 }
            .store(in: &cancellables)

        // Auto-validate Loop remote setup when API secret or QR code changes
        Publishers.CombineLatest($loopApiSecret, $loopQrCodeURL)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] apiSecret, qrCodeURL in
                self?.validateLoopRemoteSetup(apiSecret: apiSecret, qrCodeURL: qrCodeURL)
            }
            .store(in: &cancellables)

        Storage.shared.device.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.isTrioDevice = (newValue == "Trio")
            }
            .store(in: &cancellables)

        // Loop APNS setup bindings
        $loopAPNSKeyId
            .dropFirst()
            .sink { [weak self] in self?.storage.loopAPNSKeyId.value = $0 }
            .store(in: &cancellables)

        $loopAPNSKey
            .dropFirst()
            .sink { [weak self] in self?.storage.loopAPNSKey.value = $0 }
            .store(in: &cancellables)

        $loopDeveloperTeamId
            .dropFirst()
            .sink { [weak self] in self?.storage.loopDeveloperTeamId.value = $0 }
            .store(in: &cancellables)

        $loopAPNSQrCodeURL
            .dropFirst()
            .sink { [weak self] in self?.storage.loopAPNSQrCodeURL.value = $0 }
            .store(in: &cancellables)

        $loopAPNSDeviceToken
            .dropFirst()
            .sink { [weak self] in self?.storage.loopAPNSDeviceToken.value = $0 }
            .store(in: &cancellables)

        $loopAPNSBundleIdentifier
            .dropFirst()
            .sink { [weak self] in self?.storage.loopAPNSBundleIdentifier.value = $0 }
            .store(in: &cancellables)

        $loopAPNSSetup
            .dropFirst()
            .sink { [weak self] in self?.storage.loopAPNSSetup.value = $0 }
            .store(in: &cancellables)

        $productionEnvironment
            .dropFirst()
            .sink { [weak self] in self?.storage.productionEnvironment.value = $0 }
            .store(in: &cancellables)

        // Auto-validate Loop APNS setup when key ID, APNS key, or QR code changes
        Publishers.CombineLatest3($loopAPNSKeyId, $loopAPNSKey, $loopAPNSQrCodeURL)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                self?.validateLoopAPNSSetup()
            }
            .store(in: &cancellables)
    }

    // MARK: - Loop Remote Setup Methods

    private func validateLoopRemoteSetup(apiSecret: String, qrCodeURL: String) {
        // Check if we have both API secret and a valid TOTP QR code
        let hasApiSecret = !apiSecret.isEmpty
        let hasValidTOTP = !qrCodeURL.isEmpty && TOTPGenerator.extractOTPFromURL(qrCodeURL) != nil

        // Auto-set loopRemoteSetup to true if both conditions are met
        if hasApiSecret && hasValidTOTP {
            loopRemoteSetup = true
        } else {
            loopRemoteSetup = false
        }
    }

    func saveLoopRemoteSetup() {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil

            // Validate the setup
            guard !self.storage.url.value.isEmpty else {
                self.errorMessage = "Please configure your Nightscout URL in the main settings"
                self.isLoading = false
                return
            }

            guard !self.loopApiSecret.isEmpty else {
                self.errorMessage = "Please configure your API Secret"
                self.isLoading = false
                return
            }

            guard !self.loopQrCodeURL.isEmpty else {
                self.errorMessage = "Please scan the QR code from your Loop app"
                self.isLoading = false
                return
            }

            // Mark setup as complete (values are already saved via bindings)
            self.loopRemoteSetup = true

            self.isLoading = false
        }
    }

    func handleQRCodeScanResult(_ result: Result<String, Error>) {
        DispatchQueue.main.async {
            switch result {
            case let .success(code):
                self.loopQrCodeURL = code
            case let .failure(error):
                self.errorMessage = "Scanning failed: \(error.localizedDescription)"
            }
            self.isShowingScanner = false
        }
    }

    // MARK: - Loop APNS Setup Methods

    func validateLoopAPNSSetup() {
        // Use the service's basic validation method to check required fields
        let apnsService = LoopAPNSService()
        let isValid = apnsService.validateBasicSetup()

        // Auto-set loopAPNSSetup to true if basic conditions are met
        loopAPNSSetup = isValid

        // Log the validation result for debugging
        LogManager.shared.log(category: .apns, message: "Loop APNS setup validation result: \(isValid)")
    }

    private func validateFullLoopAPNSSetup() {
        // Use the service's full validation method to check all fields including device token
        let apnsService = LoopAPNSService()
        let isValid = apnsService.validateSetup()

        // Set loopAPNSSetup to true if all conditions are met
        loopAPNSSetup = isValid
    }

    func refreshDeviceToken() async {
        await MainActor.run {
            isRefreshingDeviceToken = true
            loopAPNSErrorMessage = nil
        }

        let apnsService = LoopAPNSService()
        let success = await apnsService.refreshDeviceToken()

        await MainActor.run {
            self.isRefreshingDeviceToken = false
            if success {
                self.loopAPNSDeviceToken = self.storage.loopAPNSDeviceToken.value
                self.validateFullLoopAPNSSetup()
            } else {
                self.loopAPNSErrorMessage = "Failed to refresh device token. Check your Nightscout URL and API secret."
            }
        }
    }

    func handleLoopAPNSQRCodeScanResult(_ result: Result<String, Error>) {
        DispatchQueue.main.async {
            switch result {
            case let .success(code):
                self.loopAPNSQrCodeURL = code
            case let .failure(error):
                self.loopAPNSErrorMessage = "Scanning failed: \(error.localizedDescription)"
            }
            self.isShowingLoopAPNSScanner = false
        }
    }
}
