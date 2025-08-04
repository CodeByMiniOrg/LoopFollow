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

        // Create organized backup structure
        var backup: [String: Any] = [:]

        do {
            LogManager.shared.log(category: .general, message: "Starting organized settings backup...")

            // Connection Settings
            backup["connection"] = createConnectionSettings(storage)

            // Remote Settings
            backup["remote"] = createRemoteSettings(storage)

            // Core App Settings
            backup["core"] = createCoreAppSettings(storage)

            // UI Settings
            backup["ui"] = createUISettings(storage)

            // Graph Settings
            backup["graph"] = createGraphSettings(storage)

            // Calendar Settings
            backup["calendar"] = createCalendarSettings(storage)

            // Dexcom Share Settings
            backup["dexcomShare"] = createDexcomShareSettings(storage)

            // Advanced Settings
            backup["advanced"] = createAdvancedSettings(storage)

            // Alarm Settings
            backup["alarms"] = createAlarmSettings(storage)

            // Version Info
            backup["version"] = createVersionInfo(storage)

            // Add backup metadata
            backup["backupTimestamp"] = Date().timeIntervalSince1970
            backup["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

            LogManager.shared.log(category: .general, message: "Organized settings backup created, attempting JSON serialization...")

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

    // MARK: - Settings Group Creation Methods

    /// Create connection settings group
    private func createConnectionSettings(_ storage: Storage) -> [String: Any] {
        return [
            "url": storage.url.value,
            "token": storage.token.value,
            "device": storage.device.value,
            "units": storage.units.value,
            "nsWriteAuth": storage.nsWriteAuth.value,
            "nsAdminAuth": storage.nsAdminAuth.value,
        ]
    }

    /// Create remote settings group
    private func createRemoteSettings(_ storage: Storage) -> [String: Any] {
        return [
            "remoteType": storage.remoteType.value.rawValue,
            "deviceToken": storage.deviceToken.value,
            "sharedSecret": storage.sharedSecret.value,
            "productionEnvironment": storage.productionEnvironment.value,
            "apnsKey": storage.apnsKey.value,
            "teamId": storage.teamId.value,
            "keyId": storage.keyId.value,
            "bundleId": storage.bundleId.value,
            "user": storage.user.value,
            "loopAPNSQrCodeURL": storage.loopAPNSQrCodeURL.value,
        ]
    }

    /// Create core app settings group
    private func createCoreAppSettings(_ storage: Storage) -> [String: Any] {
        return [
            "maxBolus": try? encodeHKQuantity(storage.maxBolus.value, expectedUnit: .internationalUnit()),
            "maxCarbs": try? encodeHKQuantity(storage.maxCarbs.value, expectedUnit: .gram()),
            "maxProtein": try? encodeHKQuantity(storage.maxProtein.value, expectedUnit: .gram()),
            "maxFat": try? encodeHKQuantity(storage.maxFat.value, expectedUnit: .gram()),
            "mealWithBolus": storage.mealWithBolus.value,
            "mealWithFatProtein": storage.mealWithFatProtein.value,
            "backgroundRefreshType": storage.backgroundRefreshType.value.rawValue,
            "debugLogLevel": storage.debugLogLevel.value,
        ]
    }

    /// Create UI settings group
    private func createUISettings(_ storage: Storage) -> [String: Any] {
        return [
            "appBadge": storage.appBadge.value,
            "colorBGText": storage.colorBGText.value,
            "forceDarkMode": storage.forceDarkMode.value,
            "showStats": storage.showStats.value,
            "useIFCC": storage.useIFCC.value,
            "showSmallGraph": storage.showSmallGraph.value,
            "screenlockSwitchState": storage.screenlockSwitchState.value,
            "showDisplayName": storage.showDisplayName.value,
            "forcePortraitMode": storage.forcePortraitMode.value,
            "snoozerEmoji": storage.snoozerEmoji.value,
            "hideInfoTable": storage.hideInfoTable.value,
            "persistentNotification": storage.persistentNotification.value,
            "alarmsPosition": storage.alarmsPosition.value.rawValue,
            "remotePosition": storage.remotePosition.value.rawValue,
            "nightscoutPosition": storage.nightscoutPosition.value.rawValue,
        ]
    }

    /// Create graph settings group
    private func createGraphSettings(_ storage: Storage) -> [String: Any] {
        return [
            "display": [
                "showDots": storage.showDots.value,
                "showLines": storage.showLines.value,
                "showValues": storage.showValues.value,
                "showAbsorption": storage.showAbsorption.value,
                "showDIALines": storage.showDIALines.value,
                "show30MinLine": storage.show30MinLine.value,
                "show90MinLine": storage.show90MinLine.value,
                "showMidnightLines": storage.showMidnightLines.value,
                "smallGraphTreatments": storage.smallGraphTreatments.value,
            ],
            "scaling": [
                "smallGraphHeight": storage.smallGraphHeight.value,
                "predictionToLoad": storage.predictionToLoad.value,
                "minBasalScale": storage.minBasalScale.value,
                "minBGScale": storage.minBGScale.value,
                "lowLine": storage.lowLine.value,
                "highLine": storage.highLine.value,
                "downloadDays": storage.downloadDays.value,
                "chartScaleX": storage.chartScaleX.value,
            ],
        ]
    }

    /// Create calendar settings group
    private func createCalendarSettings(_ storage: Storage) -> [String: Any] {
        return [
            "writeCalendarEvent": storage.writeCalendarEvent.value,
            "calendarIdentifier": storage.calendarIdentifier.value,
            "watchLine1": storage.watchLine1.value,
            "watchLine2": storage.watchLine2.value,
        ]
    }

    /// Create Dexcom Share settings group
    private func createDexcomShareSettings(_ storage: Storage) -> [String: Any] {
        return [
            "shareUserName": storage.shareUserName.value,
            "sharePassword": storage.sharePassword.value,
            "shareServer": storage.shareServer.value,
        ]
    }

    /// Create advanced settings group
    private func createAdvancedSettings(_ storage: Storage) -> [String: Any] {
        return [
            "download": [
                "downloadTreatments": storage.downloadTreatments.value,
                "downloadPrediction": storage.downloadPrediction.value,
                "bgUpdateDelay": storage.bgUpdateDelay.value,
            ],
            "graphing": [
                "graphOtherTreatments": storage.graphOtherTreatments.value,
                "graphBasal": storage.graphBasal.value,
                "graphBolus": storage.graphBolus.value,
                "graphCarbs": storage.graphCarbs.value,
            ],
            "speech": [
                "speakBG": storage.speakBG.value,
                "speakBGAlways": storage.speakBGAlways.value,
                "speakLowBG": storage.speakLowBG.value,
                "speakProactiveLowBG": storage.speakProactiveLowBG.value,
                "speakFastDropDelta": storage.speakFastDropDelta.value,
                "speakLowBGLimit": storage.speakLowBGLimit.value,
                "speakHighBGLimit": storage.speakHighBGLimit.value,
                "speakHighBG": storage.speakHighBG.value,
                "speakLanguage": storage.speakLanguage.value,
            ],
            "contact": [
                "contactTrend": storage.contactTrend.value.rawValue,
                "contactDelta": storage.contactDelta.value.rawValue,
                "contactEnabled": storage.contactEnabled.value,
                "contactBackgroundColor": storage.contactBackgroundColor.value,
                "contactTextColor": storage.contactTextColor.value,
            ],
            "insertTimes": [
                "cageInsertTime": storage.cageInsertTime.value,
                "sageInsertTime": storage.sageInsertTime.value,
            ],
        ]
    }

    /// Create alarm settings group
    private func createAlarmSettings(_ storage: Storage) -> [String: Any] {
        return [
            "alarms": try? encodeAlarms(storage.alarms.value),
            "configuration": try? encodeAlarmConfiguration(storage.alarmConfiguration.value),
        ]
    }

    /// Create version info group
    private func createVersionInfo(_ storage: Storage) -> [String: Any] {
        return [
            "cachedForVersion": storage.cachedForVersion.value,
            "latestVersion": storage.latestVersion.value,
            "latestVersionChecked": storage.latestVersionChecked.value?.timeIntervalSince1970,
            "currentVersionBlackListed": storage.currentVersionBlackListed.value,
            "lastBlacklistNotificationShown": storage.lastBlacklistNotificationShown.value?.timeIntervalSince1970,
            "lastVersionUpdateNotificationShown": storage.lastVersionUpdateNotificationShown.value?.timeIntervalSince1970,
            "lastExpirationNotificationShown": storage.lastExpirationNotificationShown.value?.timeIntervalSince1970,
        ]
    }

    // MARK: - Settings Group Restore Methods

    /// Restore connection settings
    private func restoreConnectionSettings(_ storage: Storage, from data: [String: Any]) {
        if let value = data["url"] as? String {
            storage.url.value = value
        }
        if let value = data["token"] as? String {
            storage.token.value = value
        }
        if let value = data["device"] as? String {
            storage.device.value = value
        }
        if let value = data["units"] as? String {
            storage.units.value = value
        }
    }

    /// Restore remote settings
    private func restoreRemoteSettings(_ storage: Storage, from data: [String: Any]) {
        if let value = data["remoteType"] as? String, let remoteType = RemoteType(rawValue: value) {
            storage.remoteType.value = remoteType
        }
        if let value = data["deviceToken"] as? String {
            storage.deviceToken.value = value
        }
        if let value = data["sharedSecret"] as? String {
            storage.sharedSecret.value = value
        }
        if let value = data["productionEnvironment"] as? Bool {
            storage.productionEnvironment.value = value
        }
        if let value = data["apnsKey"] as? String {
            storage.apnsKey.value = value
        }
        if let value = data["teamId"] as? String {
            storage.teamId.value = value
        }
        if let value = data["keyId"] as? String {
            storage.keyId.value = value
        }
        if let value = data["bundleId"] as? String {
            storage.bundleId.value = value
        }
        if let value = data["user"] as? String {
            storage.user.value = value
        }
        if let value = data["loopAPNSQrCodeURL"] as? String {
            storage.loopAPNSQrCodeURL.value = value
        }
    }

    /// Restore core app settings
    private func restoreCoreAppSettings(_ storage: Storage, from data: [String: Any]) {
        if let maxBolusData = data["maxBolus"] as? [String: Any],
           let maxBolus = try? decodeHKQuantity(maxBolusData)
        {
            storage.maxBolus.value = maxBolus
        }
        if let maxCarbsData = data["maxCarbs"] as? [String: Any],
           let maxCarbs = try? decodeHKQuantity(maxCarbsData)
        {
            storage.maxCarbs.value = maxCarbs
        }
        if let maxProteinData = data["maxProtein"] as? [String: Any],
           let maxProtein = try? decodeHKQuantity(maxProteinData)
        {
            storage.maxProtein.value = maxProtein
        }
        if let maxFatData = data["maxFat"] as? [String: Any],
           let maxFat = try? decodeHKQuantity(maxFatData)
        {
            storage.maxFat.value = maxFat
        }
        if let value = data["mealWithBolus"] as? Bool {
            storage.mealWithBolus.value = value
        }
        if let value = data["mealWithFatProtein"] as? Bool {
            storage.mealWithFatProtein.value = value
        }
        if let value = data["backgroundRefreshType"] as? String, let refreshType = BackgroundRefreshType(rawValue: value) {
            storage.backgroundRefreshType.value = refreshType
        }
        if let value = data["debugLogLevel"] as? Bool {
            storage.debugLogLevel.value = value
        }
    }

    /// Restore UI settings
    private func restoreUISettings(_ storage: Storage, from data: [String: Any]) {
        if let value = data["appBadge"] as? Bool {
            storage.appBadge.value = value
        }
        if let value = data["colorBGText"] as? Bool {
            storage.colorBGText.value = value
        }
        if let value = data["forceDarkMode"] as? Bool {
            storage.forceDarkMode.value = value
        }
        if let value = data["showStats"] as? Bool {
            storage.showStats.value = value
        }
        if let value = data["useIFCC"] as? Bool {
            storage.useIFCC.value = value
        }
        if let value = data["showSmallGraph"] as? Bool {
            storage.showSmallGraph.value = value
        }
        if let value = data["screenlockSwitchState"] as? Bool {
            storage.screenlockSwitchState.value = value
        }
        if let value = data["showDisplayName"] as? Bool {
            storage.showDisplayName.value = value
        }
        if let value = data["forcePortraitMode"] as? Bool {
            storage.forcePortraitMode.value = value
        }
        if let value = data["snoozerEmoji"] as? Bool {
            storage.snoozerEmoji.value = value
        }
        if let value = data["hideInfoTable"] as? Bool {
            storage.hideInfoTable.value = value
        }
        if let value = data["persistentNotification"] as? Bool {
            storage.persistentNotification.value = value
        }
        if let value = data["alarmsPosition"] as? String, let position = TabPosition(rawValue: value) {
            storage.alarmsPosition.value = position
        }
        if let value = data["remotePosition"] as? String, let position = TabPosition(rawValue: value) {
            storage.remotePosition.value = position
        }
        if let value = data["nightscoutPosition"] as? String, let position = TabPosition(rawValue: value) {
            storage.nightscoutPosition.value = position
        }
    }

    /// Restore graph settings
    private func restoreGraphSettings(_ storage: Storage, from data: [String: Any]) {
        if let display = data["display"] as? [String: Any] {
            if let value = display["showDots"] as? Bool {
                storage.showDots.value = value
            }
            if let value = display["showLines"] as? Bool {
                storage.showLines.value = value
            }
            if let value = display["showValues"] as? Bool {
                storage.showValues.value = value
            }
            if let value = display["showAbsorption"] as? Bool {
                storage.showAbsorption.value = value
            }
            if let value = display["showDIALines"] as? Bool {
                storage.showDIALines.value = value
            }
            if let value = display["show30MinLine"] as? Bool {
                storage.show30MinLine.value = value
            }
            if let value = display["show90MinLine"] as? Bool {
                storage.show90MinLine.value = value
            }
            if let value = display["showMidnightLines"] as? Bool {
                storage.showMidnightLines.value = value
            }
            if let value = display["smallGraphTreatments"] as? Bool {
                storage.smallGraphTreatments.value = value
            }
        }

        if let scaling = data["scaling"] as? [String: Any] {
            if let value = scaling["smallGraphHeight"] as? Int {
                storage.smallGraphHeight.value = value
            }
            if let value = scaling["predictionToLoad"] as? Double {
                storage.predictionToLoad.value = value
            }
            if let value = scaling["minBasalScale"] as? Double {
                storage.minBasalScale.value = value
            }
            if let value = scaling["minBGScale"] as? Double {
                storage.minBGScale.value = value
            }
            if let value = scaling["lowLine"] as? Double {
                storage.lowLine.value = value
            }
            if let value = scaling["highLine"] as? Double {
                storage.highLine.value = value
            }
            if let value = scaling["downloadDays"] as? Int {
                storage.downloadDays.value = value
            }
            if let value = scaling["chartScaleX"] as? Double {
                storage.chartScaleX.value = value
            }
        }
    }

    /// Restore calendar settings
    private func restoreCalendarSettings(_ storage: Storage, from data: [String: Any]) {
        if let value = data["writeCalendarEvent"] as? Bool {
            storage.writeCalendarEvent.value = value
        }
        if let value = data["calendarIdentifier"] as? String {
            storage.calendarIdentifier.value = value
        }
        if let value = data["watchLine1"] as? String {
            storage.watchLine1.value = value
        }
        if let value = data["watchLine2"] as? String {
            storage.watchLine2.value = value
        }
    }

    /// Restore Dexcom Share settings
    private func restoreDexcomShareSettings(_ storage: Storage, from data: [String: Any]) {
        if let value = data["shareUserName"] as? String {
            storage.shareUserName.value = value
        }
        if let value = data["sharePassword"] as? String {
            storage.sharePassword.value = value
        }
        if let value = data["shareServer"] as? String {
            storage.shareServer.value = value
        }
    }

    /// Restore advanced settings
    private func restoreAdvancedSettings(_ storage: Storage, from data: [String: Any]) {
        if let download = data["download"] as? [String: Any] {
            if let value = download["downloadTreatments"] as? Bool {
                storage.downloadTreatments.value = value
            }
            if let value = download["downloadPrediction"] as? Bool {
                storage.downloadPrediction.value = value
            }
            if let value = download["bgUpdateDelay"] as? Int {
                storage.bgUpdateDelay.value = value
            }
        }

        if let graphing = data["graphing"] as? [String: Any] {
            if let value = graphing["graphOtherTreatments"] as? Bool {
                storage.graphOtherTreatments.value = value
            }
            if let value = graphing["graphBasal"] as? Bool {
                storage.graphBasal.value = value
            }
            if let value = graphing["graphBolus"] as? Bool {
                storage.graphBolus.value = value
            }
            if let value = graphing["graphCarbs"] as? Bool {
                storage.graphCarbs.value = value
            }
        }

        if let speech = data["speech"] as? [String: Any] {
            if let value = speech["speakBG"] as? Bool {
                storage.speakBG.value = value
            }
            if let value = speech["speakBGAlways"] as? Bool {
                storage.speakBGAlways.value = value
            }
            if let value = speech["speakLowBG"] as? Bool {
                storage.speakLowBG.value = value
            }
            if let value = speech["speakProactiveLowBG"] as? Bool {
                storage.speakProactiveLowBG.value = value
            }
            if let value = speech["speakFastDropDelta"] as? Double {
                storage.speakFastDropDelta.value = value
            }
            if let value = speech["speakLowBGLimit"] as? Double {
                storage.speakLowBGLimit.value = value
            }
            if let value = speech["speakHighBGLimit"] as? Double {
                storage.speakHighBGLimit.value = value
            }
            if let value = speech["speakHighBG"] as? Bool {
                storage.speakHighBG.value = value
            }
            if let value = speech["speakLanguage"] as? String {
                storage.speakLanguage.value = value
            }
        }

        if let contact = data["contact"] as? [String: Any] {
            if let value = contact["contactTrend"] as? String, let trend = ContactIncludeOption(rawValue: value) {
                storage.contactTrend.value = trend
            }
            if let value = contact["contactDelta"] as? String, let delta = ContactIncludeOption(rawValue: value) {
                storage.contactDelta.value = delta
            }
            if let value = contact["contactEnabled"] as? Bool {
                storage.contactEnabled.value = value
            }
            if let value = contact["contactBackgroundColor"] as? String {
                storage.contactBackgroundColor.value = value
            }
            if let value = contact["contactTextColor"] as? String {
                storage.contactTextColor.value = value
            }
        }

        if let insertTimes = data["insertTimes"] as? [String: Any] {
            if let value = insertTimes["cageInsertTime"] as? TimeInterval {
                storage.cageInsertTime.value = value
            }
            if let value = insertTimes["sageInsertTime"] as? TimeInterval {
                storage.sageInsertTime.value = value
            }
        }
    }

    /// Restore alarm settings
    private func restoreAlarmSettings(_ storage: Storage, from data: [String: Any]) {
        if let alarmsData = data["alarms"] as? [[String: Any]],
           let alarms = try? decodeAlarms(alarmsData)
        {
            storage.alarms.value = alarms
        }
        if let configData = data["configuration"] as? [String: Any],
           let configuration = try? decodeAlarmConfiguration(configData)
        {
            storage.alarmConfiguration.value = configuration
        }
    }

    /// Restore version info
    private func restoreVersionInfo(_ storage: Storage, from data: [String: Any]) {
        if let value = data["cachedForVersion"] as? String {
            storage.cachedForVersion.value = value
        }
        if let value = data["latestVersion"] as? String {
            storage.latestVersion.value = value
        }
        if let value = data["latestVersionChecked"] as? TimeInterval {
            storage.latestVersionChecked.value = Date(timeIntervalSince1970: value)
        }
        if let value = data["currentVersionBlackListed"] as? Bool {
            storage.currentVersionBlackListed.value = value
        }
        if let value = data["lastBlacklistNotificationShown"] as? TimeInterval {
            storage.lastBlacklistNotificationShown.value = Date(timeIntervalSince1970: value)
        }
        if let value = data["lastVersionUpdateNotificationShown"] as? TimeInterval {
            storage.lastVersionUpdateNotificationShown.value = Date(timeIntervalSince1970: value)
        }
        if let value = data["lastExpirationNotificationShown"] as? TimeInterval {
            storage.lastExpirationNotificationShown.value = Date(timeIntervalSince1970: value)
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
            backup["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
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

    /// Restore Storage from backup data (organized structure)
    private func restoreStorageFromBackup(_ data: Data) throws {
        guard let backup = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "ICloudStorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid backup format"])
        }

        let storage = Storage.shared

        // Restore connection settings
        if let connection = backup["connection"] as? [String: Any] {
            restoreConnectionSettings(storage, from: connection)
        }

        // Restore remote settings
        if let remote = backup["remote"] as? [String: Any] {
            restoreRemoteSettings(storage, from: remote)
        }

        // Restore core app settings
        if let core = backup["core"] as? [String: Any] {
            restoreCoreAppSettings(storage, from: core)
        }

        // Restore UI settings
        if let ui = backup["ui"] as? [String: Any] {
            restoreUISettings(storage, from: ui)
        }

        // Restore graph settings
        if let graph = backup["graph"] as? [String: Any] {
            restoreGraphSettings(storage, from: graph)
        }

        // Restore calendar settings
        if let calendar = backup["calendar"] as? [String: Any] {
            restoreCalendarSettings(storage, from: calendar)
        }

        // Restore Dexcom Share settings
        if let dexcomShare = backup["dexcomShare"] as? [String: Any] {
            restoreDexcomShareSettings(storage, from: dexcomShare)
        }

        // Restore advanced settings
        if let advanced = backup["advanced"] as? [String: Any] {
            restoreAdvancedSettings(storage, from: advanced)
        }

        // Restore alarm settings
        if let alarms = backup["alarms"] as? [String: Any] {
            restoreAlarmSettings(storage, from: alarms)
        }

        // Restore version info
        if let version = backup["version"] as? [String: Any] {
            restoreVersionInfo(storage, from: version)
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

    /// Create organized JSON object for external use
    func createOrganizedBackupJSON() -> [String: Any]? {
        do {
            let storage = Storage.shared

            var backup: [String: Any] = [:]

            // Connection Settings
            backup["connection"] = createConnectionSettings(storage)

            // Remote Settings
            backup["remote"] = createRemoteSettings(storage)

            // Core App Settings
            backup["core"] = createCoreAppSettings(storage)

            // UI Settings
            backup["ui"] = createUISettings(storage)

            // Graph Settings
            backup["graph"] = createGraphSettings(storage)

            // Calendar Settings
            backup["calendar"] = createCalendarSettings(storage)

            // Dexcom Share Settings
            backup["dexcomShare"] = createDexcomShareSettings(storage)

            // Advanced Settings
            backup["advanced"] = createAdvancedSettings(storage)

            // Alarm Settings
            backup["alarms"] = createAlarmSettings(storage)

            // Version Info
            backup["version"] = createVersionInfo(storage)

            // Add backup metadata
            backup["backupTimestamp"] = Date().timeIntervalSince1970

            return backup
        } catch {
            LogManager.shared.log(category: .general, message: "Failed to create organized backup JSON: \(error)")
            return nil
        }
    }

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

        let version = backup["appVersion"] as? String

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
