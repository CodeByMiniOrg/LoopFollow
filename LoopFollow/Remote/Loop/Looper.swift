// LoopFollow
// Looper.swift
// Created by Daniel Mini Johansson.

import Foundation

struct Looper: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let nightscoutCredentials: NightscoutCredentials
    let lastSelectedDate: Date
    
    init(identifier: UUID, name: String, nightscoutCredentials: NightscoutCredentials, lastSelectedDate: Date) {
        self.id = identifier
        self.name = name
        self.nightscoutCredentials = nightscoutCredentials
        self.lastSelectedDate = lastSelectedDate
    }
}

struct NightscoutCredentials: Codable, Hashable {
    let url: URL
    let secretKey: String
    let otpURL: String
    
    init(url: URL, secretKey: String, otpURL: String) {
        self.url = url
        self.secretKey = secretKey
        self.otpURL = otpURL
    }
} 