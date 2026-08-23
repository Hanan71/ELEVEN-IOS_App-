//
//   ActivityStore.swift
//   ScreenBuddy
//
//   Single source-of-truth for tasks and rewards, persisted in UserDefaults.
//   Both KidsDashboardView (child) and Dashboard (parent) read/write from
//   this store — any change is reflected immediately in both views.
//

import SwiftUI
import Combine

// MARK: - Models

struct SharedTask: Identifiable, Codable, Equatable {
    var id                 = UUID()
    var icon               : String
    var title              : String
    var points             : Int
    var isPendingApproval  : Bool = false
    var isCompleted        : Bool = false
}

struct SharedReward: Identifiable, Codable, Equatable {
    var id        = UUID()
    var icon      : String
    var title     : String
    var cost      : Int       // points required to unlock
    var isClaimed : Bool = false
}

// MARK: - Store

final class ActivityStore: ObservableObject {

    static let shared = ActivityStore()

    @Published var tasks       : [SharedTask]   = []
    @Published var rewards     : [SharedReward] = []
    @Published var totalPoints : Int = 0

    private let tasksKey   = "sb.tasks"
    private let rewardsKey = "sb.rewards"
    private let pointsKey  = "sb.totalPoints"

    // MARK: Lifecycle
    init() {
        totalPoints = UserDefaults.standard.integer(forKey: pointsKey)
        load()
        if tasks.isEmpty && rewards.isEmpty {
            seed()
        }
    }

    // MARK: - Task Actions

    func submitTaskForApproval(id: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].isPendingApproval = true
        save()
    }

    func completeTask(id: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        if !tasks[idx].isCompleted {
            totalPoints += tasks[idx].points
            tasks[idx].isPendingApproval = false
            tasks[idx].isCompleted = true
            save()
        }
    }

    func rejectTask(id: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].isPendingApproval = false
        tasks[idx].isCompleted = false
        save()
    }

    func deleteTask(id: UUID) {
        tasks.removeAll { $0.id == id }
        save()
    }

    func addTask(_ task: SharedTask) {
        tasks.append(task)
        save()
    }

    // MARK: - Reward Actions

    /// Returns true when the child has enough points to unlock this reward.
    func isUnlocked(_ reward: SharedReward) -> Bool {
        totalPoints >= reward.cost
    }

    /// Child claims a reward (deducts points safely and marks as claimed).
    func claimReward(id: UUID) {
        guard let idx = rewards.firstIndex(where: { $0.id == id }) else { return }
        // إذا لم تكن مطالبة مسبقاً ولديه رصيد كافٍ يتم الخصم والتعيين
        if !rewards[idx].isClaimed {
            if totalPoints >= rewards[idx].cost {
                totalPoints -= rewards[idx].cost
            }
            rewards[idx].isClaimed = true
            save()
        }
    }

    /// Parent fulfils and removes a claimed reward.
    func fulfillReward(id: UUID) {
        rewards.removeAll { $0.id == id }
        save()
    }

    func addReward(_ reward: SharedReward) {
        rewards.append(reward)
        save()
    }

    // MARK: - Reset & Debug Helpers

    func resetAllData() {
        UserDefaults.standard.removeObject(forKey: tasksKey)
        UserDefaults.standard.removeObject(forKey: rewardsKey)
        UserDefaults.standard.removeObject(forKey: pointsKey)
        
        totalPoints = 0
        seed()
    }

    // MARK: - Persistence

    private func save() {
        UserDefaults.standard.set(totalPoints, forKey: pointsKey)
        if let t = try? JSONEncoder().encode(tasks)   { UserDefaults.standard.set(t, forKey: tasksKey) }
        if let r = try? JSONEncoder().encode(rewards) { UserDefaults.standard.set(r, forKey: rewardsKey) }
    }

    private func load() {
        if let data    = UserDefaults.standard.data(forKey: tasksKey),
           let decoded = try? JSONDecoder().decode([SharedTask].self, from: data)   { tasks   = decoded }
        if let data    = UserDefaults.standard.data(forKey: rewardsKey),
           let decoded = try? JSONDecoder().decode([SharedReward].self, from: data) { rewards = decoded }
    }

    /// Pre-populate on first launch so the app isn't empty.
    private func seed() {
        tasks = [
            SharedTask(icon: "📐", title: "Math HW",    points: 10),
            SharedTask(icon: "🎨", title: "Color Book", points: 5),
            SharedTask(icon: "📖", title: "Read 20 Mins", points: 15),
            SharedTask(icon: "🛏️", title: "Tidy Room", points: 10),
            SharedTask(icon: "💧", title: "Water Plants", points: 5),
            SharedTask(icon: "🏃‍♂️", title: "Outdoor Play", points: 20)
        ]
        rewards = [
            SharedReward(icon: "🍦", title: "Get Ice Cream", cost: 5),
            SharedReward(icon: "🚂", title: "Buy Lego",      cost: 50),
            SharedReward(icon: "🍿", title: "Movie Night", cost: 25),
            SharedReward(icon: "🍕", title: "Pizza Treat", cost: 35),
            SharedReward(icon: "🎮", title: "+30m Game Time", cost: 40),
            SharedReward(icon: "🎡", title: "Park Outing", cost: 80)
        ]
        save()
    }
}
