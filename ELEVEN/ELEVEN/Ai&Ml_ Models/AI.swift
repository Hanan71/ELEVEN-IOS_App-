import SwiftUI
import Combine
import CoreML
import UserNotifications

// Colour tokens (brand, appBG, cardBlue, cardRect, fieldGray, plusBlue,
// chipUnselected, chipSelected) live in AppColors.swift

// MARK: - Keyboard Observer

final class AIKeyboardObserver: ObservableObject {
    @Published var height: CGFloat = 0
    private var cancellables = Set<AnyCancellable>()

    init() {
        let nc = NotificationCenter.default
        nc.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { ($0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.height = $0 }
            .store(in: &cancellables)
        nc.publisher(for: UIResponder.keyboardWillHideNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.height = 0 }
            .store(in: &cancellables)
    }
}

// MARK: - Models

struct ChildProfile: Codable {
    let name: String
    let age: String
    let grade: String
    let gender: String
    let hours: Double
    let mostTime: String
    let usageTypes: [String]
    let goals: [String]
    let likes: [String]
}

struct ChipItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let emoji: String
}

struct ChipView: View {
    let item: ChipItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(item.emoji)
                Text(item.title).font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(isSelected ? Color.chipSelected : Color.chipUnselected))
            .foregroundColor(.black.opacity(isSelected ? 0.9 : 0.65))
        }
        .buttonStyle(.plain)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct DropdownField: View {
    let title: String
    let value: String
    let options: [String]
    @Binding var selection: String

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) { selection = option }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 11)).foregroundColor(.black.opacity(0.5))
                HStack(spacing: 4) {
                    Text(value).font(.system(size: 14, weight: .medium)).foregroundColor(.black)
                    Image(systemName: "chevron.down").font(.system(size: 9)).foregroundColor(.black.opacity(0.5))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.fieldGray))
        }
        .buttonStyle(.plain)
    }
}

struct InfoCard: Identifiable {
    let id = UUID()
    let emoji: String
    let title: String
    let detail: String
}

// MARK: - AI Services

enum AIError: Error, LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:       return "Add your Groq API key to GeminiConfig.swift."
        case .invalidURL:          return "Could not build the AI request URL."
        case .invalidResponse:     return "The AI returned an unexpected response format."
        case .serverError(let msg): return "AI service error: \(msg)"
        }
    }
}

struct AIActivity { let emoji: String; let title: String; let detail: String }
struct AITip      { let emoji: String; let text: String }
struct AIRecommendationResult { let activities: [AIActivity]; let tips: [AITip] }

enum ChildRiskPredictor {

    enum FeatureNames {
        static let age               = "Age"
        static let gender            = "Gender"
        static let averageScreenTime = "Average Screen Time (hours)"
    }

    private static let outputFeatureName = "Risk"

    static let expectedFeatureNames: Set<String> = [
        FeatureNames.age,
        FeatureNames.gender,
        FeatureNames.averageScreenTime
    ]

    @discardableResult
    static func validateModelSchema() -> Bool {
        guard let modelURL = Bundle.main.url(forResource: "MyTabularClassifier 1",
                                            withExtension: "mlmodelc")
                          ?? Bundle.main.url(forResource: "MyTabularClassifier 1",
                                            withExtension: "mlmodel") else {
            print("[ChildRiskPredictor] ⚠️  Model file not found in bundle — prediction will be unavailable.")
            return false
        }

        guard let model = try? MLModel(contentsOf: modelURL) else {
            print("[ChildRiskPredictor] ⚠️  Could not load model for schema validation — check the .mlmodel bundle resource.")
            return false
        }

        let actualNames = Set(model.modelDescription.inputDescriptionsByName.keys)
        guard actualNames == expectedFeatureNames else {
            let missing  = expectedFeatureNames.subtracting(actualNames).sorted()
            let extra    = actualNames.subtracting(expectedFeatureNames).sorted()
            print("[ChildRiskPredictor] ❌  Model schema mismatch — predictions will fail.")
            if !missing.isEmpty { print("  Features expected but absent : \(missing)") }
            if !extra.isEmpty   { print("  Features present but unexpected: \(extra)") }
            print("  → Update ChildRiskPredictor.FeatureNames to match the new model spec.")
            return false
        }

        print("[ChildRiskPredictor] ✅  Schema validated — all expected input features are present.")
        return true
    }

