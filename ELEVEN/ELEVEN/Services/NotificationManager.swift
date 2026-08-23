//
//  NotificationManager.swift
//  ELEVEN
//

import Foundation
import UserNotifications

class LocalNotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = LocalNotificationManager()

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    static func requestPermission() {
       
        _ = LocalNotificationManager.shared

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("Notification permission granted.")
                    sendImmediateWelcomeNotification()
                } else if let error = error {
                    print("Notification permission error: \(error.localizedDescription)")
                }
            }
        }
    }

    private static func sendImmediateWelcomeNotification() {
        let center = UNUserNotificationCenter.current()
        center.delegate = LocalNotificationManager.shared

        let content = UNMutableNotificationContent()
        content.title = "🎉 Notifications Enabled!"
        content.body = "You will now receive smart reminders and tips to manage screen time effectively."
        content.sound = .default

      
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "immediate_welcome_notification_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Error presenting initial notification: \(error.localizedDescription)")
            } else {
                print("Welcome notification scheduled successfully.")
            }
        }
    }

    static func scheduleGeminiReminders(childName: String, activities: [InfoCard], tips: [InfoCard]) {
        let center = UNUserNotificationCenter.current()
        center.delegate = LocalNotificationManager.shared
        center.removeAllPendingNotificationRequests()

        var suggestions: [(title: String, body: String)] = []

        for activity in activities {
            let title = "\(activity.emoji) Time for an activity, \(childName)!"
            let body = "\(activity.title) - \(activity.detail)"
            suggestions.append((title: title, body: body))
        }

        for tip in tips {
            let title = "\(tip.emoji) Screen Time Tip"
            let body = tip.detail
            suggestions.append((title: title, body: body))
        }

        guard !suggestions.isEmpty else { return }

        let interval: TimeInterval = 60

        for (index, item) in suggestions.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default

            let triggerTime = interval * Double(index + 1)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: triggerTime, repeats: false)

            let request = UNNotificationRequest(
                identifier: "gemini_reminder_\(index)",
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error = error {
                    print("Error scheduling reminder: \(error.localizedDescription)")
                }
            }
        }
    }

    //  to make sure it is working and sending notifications (Foreground)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge, .list])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
}
