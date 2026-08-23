//
//   Pdashboard.swift
//   ScreenBuddy
//
//   Parent-facing dashboard. Reads tasks and rewards from ActivityStore
//   (shared with KidsDashboardView) so both views stay in sync.
//

import SwiftUI

// MARK: - Parent Dashboard

struct Dashboard: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var store: ActivityStore
    
    @AppStorage("isParentLoggedIn") private var isParentLoggedIn = true
    @AppStorage("childName") private var childName: String = ""
    @AppStorage("hasSeenChildOnboarding") private var hasSeenChildOnboarding = false

    @State private var showAddToDo = false
    @State private var showAddReward = false
    @State private var showAIFeedback = false

    // ✅ التعديل يفتح صفحة التعديل الكاملة (To Do / Reward)
    @State private var editTask: SharedTask? = nil
    @State private var editReward: SharedReward? = nil

    private let starBgColor = Color(red: 134/255, green: 174/255, blue: 217/255)
    private var displayName: String { childName.isEmpty ? "your child" : childName }

    private var activeTasks: [SharedTask] {
        store.tasks.filter { !$0.isCompleted }
    }

    // ✅ المهام المعلقة تطلع فوق
    private var sortedPendingTasks: [SharedTask] {
        activeTasks.sorted { lhs, rhs in
            if lhs.isPendingApproval != rhs.isPendingApproval {
                return lhs.isPendingApproval
            }
            return false
        }
    }

    // ✅ المكافآت المطلوبة تطلع فوق
    private var sortedPendingRewards: [SharedReward] {
        store.rewards.sorted { lhs, rhs in
            if lhs.isClaimed != rhs.isClaimed {
                return lhs.isClaimed
            }
            return false
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {

                // Header
                HStack {
                    Button(action: {
                        isParentLoggedIn = false
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.black)
                    }
                    Spacer()
                    Text("Dashboard")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.black)
                    Spacer()
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22))
                        .opacity(0)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // ── Points Summary ──
                HStack(spacing: 10) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(starBgColor)
                        .clipShape(Circle())
                        .shadow(color: starBgColor.opacity(0.3), radius: 4, x: 0, y: 2)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(displayName)'s points")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)
                        Text("\(store.totalPoints) pts")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.black)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: store.totalPoints)
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 2)

                // ── To Do section ──
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Text("📝").font(.title2)
                        Text("To Do")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.black)
                    }

                    if activeTasks.isEmpty {
                        HStack(spacing: 12) {
                            Text("🎉").font(.system(size: 24))
                            Text("All tasks completed!")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(sortedPendingTasks) { task in
                            SwipeToReveal(onEdit: {
                                editTask = task
                            }, onDelete: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    store.deleteTask(id: task.id)
                                }
                            }) {
                                ParentTaskRow(
                                    icon: task.icon, title: task.title,
                                    points: "+\(task.points)pts",
                                    subBadge: task.isPendingApproval ? "⏳ Pending your approval" : nil,
                                    isPending: task.isPendingApproval,
                                    accentColor: Color(red: 0.98, green: 0.55, blue: 0.5),
                                    badgeBorder: Color(red: 1.0, green: 0.70, blue: 0.60),
                                    showComplete: task.isPendingApproval,
                                    showDelete: task.isPendingApproval
                                ) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        store.completeTask(id: task.id)
                                    }
                                } onDelete: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        store.rejectTask(id: task.id)
                                    }
                                }
                            }
                        }
                    }

                    AddActivityButton(color: Color(red: 0.98, green: 0.45, blue: 0.38)) {
                        showAddToDo = true
                    }
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(28)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.gray.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)

                // ── Rewards section ──
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Text("🏆").font(.title2)
                        Text("Rewards")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.black)
                    }

                    if store.rewards.isEmpty {
                        Text("No rewards added yet.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.gray)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(sortedPendingRewards) { reward in
                            SwipeToReveal(onEdit: {
                                editReward = reward
                            }, onDelete: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    store.fulfillReward(id: reward.id)
                                }
                            }) {
                                ParentTaskRow(
                                    icon: reward.icon, title: reward.title,
                                    points: "+\(reward.cost)pts",
                                    subBadge: reward.isClaimed ? "⏳ Your child wants this!" : nil,
                                    isPending: reward.isClaimed,
                                    accentColor: Color(red: 0.72, green: 0.82, blue: 0.93),
                                    badgeBorder: Color(red: 0.62, green: 0.76, blue: 0.94),
                                    showComplete: reward.isClaimed,
                                    showDelete: false
                                ) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        store.fulfillReward(id: reward.id)
                                    }
                                } onDelete: {}
                            }
                        }
                    }

                    AddActivityButton(color: Color(red: 0.42, green: 0.62, blue: 0.88)) {
                        showAddReward = true
                    }
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(28)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.gray.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)

                // AI Feedback button
                Button(action: { showAIFeedback = true }) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color(red: 0.25, green: 0.35, blue: 0.45))
                        
                        Spacer()
                        
                        Text("AI Recommendations")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color(red: 0.25, green: 0.35, blue: 0.45))
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color(red: 0.25, green: 0.35, blue: 0.45))
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 22)
                    .background(Color(red: 0.73, green: 0.82, blue: 0.91))
                    .cornerRadius(28)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(Color(red: 0.97, green: 0.97, blue: 0.97).ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                showAddToDo = false
                showAddReward = false
                showAIFeedback = false
                editTask = nil
                editReward = nil
                isParentLoggedIn = false
                dismiss()
            }
        }
        .sheet(isPresented: $showAddToDo) {
            ToDoActivityView()
        }
        .sheet(isPresented: $showAddReward) {
            RewardView()
        }
        .sheet(item: $editTask) { task in
            ToDoActivityView(taskToEdit: task)
        }
        .sheet(item: $editReward) { reward in
            RewardView(rewardToEdit: reward)
        }
        .fullScreenCover(isPresented: $showAIFeedback) {
            if hasSeenChildOnboarding, let profile = ProfileStore.load() {
                RecommendationsView(profile: profile)
            } else {
                ChildOnboardingView()
            }
        }
        .refreshable {
            try? await Task.sleep(nanoseconds: 600_000_000)
        }
    }
}