    static func predict(profile: ChildProfile) -> String? {
        guard let modelURL = Bundle.main.url(forResource: "MyTabularClassifier 1",
                                            withExtension: "mlmodelc")
                          ?? Bundle.main.url(forResource: "MyTabularClassifier 1",
                                            withExtension: "mlmodel") else {
            print("[ChildRiskPredictor] ⚠️  Model file not found — skipping prediction.")
            return nil
        }

        do {
            let model = try MLModel(contentsOf: modelURL)

            let features: [String: Any] = [
                FeatureNames.age              : Double(profile.age) ?? 0.0,
                FeatureNames.gender           : profile.gender,
                FeatureNames.averageScreenTime: profile.hours
            ]
            let provider   = try MLDictionaryFeatureProvider(dictionary: features)
            let prediction = try model.prediction(from: provider)

            guard let risk = prediction.featureValue(for: outputFeatureName)?.stringValue else {
                print("[ChildRiskPredictor] ⚠️  Prediction ran but output feature '\(outputFeatureName)' was nil — verify the model output name.")
                return nil
            }
            return risk

        } catch {
            print("[ChildRiskPredictor] ❌  Prediction failed: \(error.localizedDescription)")
            return nil
        }
    }
}

final class AIRecommendationService {

    // ✅ آخر ما انعرض بالقسمين — لمنع أي تكرار بالـ Refresh
    private static var lastTitles: [String] = []
    private static var lastTips: [String] = []

    func fetchRecommendations(for profile: ChildProfile,
                              riskLevel: String? = nil) async throws -> AIRecommendationResult {
        guard !GeminiConfig.apiKey.isEmpty,
              GeminiConfig.apiKey != "YOUR_KEY_HERE",
              GeminiConfig.apiKey != "GEMINI_API_KEY_HERE" else {
            throw AIError.notConfigured
        }

        // ✅ بذرة عشوائية + قوائم سوداء للأنشطة والنصايح = تنويع بالطلب نفسه
        var prompt = buildPrompt(profile: profile, riskLevel: riskLevel)
            + "\n\nCreative seed: \(Int.random(in: 1000...99999)) — hidden inspiration for a completely NEW set."
        if !Self.lastTitles.isEmpty {
            prompt += "\nNEVER reuse these previous activity titles: \(Self.lastTitles.joined(separator: " | "))"
        }
        if !Self.lastTips.isEmpty {
            prompt += "\nNEVER reuse these previous tips: \(Self.lastTips.joined(separator: " | "))"
        }

        let models = [
            "llama-3.3-70b-versatile",
            "llama-3.1-8b-instant",
            "openai/gpt-oss-20b",
            "meta-llama/llama-4-scout-17b-16e-instruct"
        ]
        var lastError: Error = AIError.invalidResponse
        for model in models {
            do {
                let text   = try await callGroq(prompt: prompt, model: model)
                let parsed = parse(text, profile: profile)

                // ✅ إذا الـ AI كرر نفس الأنشطة أو نفس النصايح — نستبدل القسم المكرر بأفكار محلية جديدة
                var acts = parsed.activities
                var tips = parsed.tips
                if acts.map({ $0.title }) == Self.lastTitles {
                    acts = Self.freshActivities(for: profile)
                }
                if tips.map({ $0.text }) == Self.lastTips {
                    tips = Self.freshTips(for: profile)
                }

                Self.lastTitles = acts.map { $0.title }
                Self.lastTips   = tips.map { $0.text }
                return AIRecommendationResult(activities: acts, tips: tips)
            } catch {
                print("[AI] ❌ \(model) فشل: \(error)")
                lastError = error
            }
        }

        // ✅ فشل الاتصال بالكامل → مجموعة محلية مختلفة عن المعروضة حاليًا
        let offline = Self.offlineResult(for: profile)
        Self.lastTitles = offline.activities.map { $0.title }
        Self.lastTips   = offline.tips.map { $0.text }
        print("[AI] ⚠️ الطلب المباشر فشل — عرضنا أفكار محلية متنوعة: \(lastError)")
        return offline
    }

    // MARK: - Prompt (جمل كاملة واضحة + تحليل إجابات الأهل)

