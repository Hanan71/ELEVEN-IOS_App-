import SwiftUI
import Combine

private enum TodoPalette {
    static let bg        = Color(red: 0.97, green: 0.97, blue: 0.97)
    static let cardBG    = Color(red: 0.98, green: 0.83, blue: 0.79)
    static let primary   = Color(red: 0.99, green: 0.52, blue: 0.41)
    static let textDark  = Color.black.opacity(0.8)
    static let textGray  = Color(red: 0.58, green: 0.62, blue: 0.67)
}

final class TodoKeyboardObserver: ObservableObject {
    @Published var height: CGFloat = 0
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { ($0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height }
            .assign(to: \.height, on: self)
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }
            .assign(to: \.height, on: self)
            .store(in: &cancellables)
    }
}

struct ToDoActivityView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ActivityStore
    var taskToEdit: SharedTask? = nil
    
    @State private var activityName     = ""
    @State private var points           = 10
    @State private var showSavedToast   = false
    @State private var showEmojiPicker  = false
    @State private var selectedEmoji    = "😄"

    @StateObject private var keyboard   = TodoKeyboardObserver()
    @FocusState private var isNameFieldFocused: Bool

    let emojiOptions = ["😄", "🌻", "🎨", "📚", "🧹", "🏃‍♀️", "🎵", "🍎", "🧸", "🛏️", "🪥", "🥗", "🧘‍♀️", "🎮", "✏️", "🚿","📝", "➗"]

    var body: some View {
        ZStack {
            TodoPalette.bg
                .ignoresSafeArea()

            // ✅ ScrollView يحل مشكلة الكيبورد
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {

                    Button(action: dismiss.callAsFunction) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(TodoPalette.textDark)
                    }

                    Text(taskToEdit != nil ? "Edit To Do" : "To Do")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(TodoPalette.textDark)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, -44)

                    HStack(spacing: 16) {
                        Button {
                            isNameFieldFocused = false
                            showEmojiPicker = true
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                Circle()
                                    .fill(Color.white.opacity(0.8))
                                    .frame(width: 64, height: 64)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(TodoPalette.primary.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                                    )

                                Text(selectedEmoji)
                                    .font(.system(size: 34))
                                    .frame(width: 64, height: 64)

                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(TodoPalette.primary)
                                    .frame(width: 22, height: 22)
                                    .offset(x: 4, y: 4)
                            }
                        }
                        .buttonStyle(.plain)

                        TextField("", text: $activityName, prompt: Text("Add Activity").foregroundColor(Color(hex: "525257")))
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color(hex: "525257"))
                            .focused($isNameFieldFocused)
                            .submitLabel(.done)
                            .textInputAutocapitalization(.sentences)
                            .autocorrectionDisabled(false)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .background(TodoPalette.cardBG)
                    .clipShape(RoundedRectangle(cornerRadius: 26))

                    HStack(spacing: 6) {
                        Text("🎯").font(.system(size: 18))
                        Text("How many point dose it cost?")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(TodoPalette.textDark)
                    }

                    HStack {
                        Spacer()

                        stepperButton(systemName: "minus") {
                            isNameFieldFocused = false
                            if points > 0 { points -= 1 }
                        }

                        Spacer()

                        Text("\(points) pts")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color(hex: "525257")) 

                        Spacer()

                        stepperButton(systemName: "plus") {
                            isNameFieldFocused = false
                            points += 1
                        }

                        Spacer()
                    }
                    .padding(.vertical, 28)
                    .background(TodoPalette.cardBG)
                    .clipShape(RoundedRectangle(cornerRadius: 26))

                    Spacer(minLength: 20)

                    Button(action: saveActivity) {
                        Text(taskToEdit != nil ? "Update Activity" : "Save Activity")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(TodoPalette.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 26))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(.keyboard, edges: .bottom)

            if showSavedToast {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                        Text("Saved successfully")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 26)
                    .padding(.vertical, 16)
                    .background(TodoPalette.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showSavedToast)
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerSheet(emojiOptions: emojiOptions, selectedEmoji: $selectedEmoji)
                .presentationDetents([.height(340)])
        }
        .onAppear {
            if let t = taskToEdit {
                activityName = t.title
                selectedEmoji = t.icon
                points = t.points
            }
        }
    }

    @ViewBuilder
    private func stepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(TodoPalette.primary)
                .clipShape(Circle())
        }
    }

    private func saveActivity() {
        guard !activityName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        if let t = taskToEdit,
           let i = store.tasks.firstIndex(where: { $0.id == t.id }) {
            store.tasks[i].title = activityName.trimmingCharacters(in: .whitespaces)
            store.tasks[i].icon  = selectedEmoji
            store.tasks[i].points = points
        } else {
            let newTask = SharedTask(icon: selectedEmoji, title: activityName, points: points)
            store.addTask(newTask)
        }

        showSavedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showSavedToast = false
            dismiss()
        }
    }
}

struct EmojiPickerSheet: View {
    let emojiOptions: [String]
    @Binding var selectedEmoji: String
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 5)

    var body: some View {
        ZStack {
            TodoPalette.bg.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Choose an icon")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(TodoPalette.textDark)
                    .padding(.top, 20)

                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(emojiOptions, id: \.self) { emoji in
                        Button {
                            selectedEmoji = emoji
                            dismiss()
                        } label: {
                            Text(emoji)
                                .font(.system(size: 34))
                                .frame(width: 58, height: 58)
                                .background(selectedEmoji == emoji ? TodoPalette.primary.opacity(0.35) : .clear)
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }
}

#Preview {
    ToDoActivityView()
        .environmentObject(ActivityStore.shared)
}
