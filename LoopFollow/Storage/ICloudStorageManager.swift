// LoopFollow
// ICloudStorageManager.swift
// Created by codebymini.

import Combine
import Foundation
import HealthKit
import UIKit

/// Manages iCloud storage for complete LoopFollow settings backup/restore
/// Uses NSUbiquitousKeyValueStore to sync complete Storage state across devices
class ICloudStorageManager: ObservableObject {
    static let shared = ICloudStorageManager()

    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupICloudSync()
    }

    // MARK: - iCloud Setup

    private func setupICloudSync() {
        // Enable automatic synchronization
        ubiquitousStore.synchronize()

        // Listen for iCloud changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ubiquitousKeyValueStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore
        )
    }

    @objc private func ubiquitousKeyValueStoreDidChange(_: Notification) {
        LogManager.shared.log(category: .general, message: "iCloud data changed externally - user can manually restore if needed")
    }

    // MARK: - Complete Storage Backup

    /// Backup complete Storage state to iCloud
    func backupToICloud() {
        LogManager.shared.log(category: .general, message: "Starting complete Storage backup to iCloud...")

        do {
            let storageData = try createStorageBackup()
            ubiquitousStore.set(storageData, forKey: "completeStorageBackup")
            ubiquitousStore.synchronize()

            LogManager.shared.log(category: .general, message: "Complete Storage backup to iCloud successful")
        } catch {
            LogManager.shared.log(category: .general, message: "Failed to backup Storage to iCloud: \(error)")
        }
    }

    /// Create a minimal backup of critical Storage values only
    private func createStorageBackup() throws -> Data {
        let storage = Storage.shared

        // Create a dictionary with only the most critical settings
        var backup: [String: Any] = [:]

        do {
            LogManager.shared.log(category: .general, message: "Starting settings backup...")
            // Core connection settings
            backup["url"] = storage.url.value
            backup["token"] = storage.token.value


            // Remote settings
            backup["deviceToken"] = storage.deviceToken.value
            backup["remoteType"] = storage.remoteType.value.rawValue
            backup["sharedSecret"] = storage.sharedSecret.value
            backup["productionEnvironment"] = storage.productionEnvironment.value
            backup["apnsKey"] = storage.apnsKey.value
            backup["teamId"] = storage.teamId.value
            backup["keyId"] = storage.keyId.value
            backup["bundleId"] = storage.bundleId.value
            backup["user"] = storage.user.value
            backup["loopAPNSSetup"] = storage.loopAPNSSetup.value
            backup["loopAPNSQrCodeURL"] = storage.loopAPNSQrCodeURL.value
            backup["loopAPNSDeviceToken"] = storage.loopAPNSDeviceToken.value
            backup["loopAPNSBundleIdentifier"] = storage.loopAPNSBundleIdentifier.value


            backup["maxBolus"] = try encodeHKQuantity(storage.maxBolus.value, expectedUnit: .internationalUnit())
            backup["maxCarbs"] = try encodeHKQuantity(storage.maxCarbs.value, expectedUnit: .gram())
            backup["maxProtein"] = try encodeHKQuantity(storage.maxProtein.value, expectedUnit: .gram())
            backup["maxFat"] = try encodeHKQuantity(storage.maxFat.value, expectedUnit: .gram())

            // Core app settings
            backup["units"] = storage.units.value
            backup["device"] = storage.device.value
            backup["nsWriteAuth"] = storage.nsWriteAuth.value
            backup["nsAdminAuth"] = storage.nsAdminAuth.value

            // UI settings
            backup["appBadge"] = storage.appBadge.value
            backup["colorBGText"] = storage.colorBGText.value
            backup["forceDarkMode"] = storage.forceDarkMode.value
            backup["showStats"] = storage.showStats.value
            backup["useIFCC"] = storage.useIFCC.value
            backup["showSmallGraph"] = storage.showSmallGraph.value
            backup["screenlockSwitchState"] = storage.screenlockSwitchState.value
            backup["showDisplayName"] = storage.showDisplayName.value
            backup["forcePortraitMode"] = storage.forcePortraitMode.value

            // Graph settings
            backup["showDots"] = storage.showDots.value
            backup["showLines"] = storage.showLines.value
            backup["showValues"] = storage.showValues.value
            backup["showAbsorption"] = storage.showAbsorption.value
            backup["showDIALines"] = storage.showDIALines.value
            backup["show30MinLine"] = storage.show30MinLine.value
            backup["show90MinLine"] = storage.show90MinLine.value
            backup["showMidnightLines"] = storage.showMidnightLines.value
            backup["smallGraphTreatments"] = storage.smallGraphTreatments.value
            backup["smallGraphHeight"] = storage.smallGraphHeight.value
            backup["predictionToLoad"] = storage.predictionToLoad.value
            backup["minBasalScale"] = storage.minBasalScale.value
            backup["minBGScale"] = storage.minBGScale.value
            backup["lowLine"] = storage.lowLine.value
            backup["highLine"] = storage.highLine.value
            backup["downloadDays"] = storage.downloadDays.value

            // Calendar settings
            backup["writeCalendarEvent"] = storage.writeCalendarEvent.value
            backup["calendarIdentifier"] = storage.calendarIdentifier.value
            backup["watchLine1"] = storage.watchLine1.value
            backup["watchLine2"] = storage.watchLine2.value

            // Dexcom Share settings
            backup["shareUserName"] = storage.shareUserName.value
            backup["sharePassword"] = storage.sharePassword.value
            backup["shareServer"] = storage.shareServer.value

            // Chart settings
            backup["chartScaleX"] = storage.chartScaleX.value

            // Advanced settings
            backup["downloadTreatments"] = storage.downloadTreatments.value
            backup["downloadPrediction"] = storage.downloadPrediction.value
            backup["graphOtherTreatments"] = storage.graphOtherTreatments.value
            backup["graphBasal"] = storage.graphBasal.value
            backup["graphBolus"] = storage.graphBolus.value
            backup["graphCarbs"] = storage.graphCarbs.value
            backup["bgUpdateDelay"] = storage.bgUpdateDelay.value

            // Add backup timestamp
            backup["backupTimestamp"] = Date().timeIntervalSince1970
            backup["backupVersion"] = "1.0"

            LogManager.shared.log(category: .general, message: "Minimal settings added, attempting JSON serialization...")

        } catch {
            LogManager.shared.log(category: .general, message: "Error during backup creation: \(error)")
            throw error
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: backup)
            LogManager.shared.log(category: .general, message: "JSON serialization successful, data size: \(jsonData.count) bytes")
            return jsonData
        } catch {
            LogManager.shared.log(category: .general, message: "JSON serialization failed: \(error)")
            throw error
        }
    }

    /// Create a backup of alarm settings only
    private func createAlarmBackup() throws -> Data {
        let storage = Storage.shared

        // Create a dictionary with only alarm settings
        var backup: [String: Any] = [:]

        do {
            LogManager.shared.log(category: .general, message: "Starting alarm settings backup...")

            // Alarms
            backup["alarms"] = try encodeAlarms(storage.alarms.value)
            backup["alarmConfiguration"] = try encodeAlarmConfiguration(storage.alarmConfiguration.value)

            // Add backup timestamp
            backup["backupTimestamp"] = Date().timeIntervalSince1970
            backup["backupVersion"] = "1.0"
            backup["backupType"] = "alarms"

            LogManager.shared.log(category: .general, message: "Alarm settings added, attempting JSON serialization...")

        } catch {
            LogManager.shared.log(category: .general, message: "Error during alarm backup creation: \(error)")
            throw error
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: backup)
            LogManager.shared.log(category: .general, message: "Alarm JSON serialization successful, data size: \(jsonData.count) bytes")
            return jsonData
        } catch {
            LogManager.shared.log(category: .general, message: "Alarm JSON serialization failed: \(error)")
            throw error
        }
    }

    /// Encode HKQuantity for storage
    private func encodeHKQuantity(_ quantity: HKQuantity, expectedUnit: HKUnit) throws -> [String: Any] {
        let value = quantity.doubleValue(for: expectedUnit)
        let unitString = expectedUnit.unitString

        return [
            "value": value,
            "unit": unitString,
        ]
    }

    /// Encode BLEDevice for storage
    private func encodeBLEDevice(_ device: BLEDevice) throws -> [String: Any] {
        return [
            "id": device.id.uuidString,
            "name": device.name,
            "rssi": device.rssi,
            "isConnected": device.isConnected,
            "advertisedServices": device.advertisedServices,
            "lastSeen": device.lastSeen.timeIntervalSince1970,
            "lastConnected": device.lastConnected?.timeIntervalSince1970,
        ]
    }

    /// Encode Alarm for storage
    private func encodeAlarm(_ alarm: Alarm) throws -> [String: Any] {
        return [
            "id": alarm.id.uuidString,
            "type": alarm.type.rawValue,
            "name": alarm.name,
            "isEnabled": alarm.isEnabled,
            "snoozedUntil": alarm.snoozedUntil?.timeIntervalSince1970,
            "aboveBG": alarm.aboveBG,
            "belowBG": alarm.belowBG,
            "threshold": alarm.threshold,
            "predictiveMinutes": alarm.predictiveMinutes,
            "delta": alarm.delta,
            "persistentMinutes": alarm.persistentMinutes,
            "monitoringWindow": alarm.monitoringWindow,
            "soundFile": alarm.soundFile.rawValue,
            "snoozeDuration": alarm.snoozeDuration,
            "playSoundOption": alarm.playSoundOption.rawValue,
            "repeatSoundOption": alarm.repeatSoundOption.rawValue,
            "activeOption": alarm.activeOption.rawValue,
            "missedBolusPrebolusWindow": alarm.missedBolusPrebolusWindow,
            "missedBolusIgnoreSmallBolusUnits": alarm.missedBolusIgnoreSmallBolusUnits,
            "missedBolusIgnoreUnderGrams": alarm.missedBolusIgnoreUnderGrams,
            "missedBolusIgnoreUnderBG": alarm.missedBolusIgnoreUnderBG,
            "bolusCountThreshold": alarm.bolusCountThreshold,
            "bolusWindowMinutes": alarm.bolusWindowMinutes,
        ]
    }

    /// Encode Alarms array for storage
    private func encodeAlarms(_ alarms: [Alarm]) throws -> [[String: Any]] {
        return try alarms.map { try encodeAlarm($0) }
    }

    /// Encode AlarmConfiguration for storage
    private func encodeAlarmConfiguration(_ config: AlarmConfiguration) throws -> [String: Any] {
        return [
            "snoozeUntil": config.snoozeUntil?.timeIntervalSince1970,
            "muteUntil": config.muteUntil?.timeIntervalSince1970,
            "dayStart": [
                "hour": config.dayStart.hour,
                "minute": config.dayStart.minute,
            ],
            "nightStart": [
                "hour": config.nightStart.hour,
                "minute": config.nightStart.minute,
            ],
            "overrideSystemOutputVolume": config.overrideSystemOutputVolume,
            "forcedOutputVolume": config.forcedOutputVolume,
            "audioDuringCalls": config.audioDuringCalls,
            "ignoreZeroBG": config.ignoreZeroBG,
            "autoSnoozeCGMStart": config.autoSnoozeCGMStart,
        ]
    }

    // MARK: - Complete Storage Restore

    /// Restore complete Storage state from iCloud
    func restoreFromICloud() {
        LogManager.shared.log(category: .general, message: "Starting complete Storage restore from iCloud...")

        guard let data = ubiquitousStore.data(forKey: "completeStorageBackup") else {
            LogManager.shared.log(category: .general, message: "No backup data found in iCloud")
            return
        }

        do {
            try restoreStorageFromBackup(data)
            LogManager.shared.log(category: .general, message: "Complete Storage restore from iCloud successful")
        } catch {
            LogManager.shared.log(category: .general, message: "Failed to restore Storage from iCloud: \(error)")
        }
    }

    /// Restore Storage from backup data (minimal settings only)
    private func restoreStorageFromBackup(_ data: Data) throws {
        guard let backup = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "ICloudStorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid backup format"])
        }

        let storage = Storage.shared

        // Restore core connection settings
        if let value = backup["remoteType"] as? String, let remoteType = RemoteType(rawValue: value) {
            storage.remoteType.value = remoteType
        }
        if let value = backup["deviceToken"] as? String {
            storage.deviceToken.value = value
        }
        if let value = backup["sharedSecret"] as? String {
            storage.sharedSecret.value = value
        }
        if let value = backup["productionEnvironment"] as? Bool {
            storage.productionEnvironment.value = value
        }
        if let value = backup["apnsKey"] as? String {
            storage.apnsKey.value = value
        }
        if let value = backup["teamId"] as? String {
            storage.teamId.value = value
        }
        if let value = backup["keyId"] as? String {
            storage.keyId.value = value
        }
        if let value = backup["bundleId"] as? String {
            storage.bundleId.value = value
        }
        if let value = backup["user"] as? String {
            storage.user.value = value
        }

        // Restore HKQuantities
        if let maxBolusData = backup["maxBolus"] as? [String: Any] {
            storage.maxBolus.value = try decodeHKQuantity(maxBolusData)
        }
        if let maxCarbsData = backup["maxCarbs"] as? [String: Any] {
            storage.maxCarbs.value = try decodeHKQuantity(maxCarbsData)
        }
        if let maxProteinData = backup["maxProtein"] as? [String: Any] {
            storage.maxProtein.value = try decodeHKQuantity(maxProteinData)
        }
        if let maxFatData = backup["maxFat"] as? [String: Any] {
            storage.maxFat.value = try decodeHKQuantity(maxFatData)
        }

        // Restore core app settings
        if let value = backup["token"] as? String {
            storage.token.value = value
        }
        if let value = backup["units"] as? String {
            storage.units.value = value
        }
        if let value = backup["url"] as? String {
            storage.url.value = value
        }
        if let value = backup["device"] as? String {
            storage.device.value = value
        }
        if let value = backup["nsWriteAuth"] as? Bool {
            storage.nsWriteAuth.value = value
        }
        if let value = backup["nsAdminAuth"] as? Bool {
            storage.nsAdminAuth.value = value
        }

        // Restore essential UI settings
        if let value = backup["appBadge"] as? Bool {
            storage.appBadge.value = value
        }
        if let value = backup["colorBGText"] as? Bool {
            storage.colorBGText.value = value
        }
        if let value = backup["forceDarkMode"] as? Bool {
            storage.forceDarkMode.value = value
        }
        if let value = backup["showStats"] as? Bool {
            storage.showStats.value = value
        }
        if let value = backup["useIFCC"] as? Bool {
            storage.useIFCC.value = value
        }
        if let value = backup["showSmallGraph"] as? Bool {
            storage.showSmallGraph.value = value
        }
        if let value = backup["screenlockSwitchState"] as? Bool {
            storage.screenlockSwitchState.value = value
        }
        if let value = backup["showDisplayName"] as? Bool {
            storage.showDisplayName.value = value
        }
        if let value = backup["forcePortraitMode"] as? Bool {
            storage.forcePortraitMode.value = value
        }

        // Restore graph settings
        if let value = backup["showDots"] as? Bool {
            storage.showDots.value = value
        }
        if let value = backup["showLines"] as? Bool {
            storage.showLines.value = value
        }
        if let value = backup["showValues"] as? Bool {
            storage.showValues.value = value
        }
        if let value = backup["showAbsorption"] as? Bool {
            storage.showAbsorption.value = value
        }
        if let value = backup["showDIALines"] as? Bool {
            storage.showDIALines.value = value
        }
        if let value = backup["show30MinLine"] as? Bool {
            storage.show30MinLine.value = value
        }
        if let value = backup["show90MinLine"] as? Bool {
            storage.show90MinLine.value = value
        }
        if let value = backup["showMidnightLines"] as? Bool {
            storage.showMidnightLines.value = value
        }
        if let value = backup["smallGraphTreatments"] as? Bool {
            storage.smallGraphTreatments.value = value
        }
        if let value = backup["smallGraphHeight"] as? Int {
            storage.smallGraphHeight.value = value
        }
        if let value = backup["predictionToLoad"] as? Double {
            storage.predictionToLoad.value = value
        }
        if let value = backup["minBasalScale"] as? Double {
            storage.minBasalScale.value = value
        }
        if let value = backup["minBGScale"] as? Double {
            storage.minBGScale.value = value
        }
        if let value = backup["lowLine"] as? Double {
            storage.lowLine.value = value
        }
        if let value = backup["highLine"] as? Double {
            storage.highLine.value = value
        }
        if let value = backup["downloadDays"] as? Int {
            storage.downloadDays.value = value
        }

        // Restore calendar settings
        if let value = backup["writeCalendarEvent"] as? Bool {
            storage.writeCalendarEvent.value = value
        }
        if let value = backup["calendarIdentifier"] as? String {
            storage.calendarIdentifier.value = value
        }
        if let value = backup["watchLine1"] as? String {
            storage.watchLine1.value = value
        }
        if let value = backup["watchLine2"] as? String {
            storage.watchLine2.value = value
        }

        // Restore Dexcom Share settings
        if let value = backup["shareUserName"] as? String {
            storage.shareUserName.value = value
        }
        if let value = backup["sharePassword"] as? String {
            storage.sharePassword.value = value
        }
        if let value = backup["shareServer"] as? String {
            storage.shareServer.value = value
        }

        // Restore chart settings
        if let value = backup["chartScaleX"] as? Double {
            storage.chartScaleX.value = value
        }

        // Restore advanced settings
        if let value = backup["downloadTreatments"] as? Bool {
            storage.downloadTreatments.value = value
        }
        if let value = backup["downloadPrediction"] as? Bool {
            storage.downloadPrediction.value = value
        }
        if let value = backup["graphOtherTreatments"] as? Bool {
            storage.graphOtherTreatments.value = value
        }
        if let value = backup["graphBasal"] as? Bool {
            storage.graphBasal.value = value
        }
        if let value = backup["graphBolus"] as? Bool {
            storage.graphBolus.value = value
        }
        if let value = backup["graphCarbs"] as? Bool {
            storage.graphCarbs.value = value
        }
        if let value = backup["bgUpdateDelay"] as? Int {
            storage.bgUpdateDelay.value = value
        }

        // Restore Loop APNS settings
        if let value = backup["loopAPNSSetup"] as? Bool {
            storage.loopAPNSSetup.value = value
        }
        if let value = backup["loopAPNSQrCodeURL"] as? String {
            storage.loopAPNSQrCodeURL.value = value
        }
        if let value = backup["loopAPNSDeviceToken"] as? String {
            storage.loopAPNSDeviceToken.value = value
        }
        if let value = backup["loopAPNSBundleIdentifier"] as? String {
            storage.loopAPNSBundleIdentifier.value = value
        }
    }

    /// Restore alarm settings from backup data
    private func restoreAlarmsFromBackup(_ data: Data) throws {
        guard let backup = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "ICloudStorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid backup format"])
        }

        let storage = Storage.shared

        // Restore alarms
        if let alarmsData = backup["alarms"] as? [[String: Any]] {
            storage.alarms.value = try decodeAlarms(alarmsData)
        }
        if let configData = backup["alarmConfiguration"] as? [String: Any] {
            storage.alarmConfiguration.value = try decodeAlarmConfiguration(configData)
        }
    }

    /// Decode HKQuantity from storage
    private func decodeHKQuantity(_ data: [String: Any]) throws -> HKQuantity {
        guard let value = data["value"] as? Double,
              let unitString = data["unit"] as? String
        else {
            throw NSError(domain: "ICloudStorageManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid HKQuantity data"])
        }

        let unit: HKUnit
        switch unitString {
        case "IU":
            unit = .internationalUnit()
        case "g":
            unit = .gram()
        default:
            unit = .gram() // fallback
        }

        return HKQuantity(unit: unit, doubleValue: value)
    }

    /// Decode BLEDevice from storage
    private func decodeBLEDevice(_ data: [String: Any]) throws -> BLEDevice {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let rssi = data["rssi"] as? Int,
              let isConnected = data["isConnected"] as? Bool,
              let lastSeenInterval = data["lastSeen"] as? TimeInterval
        else {
            throw NSError(domain: "ICloudStorageManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid BLEDevice data"])
        }

        let name = data["name"] as? String
        let advertisedServices = data["advertisedServices"] as? [String]
        let lastConnected: Date?
        if let lastConnectedInterval = data["lastConnected"] as? TimeInterval {
            lastConnected = Date(timeIntervalSince1970: lastConnectedInterval)
        } else {
            lastConnected = nil
        }

        return BLEDevice(
            id: id,
            name: name,
            rssi: rssi,
            isConnected: isConnected,
            advertisedServices: advertisedServices,
            lastSeen: Date(timeIntervalSince1970: lastSeenInterval),
            lastConnected: lastConnected
        )
    }

    /// Decode Alarm from storage
    private func decodeAlarm(_ data: [String: Any]) throws -> Alarm {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let typeString = data["type"] as? String,
              let type = AlarmType(rawValue: typeString),
              let name = data["name"] as? String,
              let isEnabled = data["isEnabled"] as? Bool,
              let soundFileString = data["soundFile"] as? String,
              let soundFile = SoundFile(rawValue: soundFileString),
              let snoozeDuration = data["snoozeDuration"] as? Int,
              let playSoundOptionString = data["playSoundOption"] as? String,
              let playSoundOption = PlaySoundOption(rawValue: playSoundOptionString),
              let repeatSoundOptionString = data["repeatSoundOption"] as? String,
              let repeatSoundOption = RepeatSoundOption(rawValue: repeatSoundOptionString),
              let activeOptionString = data["activeOption"] as? String,
              let activeOption = ActiveOption(rawValue: activeOptionString)
        else {
            throw NSError(domain: "ICloudStorageManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid Alarm data"])
        }

        var alarm = Alarm(type: type)
        alarm.id = id
        alarm.name = name
        alarm.isEnabled = isEnabled
        alarm.soundFile = soundFile
        alarm.snoozeDuration = snoozeDuration
        alarm.playSoundOption = playSoundOption
        alarm.repeatSoundOption = repeatSoundOption
        alarm.activeOption = activeOption

        // Optional properties
        if let snoozedUntilInterval = data["snoozedUntil"] as? TimeInterval {
            alarm.snoozedUntil = Date(timeIntervalSince1970: snoozedUntilInterval)
        }
        alarm.aboveBG = data["aboveBG"] as? Double
        alarm.belowBG = data["belowBG"] as? Double
        alarm.threshold = data["threshold"] as? Double
        alarm.predictiveMinutes = data["predictiveMinutes"] as? Int
        alarm.delta = data["delta"] as? Double
        alarm.persistentMinutes = data["persistentMinutes"] as? Int
        alarm.monitoringWindow = data["monitoringWindow"] as? Int
        alarm.missedBolusPrebolusWindow = data["missedBolusPrebolusWindow"] as? Int
        alarm.missedBolusIgnoreSmallBolusUnits = data["missedBolusIgnoreSmallBolusUnits"] as? Double
        alarm.missedBolusIgnoreUnderGrams = data["missedBolusIgnoreUnderGrams"] as? Double
        alarm.missedBolusIgnoreUnderBG = data["missedBolusIgnoreUnderBG"] as? Double
        alarm.bolusCountThreshold = data["bolusCountThreshold"] as? Int
        alarm.bolusWindowMinutes = data["bolusWindowMinutes"] as? Int

        return alarm
    }

    /// Decode Alarms array from storage
    private func decodeAlarms(_ data: [[String: Any]]) throws -> [Alarm] {
        return try data.map { try decodeAlarm($0) }
    }

    /// Decode AlarmConfiguration from storage
    private func decodeAlarmConfiguration(_ data: [String: Any]) throws -> AlarmConfiguration {
        guard let dayStartData = data["dayStart"] as? [String: Any],
              let dayStartHour = dayStartData["hour"] as? Int,
              let dayStartMinute = dayStartData["minute"] as? Int,
              let nightStartData = data["nightStart"] as? [String: Any],
              let nightStartHour = nightStartData["hour"] as? Int,
              let nightStartMinute = nightStartData["minute"] as? Int,
              let overrideSystemOutputVolume = data["overrideSystemOutputVolume"] as? Bool,
              let forcedOutputVolume = data["forcedOutputVolume"] as? Float,
              let audioDuringCalls = data["audioDuringCalls"] as? Bool,
              let ignoreZeroBG = data["ignoreZeroBG"] as? Bool,
              let autoSnoozeCGMStart = data["autoSnoozeCGMStart"] as? Bool
        else {
            throw NSError(domain: "ICloudStorageManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid AlarmConfiguration data"])
        }

        let snoozeUntil: Date?
        if let snoozeUntilInterval = data["snoozeUntil"] as? TimeInterval {
            snoozeUntil = Date(timeIntervalSince1970: snoozeUntilInterval)
        } else {
            snoozeUntil = nil
        }

        let muteUntil: Date?
        if let muteUntilInterval = data["muteUntil"] as? TimeInterval {
            muteUntil = Date(timeIntervalSince1970: muteUntilInterval)
        } else {
            muteUntil = nil
        }

        return AlarmConfiguration(
            snoozeUntil: snoozeUntil,
            muteUntil: muteUntil,
            dayStart: TimeOfDay(hour: dayStartHour, minute: dayStartMinute),
            nightStart: TimeOfDay(hour: nightStartHour, minute: nightStartMinute),
            overrideSystemOutputVolume: overrideSystemOutputVolume,
            forcedOutputVolume: forcedOutputVolume,
            audioDuringCalls: audioDuringCalls,
            ignoreZeroBG: ignoreZeroBG,
            autoSnoozeCGMStart: autoSnoozeCGMStart
        )
    }

    // MARK: - Public Methods

    /// Check if iCloud is available
    var isICloudAvailable: Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }

    /// Check if backup exists in iCloud
    var hasBackup: Bool {
        return ubiquitousStore.data(forKey: "completeStorageBackup") != nil
    }

    /// Get backup info (timestamp and version)
    func getBackupInfo() -> (timestamp: Date?, version: String?) {
        guard let data = ubiquitousStore.data(forKey: "completeStorageBackup"),
              let backup = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return (nil, nil)
        }

        let timestamp: Date?
        if let timestampInterval = backup["backupTimestamp"] as? TimeInterval {
            timestamp = Date(timeIntervalSince1970: timestampInterval)
        } else {
            timestamp = nil
        }

        let version = backup["backupVersion"] as? String

        return (timestamp, version)
    }

    /// Force synchronization with iCloud
    func synchronize() {
        ubiquitousStore.synchronize()
    }

    /// Clear all iCloud data
    func clearICloudData() {
        ubiquitousStore.removeObject(forKey: "completeStorageBackup")
        ubiquitousStore.synchronize()
        LogManager.shared.log(category: .general, message: "Cleared all iCloud backup data")
    }
}
