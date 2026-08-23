import SwiftUI
import Combine

// MARK: -  "Tell us about your child"

struct ChildOnboardingView: View {

    @Environment(\.scenePhase) private var scenePhase
    
    @Environment(\.dismiss) private var dismiss

    @AppStorage("isParentMode") private var isParentMode = true

    @AppStorage("hasSeenChildOnboarding") private var hasSeenChildOnboarding = false

    @State private var age = "9"
    @State private var grade = "3rd"
    @State private var gender = "Male"

    @State private var hours: Double = 1
    @State private var selectedTime: String? = "Morning"
    @State private var selectedUsage: Set<String> = ["Game", "Watch-video"]
    @State private var selectedGoals: Set<String> = ["Reduce screen-time"]
    @State private var selectedLikes: Set<String> = ["Soccer", "Paint", "Lego"]

    @State private var showRecommendations = false

    // Reads the name entered in HiThereView via the shared AppStorage key.
    @AppStorage("childName") private var storedChildName: String = ""
    private var childName: String {
        storedChildName.isEmpty ? "your child" : storedChildName
    }

    private let timeOptions = [
        ChipItem(title: "Morning", emoji: "☀️"),
        ChipItem(title: "Noon", emoji: "🌇"),
        ChipItem(title: "Night", emoji: "🌃")
    ]
    private let usageOptions = [
        ChipItem(title: "Games", emoji: "🎮"),
        ChipItem(title: "Entreatment", emoji: "🖥️"),
        ChipItem(title: "Social", emoji: "👥")
    ]
    private let goalOptions = [
        ChipItem(title: "Reduce screen-time", emoji: "🎮"),
        ChipItem(title: "Improve focus", emoji: "🧠"),
        ChipItem(title: "Better sleep", emoji: "😴")
    ]
    @State private var likeOptions: [ChipItem] = [
        ChipItem(title: "Soccer", emoji: "⚽️"),
        ChipItem(title: "Read", emoji: "📖"),
        ChipItem(title: "Paint", emoji: "🎨"),
        ChipItem(title: "Lego", emoji: "🧩")
    ]

    @State private var showAddAlert = false
    @State private var newLike = ""

    private var currentProfile: ChildProfile {
        ChildProfile(name: childName, age: age, grade: grade, gender: gender,
                     hours: hours, mostTime: selectedTime ?? "-",
                     usageTypes: Array(selectedUsage),
                     goals: Array(selectedGoals),
                     likes: Array(selectedLikes))
    }

    var body: some View {
        onboardingForm
            .onAppear { loadSavedProfile() }
         
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .background {
                    showRecommendations = false
                    isParentMode = false
                    dismiss()
                }
            }
            .fullScreenCover(isPresented: $showRecommendations) {
                RecommendationsView(profile: currentProfile)
            }
            .alert("Add interest", isPresented: $showAddAlert) {
                TextField("e.g. Swimming", text: $newLike)
                Button("Add") {
                    let trimmed = newLike.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        likeOptions.append(ChipItem(title: trimmed, emoji: "⭐️"))
                        selectedLikes.insert(trimmed)
                    }
                    newLike = ""
                }
                Button("Cancel", role: .cancel) { newLike = "" }
            }
    }

    // MARK: - Onboarding Form View
    private var onboardingForm: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 30) {
                backButton
                header
                aboutSection
                habitsSection
                timeSection
                usageSection
                goalsSection
                likesSection
                seeRecommendationsButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .background(Color.appBG.ignoresSafeArea())
    }

    // MARK: - 
    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
            }
            .padding(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Persistence helpers

    private func loadSavedProfile() {
        guard let saved = ProfileStore.load() else { return }

        age    = saved.age
        grade  = saved.grade
        gender = saved.gender
        hours  = saved.hours
        selectedTime = saved.mostTime.isEmpty ? nil : saved.mostTime

        selectedUsage = Set(saved.usageTypes)
        selectedGoals = Set(saved.goals)
        selectedLikes = Set(saved.likes)

        let knownTitles = Set(likeOptions.map(\.title))
        for like in saved.likes where !knownTitles.contains(like) {
            likeOptions.append(ChipItem(title: like, emoji: "⭐️"))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tell us about your child!")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.black)
            Text("A few details so we can tailor recommendations")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.black.opacity(0.7))
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.black)
                Text(childName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 14) {
                DropdownField(title: "Age", value: age,
                              options: (3...16).map { "\($0)" }, selection: $age)
                DropdownField(title: "Grade", value: grade,
                              options: ["KG", "1st", "2nd", "3rd", "4th", "5th", "6th"],
                              selection: $grade)
                DropdownField(title: "Gender", value: gender,
                              options: ["Male", "Female"], selection: $gender)
            }
        }
    }

    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current screen habits!")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)
            Text("How many hours does \(childName) use the ipad?")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black.opacity(0.85))
            HoursSlider(hours: $hours)
                .padding(.top, 6)
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("When does \(childName) use it the most?")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
            FlowLayout {
                ForEach(timeOptions) { item in
                    ChipView(item: item, isSelected: selectedTime == item.title) {
                        selectedTime = item.title
                    }
                }
            }
        }
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device usage type?")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
            FlowLayout {
                ForEach(usageOptions) { item in
                    ChipView(item: item, isSelected: selectedUsage.contains(item.title)) {
                        if selectedUsage.contains(item.title) { selectedUsage.remove(item.title) }
                        else { selectedUsage.insert(item.title) }
                    }
                }
            }
        }
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What is the parents goal?")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
            FlowLayout {
                ForEach(goalOptions) { item in
                    ChipView(item: item, isSelected: selectedGoals.contains(item.title)) {
                        if selectedGoals.contains(item.title) { selectedGoals.remove(item.title) }
                        else { selectedGoals.insert(item.title) }
                    }
                }
            }
        }
    }

    private var likesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What does \(childName) like?")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
            FlowLayout {
                ForEach(likeOptions) { item in
                    ChipView(item: item, isSelected: selectedLikes.contains(item.title)) {
                        if selectedLikes.contains(item.title) { selectedLikes.remove(item.title) }
                        else { selectedLikes.insert(item.title) }
                    }
                }
                addChip
            }
        }
    }

    private var addChip: some View {
        Button { showAddAlert = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black.opacity(0.6))
                    .padding(5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.25)))
                Text("Add")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.black.opacity(0.75))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Capsule().fill(Color.chipUnselected))
        }
        .buttonStyle(.plain)
    }

    private var seeRecommendationsButton: some View {
        Button {
            hasSeenChildOnboarding = true
            ProfileStore.save(currentProfile)
            showRecommendations = true
        } label: {
            HStack {
                Text("See recommendations")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(Capsule().fill(Color.fieldGray))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    ChildOnboardingView()
}
