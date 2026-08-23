import SwiftUI
import Combine

final class KeyboardObserver: ObservableObject {
    @Published var height: CGFloat = 0
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
            .map { $0.height }
            .sink { [weak self] in self?.height = $0 }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in self?.height = 0 }
            .store(in: &cancellables)
    }
}

struct RewardView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ActivityStore
    var rewardToEdit: SharedReward? = nil

    @State private var rewardName: String = ""
    @State private var points: Int = 10
    @State private var showSavedToast: Bool = false
    @State private var showEmojiPicker: Bool = false
    @State private var selectedEmoji: String = "😄"

    @StateObject private var keyboard = KeyboardObserver()
    @FocusState private var isNameFieldFocused: Bool

    let background = Color(hex: "F8F8F8")
    let blue = Color(red: 0.42, green: 0.62, blue: 0.88)

    
    let emojiOptions = [
        "🍦", "🎬", "🍩", "🎁", "🎮",
        " 🧸", "🎲", "🎂", "🧃", "🍕",
        "🍫", "🎯", "🍓", "⚽", "🚲",
        "⚽️", "⭐️", "🐶", "🐱", "🏀"
        ,"🧩", "🥞", "✈️", "📝"
    ]

    var lightBlue: Color { blue.opacity(0.35) }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

  
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.black)
                    }

                    Text(rewardToEdit != nil ? "Edit Reward" : "Reward")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.black) 
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, -44)

                    HStack(spacing: 12) {
                        Button(action: {
                            isNameFieldFocused = false
                            showEmojiPicker = true
                        }) {
                            ZStack(alignment: .bottomTrailing) {
                                Circle()
                                    .fill(Color.white.opacity(0.6))
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(
                                                blue.opacity(0.6),
                                                style: StrokeStyle(lineWidth: 2, dash: [5, 4])
                                            )
                                    )

                                Text(selectedEmoji)
                                    .font(.system(size: 30))
                                    .frame(width: 56, height: 56)

                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(blue)
                                    .frame(width: 20, height: 20)
                                    .offset(x: 4, y: 4)
                            }
                        }

                        TextField("", text: $rewardName, prompt: Text("Add Reward").foregroundColor(Color(hex: "525257")))
                            .font(.system(size: 18))
                            .foregroundStyle(Color(hex: "525257"))
                            .focused($isNameFieldFocused)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .background(lightBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 24))

                    Text("🎯 How many points does it cost?")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.black)

                    HStack {
                        Spacer()

                        Button(action: { if points > 0 { points -= 1 } }) {
                            Image(systemName: "minus")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(blue)
                                .clipShape(Circle())
                        }

                        Spacer()

                        Text("\(points) pts")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(Color(hex: "525257"))

                        Spacer()

                        Button(action: { points += 1 }) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(blue)
                                .clipShape(Circle())
                        }

                        Spacer()
                    }
                    .padding(.vertical, 24)
                    .background(lightBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 24))

                    Spacer(minLength: 20)

                    Button(action: saveReward) {
                        Text(rewardToEdit != nil ? "Update Reward" : "Save Reward")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(blue)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(.keyboard, edges: .bottom)

            if showSavedToast {
                VStack {
                    Spacer()

                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white)

                        Text("Saved successfully")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(blue)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showSavedToast)
        .sheet(isPresented: $showEmojiPicker) {
            RewardEmojiSheet(
                emojiOptions: emojiOptions,
                selectedEmoji: $selectedEmoji,
                accentColor: blue,
                background: background
            )
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            if let r = rewardToEdit {
                rewardName = r.title
                selectedEmoji = r.icon
                points = r.cost
            }
        }
    }

    private func saveReward() {
        guard !rewardName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        if let r = rewardToEdit,
           let i = store.rewards.firstIndex(where: { $0.id == r.id }) {
            store.rewards[i].title = rewardName.trimmingCharacters(in: .whitespaces)
            store.rewards[i].icon  = selectedEmoji
            store.rewards[i].cost  = points
        } else {
            store.rewards.append(
                SharedReward(icon: selectedEmoji,
                             title: rewardName.trimmingCharacters(in: .whitespaces),
                             cost: points)
            )
        }

        showSavedToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showSavedToast = false
            dismiss()
        }

        rewardName = ""
        points = 10
        selectedEmoji = "😄"
    }
}

struct RewardEmojiSheet: View {

    let emojiOptions: [String]
    @Binding var selectedEmoji: String
    let accentColor: Color
    let background: Color

    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 5)

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Choose an icon")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.top, 20)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(emojiOptions, id: \.self) { emoji in
                            Button(action: {
                                selectedEmoji = emoji
                                dismiss()
                            }) {
                                Text(emoji)
                                    .font(.system(size: 32))
                                    .frame(width: 56, height: 56)
                                    .background(
                                        selectedEmoji == emoji
                                            ? accentColor.opacity(0.35)
                                            : Color.clear
                                    )
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

#Preview {
    RewardView()
        .environmentObject(ActivityStore.shared)
}