    private func buildPrompt(profile: ChildProfile, riskLevel: String?) -> String {
        let risk  = riskLevel ?? "Unknown"
        let usage = profile.usageTypes.joined(separator: ", ")
        let goals = profile.goals.joined(separator: ", ")
        let likes = profile.likes.joined(separator: ", ")

        return """
        You are a child screen-time coach. Craft concise but COMPLETE, highly personalised suggestions from the parents' answers below.

        Child: \(profile.name), \(profile.age) y/o, grade \(profile.grade)
        Screen time: \(Int(profile.hours))h/day, mostly \(profile.mostTime)
        Device used for: \(usage)
        Parent goals: \(goals)
        Child interests: \(likes)
        Risk level: \(risk) — \(riskGuidanceContext(risk))

        Respond with ONLY valid JSON, no markdown:
        {
          "activities": [
            { "emoji": "⚽️", "title": "max 5 words", "detail": "one full friendly sentence, 10-18 words, e.g. 20 min of team play outside to build coordination and confidence." },
            { "emoji": "🧩", "title": "max 5 words", "detail": "one full friendly sentence, 10-18 words." },
            { "emoji": "🎨", "title": "max 5 words", "detail": "one full friendly sentence, 10-18 words." }
          ],
          "tips": [
            { "emoji": "💡", "text": "one complete actionable sentence for parents, 12-22 words." },
            { "emoji": "🌙", "text": "one complete actionable sentence for parents, 12-22 words." },
            { "emoji": "📍", "text": "one complete actionable sentence for parents, 12-22 words." }
          ]
        }

        Strict rules:
        • Each activity MUST use one of the child's interests; each tip MUST serve one parent goal.
        • Titles max 5 words. Every detail and tip MUST be a COMPLETE sentence — never cut mid-way, never vague fragments.
        • Completely new ideas every time, for BOTH activities and tips.
        """
    }

    private func riskGuidanceContext(_ risk: String) -> String {
        switch risk.lowercased() {
        case "high":   return "prioritise urgent reduction and strict limits"
        case "medium": return "gradual reduction with fun alternatives"
        default:       return "reinforce healthy balanced habits"
        }
    }

    // MARK: - Groq Network Call (OpenAI-compatible)

