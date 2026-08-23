//
//   ScreenTimeApp.swift
//   ScreenBuddy
//
//   @main entry point — owns the single root NavigationStack for the whole app.
//

import SwiftUI
import AppIntents
import UserNotifications

@main
struct ScreenTimeApp: App {

    @StateObject private var store = ActivityStore.shared

    init() {
        // Validate Core ML model input schema at launch
        ChildRiskPredictor.validateModelSchema()
        
        // Force the system to update and register Siri commands and shortcuts at launch
        ELEVENShortcutsProvider.updateAppShortcutParameters()
        
        // Enable immediate in-app notification reception and presentation
        UNUserNotificationCenter.current().delegate = LocalNotificationManager.shared
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(store)
        }
    }
}

// MARK: - Root container
struct AppRootView: View {
    @EnvironmentObject private var store: ActivityStore

    @Environment(\.scenePhase) private var scenePhase
    
    @State private var navigationPath = NavigationPath()
    
    @AppStorage("isParentMode") private var isParentMode = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            SplashView()
                .toolbar(.hidden, for: .navigationBar)
        }
        .environmentObject(store)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                isParentMode = false            
                navigationPath = NavigationPath()
            }
        }
    }
}

// MARK: - Previews

#Preview {
    AppRootView()
        .environmentObject(ActivityStore.shared)
}
