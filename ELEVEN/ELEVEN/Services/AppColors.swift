//
//  AppColors.swift
//  ScreenBuddy
//
//  Centralised colour tokens — prevents duplicate-symbol build errors.
//  All other files should NOT declare their own Color extensions or Color(hex:).
//

import SwiftUI

// MARK: - Hex initialiser (used by ToDoView & RewardView)
extension Color {
    init(hex: String) {
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb & 0xFF0000) >> 16) / 255,
            green: Double((rgb & 0x00FF00) >>  8) / 255,
            blue:  Double( rgb & 0x0000FF)         / 255
        )
    }
}

// MARK: - App-wide named tokens
extension Color {

    // Splash screen
    static let videoBG = Color(red: 0.925, green: 0.925, blue: 0.925)

    // Parent dashboard (Pdashboard)
    static let customOrange = Color(red: 1.0,  green: 0.48, blue: 0.36)
    static let customBlue   = Color(red: 0.52, green: 0.68, blue: 0.85)
    static let customGray   = Color(red: 0.85, green: 0.85, blue: 0.85)
    static let textDarkGray = Color(red: 0.32, green: 0.32, blue: 0.34)

    // AI / onboarding / recommendations
    // Note: `brand` and `customBlue` share the same value intentionally.
    static let brand          = Color(red: 0.52, green: 0.68, blue: 0.85)
    static let appBG          = Color(red: 0.96, green: 0.96, blue: 0.97)
    static let cardBlue       = Color(red: 0.88, green: 0.92, blue: 0.97)
    static let cardRect       = Color(red: 0.93, green: 0.94, blue: 0.96)
    static let fieldGray      = Color(red: 0.92, green: 0.92, blue: 0.93)
    static let plusBlue       = Color(red: 0.62, green: 0.75, blue: 0.88)
    static let chipUnselected = Color(red: 0.90, green: 0.90, blue: 0.91)
    static let chipSelected   = Color(red: 0.75, green: 0.85, blue: 0.95)

    // Parent-control PIN screen
    static let codeDot = Color(red: 0.667, green: 0.686, blue: 0.745)
}
