//
//  Ai_recommendations.swift
//  ELEVEN

import SwiftUI
import Combine

// MARK: - Shared accent color for boxes (#BADBFF)
private extension Color {
    static let accentBlue = Color(red: 224/255, green: 233/255, blue: 244/255) // #E0E9F4
}

// MARK: - Recommendations page

struct RecommendationsView: View {
    let profile: ChildProfile

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var activities: [InfoCard] = []
    @State private var tips: [InfoCard] = []
    @State private var isLoading = false
    @State private var usingAI = false
    @State private var errorMessage: String?
    @State private var modelNote: String?
    @State private var showChildOnboarding = false

    
    @State private var collapsedIDs: Set<UUID> = []

    private let service = AIRecommendationService()

    private var currentProfile: ChildProfile {
        ProfileStore.load() ?? profile
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                topBar

                Text("Based on \(currentProfile.name)'s interests, here's what we'd suggest.")
                    .font(.system(size: 16, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black.opacity(0.8))
                    .id(currentProfile.name)

                if let modelNote {
                    HStack(spacing: 8) {
                        Text("🧠")
                        Text("Ai-model: \(modelNote)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black.opacity(0.75))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.accentBlue))
                }

                if isLoading {
                    ProgressView("Thinking…")
                        .foregroundColor(.black)
                        .padding(.vertical, 40)
                } else {
                    if let errorMessage {
                        Text("AI error: \(errorMessage)")
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    activitiesSection
                    tipsSection
                    if !usingAI {
                        Text("Showing offline suggestions.")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                }

                refreshButton
            }
            .padding(24)
        }
        .background(Color.appBG.ignoresSafeArea())
        .task {
            loadRecommendations()
        }
        .onAppear {
            NotificationManager.requestPermission()
            loadRecommendations()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                loadRecommendations()
            } else if newPhase == .background {
                showChildOnboarding = false
            }
        }
        .onChange(of: showChildOnboarding) { oldVal, newVal in
            if !newVal {
                loadRecommendations()
            }
        }
        .sheet(isPresented: $showChildOnboarding) {
            ChildOnboardingView()
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("AI Recommendations")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            Button {
                showChildOnboarding = true
            } label: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(red: 0.25, green: 0.35, blue: 0.45))
                    .frame(width: 44, height: 44)
                    .background(Color.accentBlue.opacity(0.85))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Activities to swap in")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)
            ForEach(activities) { card in
                ExpandableCardView(
                    card: card,
                    isExpanded: !collapsedIDs.contains(card.id)
                ) {
                    toggle(card)
                }
            }
        }
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Tips to lower screen-time")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)
            ForEach(tips) { card in
                ExpandableCardView(
                    card: card,
                    isExpanded: !collapsedIDs.contains(card.id)
                ) {
                    toggle(card)
                }
            }
        }
    }

    
    private var refreshButton: some View {
        Button {
            Task { await load() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.25, green: 0.35, blue: 0.45))
                Text("Refresh recommendations")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.25, green: 0.35, blue: 0.45))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color(red: 0.64, green: 0.75, blue: 0.88)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helper Methods

   
    private func toggle(_ card: InfoCard) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if collapsedIDs.contains(card.id) {
                collapsedIDs.remove(card.id)
            } else {
                collapsedIDs.insert(card.id)
            }
        }
    }

    private func loadRecommendations() {
        Task {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        collapsedIDs = []
        defer { isLoading = false }

        let targetProfile = currentProfile

        let riskLevel = ChildRiskPredictor.predict(profile: targetProfile)
        modelNote = riskLevel.map { "Risk level: \($0)" }

        do {
            let result = try await service.fetchRecommendations(for: targetProfile, riskLevel: riskLevel)
            activities = result.activities.prefix(3).map {
                InfoCard(emoji: $0.emoji, title: $0.title, detail: $0.detail)
            }
            tips = result.tips.prefix(3).map {
                InfoCard(emoji: $0.emoji, title: "", detail: $0.text)
            }
            usingAI = true
            errorMessage = nil
        } catch {
            errorMessage = (error as? AIError)?.errorDescription ?? error.localizedDescription
            let offline = AIRecommendationService.fallback(for: targetProfile)
            activities = offline.activities.prefix(3).map {
                InfoCard(emoji: $0.emoji, title: $0.title, detail: $0.detail)
            }
            tips = offline.tips.prefix(3).map {
                InfoCard(emoji: $0.emoji, title: "", detail: $0.text)
            }
            usingAI = false
        }

        NotificationManager.scheduleReminders(
            for: targetProfile,
            riskLevel: riskLevel ?? "Low"
        )
    }
}

// MARK: - Expandable Card View
struct ExpandableCardView: View {
    let card: InfoCard
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                Text(card.emoji).font(.system(size: 26))

                VStack(alignment: .leading, spacing: 4) {
                    if !card.title.isEmpty {
                        Text(card.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                    }
                   
                    Text(card.detail)
                        .font(.system(size: 14))
                        .foregroundColor(.black.opacity(0.7))
                        .lineLimit(isExpanded ? nil : 2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black.opacity(0.5))
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, isExpanded ? 18 : 14)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color.accentBlue)) 
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview("Recommendations") {
    RecommendationsView(
        profile: ChildProfile(
            name: "Fahad",
            age: "8",
            grade: "3rd",
            gender: "Male",
            hours: 3.5,
            mostTime: "Night",
            usageTypes: ["Gaming", "Videos"],
            goals: ["Reduce screen-time"],
            likes: ["Lego", "Soccer"]
        )
    )
}