    private func callGroq(prompt: String, model: String) async throws -> String {
        guard let url = URL(string: GeminiConfig.endpoint) else {
            throw AIError.invalidURL
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You are a child screen-time coach. Respond with ONLY valid JSON, no markdown. Every sentence must be complete, never truncated."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 1.0,
            "max_tokens": 1024
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(GeminiConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        var (data, response) = try await URLSession.shared.data(for: request)

        // ✅ حد الدقيقة (429): انتظر 5 ثواني وأعد مرة وحدة تلقائيًا
        if let http = response as? HTTPURLResponse, http.statusCode == 429 {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            (data, response) = try await URLSession.shared.data(for: request)
        }

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.serverError(msg)
        }

        guard
            let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let text    = message["content"] as? String
        else { throw AIError.invalidResponse }

        return text
    }

    private func parse(_ text: String, profile: ChildProfile) -> AIRecommendationResult {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```",     with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let data = cleaned.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return Self.offlineResult(for: profile) }

        let activities: [AIActivity] = (json["activities"] as? [[String: Any]] ?? [])
            .compactMap { d in
                guard let title  = d["title"]  as? String,
                      let detail = d["detail"] as? String else { return nil }
                return AIActivity(emoji: d["emoji"] as? String ?? "✨", title: title, detail: detail)
            }

        let tips: [AITip] = (json["tips"] as? [[String: Any]] ?? [])
            .compactMap { d in
                guard let text = d["text"] as? String else { return nil }
                return AITip(emoji: d["emoji"] as? String ?? "💡", text: text)
            }

        return AIRecommendationResult(
            activities: activities.isEmpty ? Self.freshActivities(for: profile) : activities,
            tips:       tips.isEmpty       ? Self.freshTips(for: profile)       : tips
        )
    }

    static func fallback(for profile: ChildProfile) -> AIRecommendationResult {
        offlineResult(for: profile)
    }

    // MARK: - بنك الأفكار المحلي (تنويع مضمون بالقسمين حتى بدون إنترنت)

    private static func activityBank(for profile: ChildProfile) -> [AIActivity] {
        let like = profile.likes.first ?? "their favorite hobby"
        return [
            AIActivity(emoji: "⚽️", title: "\(like) skills practice", detail: "30 minutes of \(like) outside to burn energy and build real confidence."),
            AIActivity(emoji: "🧩", title: "Building block challenge", detail: "20 minutes of building the tallest tower you can to grow focus and patience."),
            AIActivity(emoji: "🎨", title: "Home art studio", detail: "30 minutes of drawing and crafts to express feelings and boost imagination."),
            AIActivity(emoji: "📖", title: "Family reading time", detail: "15 minutes of reading a story together to grow vocabulary and closeness."),
            AIActivity(emoji: "🚲", title: "Neighborhood bike ride", detail: "25 minutes of riding outside for fresh air and stronger muscles."),
            AIActivity(emoji: "🧑", title: "Little chef session", detail: "20 minutes of preparing a simple snack to learn real-life skills."),
            AIActivity(emoji: "🎵", title: "Dance break party", detail: "10 minutes of dancing to favorite songs to release energy and laugh together."),
            AIActivity(emoji: "🧸", title: "Imagination role-play", detail: "15 minutes of pretending and storytelling to spark creativity and language."),
            AIActivity(emoji: "🌱", title: "Plant care mission", detail: "10 minutes of watering plants and checking growth to build responsibility."),
            AIActivity(emoji: "🎯", title: "Board game night", detail: "30 minutes of a family board game to practice turn-taking and focus."),
            AIActivity(emoji: "🪁", title: "Park adventure hour", detail: "40 minutes at the park with a kite or ball for full-body fun."),
            AIActivity(emoji: "🧹", title: "Treasure clean-up game", detail: "15 minutes of tidying one corner as a game to earn a small reward.")
        ]
    }

    private static func tipsBank(for profile: ChildProfile) -> [AITip] {
        let name = profile.name
        return [
            AITip(emoji: "🕰️", text: "Set a device-free hour before bed so \(name) winds down and sleeps better."),
            AITip(emoji: "📍", text: "Keep screens out of bedrooms and mealtime areas to protect sleep and family talk."),
            AITip(emoji: "🌟", text: "Praise \(name) every time they choose an offline activity on their own."),
            AITip(emoji: "🔔", text: "Use a visible timer so \(name) knows exactly when screen time ends."),
            AITip(emoji: "🚪", text: "Charge all devices outside the bedroom overnight to protect deep sleep."),
            AITip(emoji: "🤝", text: "Agree on two screen-free family hours every day and join in yourself."),
            AITip(emoji: "📵", text: "Plan one fully screen-free morning each weekend for a family adventure."),
            AITip(emoji: "🎁", text: "Reward three screen-light days with a small weekend treat \(name) loves."),
            AITip(emoji: "🌙", text: "Replace \(profile.mostTime) scrolling with a calm routine like reading or drawing."),
            AITip(emoji: "🧺", text: "Let \(name) pick one offline hobby each week and schedule it like a class."),
            AITip(emoji: "👨👩‍", text: "Model the habit yourself — put your own phone away during \(name)'s screen-free time."),
            AITip(emoji: "📊", text: "Review the weekly screen-time report together and celebrate any improvement.")
        ]
    }

    /// ✅ 3 أنشطة جديدة مختلفة عمّا انعرض آخر مرة
    private static func freshActivities(for profile: ChildProfile) -> [AIActivity] {
        var fresh = activityBank(for: profile).filter { !lastTitles.contains($0.title) }.shuffled()
        if fresh.count < 3 { fresh = activityBank(for: profile).shuffled() }
        return Array(fresh.prefix(3))
    }

    /// ✅ 3 نصايح جديدة مختلفة عمّا انعرض آخر مرة
    private static func freshTips(for profile: ChildProfile) -> [AITip] {
        var fresh = tipsBank(for: profile).filter { !lastTips.contains($0.text) }.shuffled()
        if fresh.count < 3 { fresh = tipsBank(for: profile).shuffled() }
        return Array(fresh.prefix(3))
    }

    private static func offlineResult(for profile: ChildProfile) -> AIRecommendationResult {
        AIRecommendationResult(activities: freshActivities(for: profile), tips: freshTips(for: profile))
    }
}

// MARK: - Local Notification Manager
enum NotificationManager {

    static func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func scheduleReminders(for profile: ChildProfile, riskLevel: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(
            withIdentifiers: (0..<3).map { "screenbuddy.reminder.\($0)" }
        )

        let messages = buildMessages(for: profile, riskLevel: riskLevel)
        let hours    = [9, 13, 17]

        for (index, message) in messages.prefix(3).enumerated() {
            let content       = UNMutableNotificationContent()
            content.title     = "Hi \(profile.name)! 👋"
            content.body      = message
            content.sound     = .default

            var components    = DateComponents()
            components.hour   = hours[index]
            components.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: "screenbuddy.reminder.\(index)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    static func cancelAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private static func buildMessages(for profile: ChildProfile,
                                      riskLevel: String) -> [String] {
        var messages: [String] = []

        for goal in profile.goals {
            switch goal {
            case "Reduce screen-time":
                let activity = profile.likes.first ?? "something fun"
                messages.append("Time for a screen break! Try \(activity) instead 🌟")
            case "Improve focus":
                messages.append("Focus check-in! Put the screen away for 15 mins and try a quiet activity 🧠")
            case "Better sleep":
                messages.append("Wind-down time! Screen off soon for a great night's sleep 🌙")
            default:
                break
            }
        }

        switch riskLevel.lowercased() {
        case "high":
            messages.append("Screen break time! Your body needs movement 🏃")
            messages.append("Let's put the device down for a bit — you've got this! 💪")
        case "medium":
            messages.append("Halfway through the day — how about a 10-minute outdoor break? ☀️")
        default:
            messages.append("Great job managing your screen time today! Keep it up 🌟")
        }

        return messages
    }
}

// MARK: - Profile Store
enum ProfileStore {
    private static let key = "savedChildProfile"

    static func save(_ profile: ChildProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> ChildProfile? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ChildProfile.self, from: data)
    }
}

// MARK: - Child Flow Root
struct ChildFlowRootView: View {
    @AppStorage("hasSeenChildOnboarding") private var hasSeenChildOnboarding = false
    @State private var savedProfile: ChildProfile? = ProfileStore.load()

    var body: some View {
        if hasSeenChildOnboarding, let profile = savedProfile {
            RecommendationsView(profile: profile)
        } else {
            ChildOnboardingView()
        }
    }
}

struct HoursSlider: View {
    @Binding var hours: Double
    var range: ClosedRange<Double> = 1...15
    var step: Double = 1
    let thumbSize: CGFloat = 34

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                roundButton("minus") { hours = max(range.lowerBound, hours - step) }

                GeometryReader { geo in
                    let usable = max(geo.size.width - thumbSize, 1)
                    let progress = CGFloat((hours - range.lowerBound) / (range.upperBound - range.lowerBound))

                    ZStack(alignment: .topLeading) {
                        Capsule()
                            .fill(Color(white: 0.85))
                            .frame(height: 6)
                            .offset(y: thumbSize / 2 - 3)

                        Circle()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                            .frame(width: thumbSize, height: thumbSize)
                            .overlay(
                                Text("\(Int(hours))")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.black.opacity(0.75))
                            )
                            .offset(x: usable * progress)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let raw = (value.location.x - thumbSize / 2) / usable
                                let clamped = min(max(0, raw), 1)
                                let newValue = range.lowerBound + Double(clamped) * (range.upperBound - range.lowerBound)
                                hours = (newValue / step).rounded() * step
                            }
                    )
                }
                .frame(height: thumbSize)

                roundButton("plus") { hours = min(range.upperBound, hours + step) }
            }

            HStack(spacing: 14) {
                Color.clear.frame(width: 38, height: 1)
                HStack(spacing: 0) {
                    ForEach(1...15, id: \.self) { i in
                        Text("\(i)")
                            .font(.system(size: 11, weight: i == Int(hours) ? .bold : .regular))
                            .foregroundColor(i == Int(hours) ? .black : Color(white: 0.45))
                            .frame(maxWidth: .infinity)
                    }
                }
                Color.clear.frame(width: 38, height: 1)
            }
        }
    }

    private func roundButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.black.opacity(0.7))
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.plusBlue))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Child Flow Root") {
    ChildFlowRootView()
}