// MARK: - SwipeToReveal

struct SwipeToReveal<RowContent: View>: View {
    var onEdit: () -> Void
    var onDelete: () -> Void
    @ViewBuilder var content: RowContent

    @State private var offsetX: CGFloat = 0
    @GestureState private var dragTranslation: CGFloat = 0

    private let actionWidth: CGFloat = 136

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                Button(action: {
                    onEdit()
                    reset()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("Edit").font(.caption2.bold())
                    }
                    .frame(width: 68)
                    .frame(maxHeight: .infinity)
                    .foregroundColor(Color(red: 0.15, green: 0.35, blue: 0.65))
                    .background(Color(red: 0.75, green: 0.87, blue: 0.98))
                }
                
                Button(action: onDelete) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Delete").font(.caption2.bold())
                    }
                    .frame(width: 68)
                    .frame(maxHeight: .infinity)
                    .foregroundColor(Color(red: 0.99, green: 0.52, blue: 0.41))
                    .background(Color(red: 0.99, green: 0.52, blue: 0.41).opacity(0.15))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))

            content
                .offset(x: currentOffset)
                .gesture(
                    DragGesture()
                        .updating($dragTranslation) { value, state, _ in
                            state = max(0, value.translation.width)
                        }
                        .onEnded { value in
                            let proposed = offsetX + value.translation.width
                            if proposed > actionWidth / 2 {
                                withAnimation(.easeOut(duration: 0.2)) { offsetX = actionWidth }
                            } else {
                                withAnimation(.easeOut(duration: 0.2)) { offsetX = 0 }
                            }
                        }
                )
        }
    }

    private var currentOffset: CGFloat {
        min(actionWidth, max(0, offsetX + dragTranslation))
    }

    private func reset() {
        withAnimation(.easeOut(duration: 0.2)) { offsetX = 0 }
    }
}

// MARK: - ParentTaskRow

struct ParentTaskRow: View {
    let icon        : String
    let title       : String
    let points      : String
    let subBadge    : String?
    var isPending   : Bool = false
    let accentColor : Color
    var badgeBorder : Color = Color.gray.opacity(0.3)
    var showComplete: Bool = true
    var showDelete  : Bool = true
    let onComplete  : () -> Void
    let onDelete    : () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                if showComplete {
                    Button(action: onComplete) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.green.opacity(0.8))
                            .frame(width: 36, height: 36)
                            .background(Color.green.opacity(0.18))
                            .clipShape(Circle())
                    }
                }

                if showDelete {
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 0.99, green: 0.52, blue: 0.41))
                            .frame(width: 36, height: 36)
                            .background(Color(red: 0.99, green: 0.52, blue: 0.41).opacity(0.15))
                            .clipShape(Circle())
                    }
                }

                Text((icon.isEmpty ? "" : icon + " ") + title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(white: 0.2))
                    .lineLimit(1)

                Spacer()

                Text(points)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(white: 0.3))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(accentColor.opacity(0.4))
                    .cornerRadius(12)
            }

            if let badge = subBadge {
                Text(badge)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(white: 0.35))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(badgeBorder, lineWidth: 1.5)
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(22)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
    }
}

// MARK: - AddActivityButton

struct AddActivityButton: View {
    let color: Color
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                Text("Add Activity")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.08))
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(color.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
            )
        }
    }
}

// MARK: - Preview

#Preview {
    Dashboard()
        .environmentObject(ActivityStore.shared)
}
