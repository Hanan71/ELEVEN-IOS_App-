//
//  AppShortcuts.swift
//  ELEVEN
//

import Foundation
import AppIntents

// 1. Define the Intent conforming to AppIntent
struct CheckChildStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Child Status"

   
    static var openAppWhenRun: Bool = true

    // 2. Perform function to handle the logic
    func perform() async throws -> some IntentResult {
        print("Siri Intent executed successfully!")
        return .result()
    }
}

// 3. Expose to Siri & Shortcuts
struct ELEVENShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckChildStatusIntent(),
            phrases: [
                "Check child status in \(.applicationName)",
                "Get screen time in \(.applicationName)"
            ],
            shortTitle: "Screen Time Status",
            systemImageName: "shield.fill"
        )
    }
}
