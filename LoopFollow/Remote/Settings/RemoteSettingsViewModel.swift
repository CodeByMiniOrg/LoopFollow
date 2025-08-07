// LoopFollow
// RemoteSettingsViewModel.swift

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
    @Published var isLoopDevice: Bool = (Storage.shared.device.value == "Loop")

    // MARK: - Loop APNS Setup Properties

    @Published var loopDeveloperTeamId: String
    @Published var loopAPNSQrCodeURL: String
    @Published var productionEnvironment: Bool
    @Published var isShowingLoopAPNSScanner: Bool = false
    @Published var loopAPNSErrorMessage: String?

    // MARK: - SMS Setup Properties

    @Published var smsPhoneNumber: String
    @Published var smsQrCodeURL: String
    @Published var smsBolusDelayMinutes: Int
    @Published var isShowingSMSScanner: Bool = false
    @Published var smsErrorMessage: String?

    // MARK: - Computed property for Loop APNS Setup validation

    var loopAPNSSetup: Bool {
        !keyId.isEmpty &&
            !apnsKey.isEmpty &&
            !loopDeveloperTeamId.isEmpty &&
            !loopAPNSQrCodeURL.isEmpty &&
            !Storage.shared.deviceToken.value.isEmpty &&
            !Storage.shared.bundleId.value.isEmpty
    }

    // MARK: - Computed property for SMS Setup validation

    var smsSetup: Bool {
        !smsPhoneNumber.isEmpty && !smsQrCodeURL.isEmpty
    }

    private var storage = Storage.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Initialize published properties from storage
        remoteType = storage.remoteType.value
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

        loopDeveloperTeamId = storage.teamId.value ?? ""
        loopAPNSQrCodeURL = storage.loopAPNSQrCodeURL.value
        productionEnvironment = storage.productionEnvironment.value

        // Initialize SMS properties
        smsPhoneNumber = storage.smsPhoneNumber.value
        smsQrCodeURL = storage.smsQrCodeURL.value
        smsBolusDelayMinutes = storage.smsBolusDelayMinutes.value

        setupBindings()
    }

    private func setupBindings() {
        // Basic property bindings
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
            .sink { [weak self] newValue in
                // Validate and fix the APNS key format using the service
                let apnsService = LoopAPNSService()
                let fixedKey = apnsService.validateAndFixAPNSKey(newValue)
                self?.storage.apnsKey.value = fixedKey
            }
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

        // Device type monitoring
        Storage.shared.device.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.isTrioDevice = (newValue == "Trio")
                self?.isLoopDevice = (newValue == "Loop")
            }
            .store(in: &cancellables)

        // Loop APNS bindings
        $loopDeveloperTeamId
            .dropFirst()
            .sink { [weak self] in self?.storage.teamId.value = $0 }
            .store(in: &cancellables)

        $loopAPNSQrCodeURL
            .dropFirst()
            .sink { [weak self] in self?.storage.loopAPNSQrCodeURL.value = $0 }
            .store(in: &cancellables)

        $productionEnvironment
            .dropFirst()
            .sink { [weak self] in self?.storage.productionEnvironment.value = $0 }
            .store(in: &cancellables)

        // SMS bindings
        $smsPhoneNumber
            .dropFirst()
            .sink { [weak self] in self?.storage.smsPhoneNumber.value = $0 }
            .store(in: &cancellables)

        $smsQrCodeURL
            .dropFirst()
            .sink { [weak self] in self?.storage.smsQrCodeURL.value = $0 }
            .store(in: &cancellables)

        $smsBolusDelayMinutes
            .dropFirst()
            .sink { [weak self] in self?.storage.smsBolusDelayMinutes.value = $0 }
            .store(in: &cancellables)
    }

    func handleLoopAPNSQRCodeScanResult(_ result: Result<String, Error>) {
        DispatchQueue.main.async {
            switch result {
            case let .success(code):
                self.loopAPNSQrCodeURL = code
                LogManager.shared.log(category: .apns, message: "Loop APNS QR code scanned: \(code)")
            case let .failure(error):
                self.loopAPNSErrorMessage = "Scanning failed: \(error.localizedDescription)"
            }
            self.isShowingLoopAPNSScanner = false
        }
    }

    func handleSMSQRCodeScanResult(_ result: Result<String, Error>) {
        DispatchQueue.main.async {
            switch result {
            case let .success(code):
                self.smsQrCodeURL = code
                LogManager.shared.log(category: .sms, message: "SMS QR code scanned: \(code)")
            case let .failure(error):
                self.smsErrorMessage = "Scanning failed: \(error.localizedDescription)"
            }
            self.isShowingSMSScanner = false
        }
    }
}
