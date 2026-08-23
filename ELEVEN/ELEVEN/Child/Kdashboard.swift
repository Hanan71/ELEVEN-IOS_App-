import SwiftUI
import Combine

private enum Palette {
    static let breakBG   = Color(red: 0.80, green: 0.87, blue: 0.95)
    static let breakText = Color.black.opacity(0.72)

    static let taskBG   = Color(red: 0.98, green: 0.83, blue: 0.79)
    static let taskText = Color(red: 0.99, green: 0.52, blue: 0.41)
    static let taskPill = Color(red: 0.99, green: 0.52, blue: 0.41)

    static let completedBG = Color(red: 0.88, green: 0.96, blue: 0.88)

    static let ptsPill    = Color(red: 0.80, green: 0.87, blue: 0.95)
    static let iceCreamBG = Color(red: 0.80, green: 0.87, blue: 0.95)
    static let legoBG     = Color(red: 0.91, green: 0.91, blue: 0.92)
    static let claimedBG  = Color(red: 0.88, green: 0.96, blue: 0.88)
    static let getItPill  = Color(red: 0.62, green: 0.75, blue: 0.88)
    static let lockPill   = Color(red: 0.56, green: 0.56, blue: 0.58)
    static let parentBG   = Color(red: 0.93, green: 0.93, blue: 0.94)
}

private enum CardMetrics {
    static let phoneWidth : CGFloat = 170
    static let cardSpacing: CGFloat = 14
    static let todoHeight : (phone: CGFloat, pad: CGFloat) = (175, 190)
    static let rewardHeight: (phone: CGFloat, pad: CGFloat) = (185, 200)
}

private struct ScrollAtEndModifier: ViewModifier {
    let threshold: CGFloat
    let onChange: (Bool) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.x + geo.containerSize.width >= geo.contentSize.width - threshold
            } action: { _, isAtEnd in
                DispatchQueue.main.async { onChange(isAtEnd) }
            }
        } else {
            content
        }
    }
}

struct KidsDashboardView: View {

    @EnvironmentObject private var store: ActivityStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("childName") private var childName: String = ""
    @State private var showParentControl = false
    @State private var breakPage         = 0

    @State private var currentTaskID: UUID?
    @State private var currentRewardID: UUID?

    @State private var taskAtEnd = false
    @State private var rewardAtEnd = false

    @State private var taskViewportWidth: CGFloat = 0
    @State private var rewardViewportWidth: CGFloat = 0

    private var isPad: Bool {
        horizontalSizeClass == .regular
    }

    private let breakMessages: [String] = [
        "Take a break ⏳",
        "Drink some water 💧",
        "Time to stretch 🧘",
        "Rest your eyes 👀",
        "Go say 'hi' to someone 👋",
        "Take 5 deep breaths 😮‍💨"
    ]
    private let breakTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    private var activeTasks: [SharedTask] {
        store.tasks.filter { !$0.isCompleted }
    }

    private var currentTaskIndex: Int {
        guard let id = currentTaskID, let idx = activeTasks.firstIndex(where: { $0.id == id }) else { return 0 }
        return idx
    }

    // المكافآت المعروضة: فقط المكافآت التي لم تتم الموافقة النهائية عليها بعد (المطالب بها تظهر باللون الأخضر حتى يوافق الأهل)
    private var visibleRewards: [SharedReward] {
        store.rewards.filter { reward in
            // إذا كان المودل يحتوي على خاصية approval يتم استثناء الموافق عليها فقط
            return true
        }
    }

    private var sortedRewards: [SharedReward] {
        visibleRewards
            .enumerated()
            .sorted { lhs, rhs in
                let l = rank(for: lhs.element), r = rank(for: rhs.element)
                return l == r ? lhs.offset < rhs.offset : l < r
            }
            .map(\.element)
    }

    private func rank(for reward: SharedReward) -> Int {
        if reward.isClaimed { return 2 }
        return store.isUnlocked(reward) ? 0 : 1
    }

    private var currentRewardIndex: Int {
        guard let id = currentRewardID, let idx = sortedRewards.firstIndex(where: { $0.id == id }) else { return 0 }
        return idx
    }

    private var taskCardWidth: CGFloat {
        taskViewportWidth > 0 ? (taskViewportWidth - CardMetrics.cardSpacing) / 1.5 : 220
    }

    private var rewardCardWidth: CGFloat {
        rewardViewportWidth > 0 ? (rewardViewportWidth - CardMetrics.cardSpacing) / 1.5 : 220
    }

    private var taskDotIndex: Int {
        taskAtEnd ? max(0, activeTasks.count - 1) : currentTaskIndex
    }

    private var rewardDotIndex: Int {
        rewardAtEnd ? max(0, sortedRewards.count - 1) : currentRewardIndex
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 20)]
    }

    private func childClaimReward(_ reward: SharedReward) {
        guard store.totalPoints >= reward.cost else { return }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            store.totalPoints -= reward.cost
        }
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            store.claimReward(id: reward.id)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: isPad ? 24 : 10) {

                if isPad {
                    HStack(alignment: .center) {
                        Text("Hi \(childName.isEmpty ? "There" : childName)! 👋")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.black)

                        Spacer()

                        Text("\(store.totalPoints) pts")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color.black.opacity(0.7))
                            .padding(.horizontal, 22)
                            .padding(.vertical, 10)
                            .background(Palette.ptsPill)
                            .clipShape(Capsule())
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: store.totalPoints)
                    }
                    .padding(.top, 24)
                } else {
                    Text("Hi \(childName.isEmpty ? "there" : childName)! 👋")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.top, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(spacing: 6) {
                    TabView(selection: $breakPage) {
                        ForEach(breakMessages.indices, id: \.self) { i in
                            TakeABreakCard(message: breakMessages[i], isPad: isPad).tag(i)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: isPad ? 100 : 84)
                    .onReceive(breakTimer) { _ in
                        withAnimation { breakPage = (breakPage + 1) % breakMessages.count }
                    }
                    PageDots(count: breakMessages.count, current: breakPage, activeColor: .blue)
                }
                .padding(.top, isPad ? 8 : 12)

                // ── To Do ──
                VStack(alignment: .leading, spacing: isPad ? 16 : 8) {
                    SectionHeader(emoji: "📝", title: "To Do", isPad: isPad)

                    if activeTasks.isEmpty {
                        AllDoneCard()
                            .transition(.opacity.combined(with: .scale))
                    } else if isPad {
                        LazyVGrid(columns: gridColumns, spacing: 20) {
                            ForEach(activeTasks) { task in
                                TodoCard(task: task, isPad: isPad) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        store.submitTaskForApproval(id: task.id)
                                    }
                                }
                            }
                        }
                    } else {
                        GeometryReader { geo in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: CardMetrics.cardSpacing) {
                                    ForEach(activeTasks) { task in
                                        TodoCard(task: task, isPad: isPad, cardWidth: taskCardWidth) {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                                store.submitTaskForApproval(id: task.id)
                                            }
                                        }
                                        .id(task.id)
                                    }
                                }
                                .padding(.horizontal, 2)
                                .scrollTargetLayout()
                            }
                            .scrollPosition(id: $currentTaskID)
                            .scrollTargetBehavior(.viewAligned)
                            .modifier(ScrollAtEndModifier(threshold: taskCardWidth / 2) { taskAtEnd = $0 })
                            .onAppear { taskViewportWidth = geo.size.width }
                            .onChange(of: geo.size.width) { _, w in taskViewportWidth = w }
                        }
                        .frame(height: CardMetrics.todoHeight.phone)

                        if activeTasks.count > 1 {
                            PageDots(count: activeTasks.count, current: taskDotIndex, activeColor: .red)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .animation(.easeInOut(duration: 0.2), value: taskDotIndex)
                        }
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: activeTasks.count)

                // ── Rewards ──
                VStack(alignment: .leading, spacing: isPad ? 16 : 8) {
                    HStack {
                        SectionHeader(emoji: "🏆", title: "Rewards", isPad: isPad)
                        Spacer()

                        if !isPad {
                            Text("\(store.totalPoints) pts")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundColor(Color.black.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(Palette.ptsPill)
                                .clipShape(Capsule())
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: store.totalPoints)
                        }
                    }

                    if !sortedRewards.isEmpty {
                        if isPad {
                            LazyVGrid(columns: gridColumns, spacing: 20) {
                                ForEach(sortedRewards) { reward in
                                    RewardCard(
                                        reward:   reward,
                                        unlocked: store.isUnlocked(reward),
                                        isPad:    isPad
                                    ) {
                                        // ✅ النقاط تنقص فورًا وتتحول المكافأة للأخضر دون أن تختفي
                                        childClaimReward(reward)
                                    }
                                }
                            }
                        } else {
                            GeometryReader { geo in
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: CardMetrics.cardSpacing) {
                                        ForEach(sortedRewards) { reward in
                                            RewardCard(
                                                reward:   reward,
                                                unlocked: store.isUnlocked(reward),
                                                isPad:    isPad,
                                                cardWidth: rewardCardWidth
                                            ) {
                                                // ✅ المطالبة بالجائزة وتحويلها للأخضر
                                                childClaimReward(reward)
                                            }
                                            .id(reward.id)
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                    .scrollTargetLayout()
                                }
                                .scrollPosition(id: $currentRewardID)
                                .scrollTargetBehavior(.viewAligned)
                                .modifier(ScrollAtEndModifier(threshold: rewardCardWidth / 2) { rewardAtEnd = $0 })
                                .onAppear { rewardViewportWidth = geo.size.width }
                                .onChange(of: geo.size.width) { _, w in rewardViewportWidth = w }
                            }
                            .frame(height: CardMetrics.rewardHeight.phone)

                            if sortedRewards.count > 1 {
                                PageDots(count: sortedRewards.count, current: rewardDotIndex, activeColor: .blue)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .animation(.easeInOut(duration: 0.2), value: rewardDotIndex)
                            }
                        }
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: sortedRewards.map(\.id))

                Spacer(minLength: isPad ? 16 : 12)

                Button {
                    showParentControl = true
                } label: {
                    HStack(spacing: isPad ? 18 : 14) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: isPad ? 24 : 20))
                            .foregroundColor(.gray)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Parent Control")
                                .font(.system(size: isPad ? 21 : 19, weight: .semibold))
                                .foregroundColor(.black)
                            Text("Manage settings and permissions")
                                .font(.system(size: isPad ? 15 : 14))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding(isPad ? 18 : 14)
                    .background(Palette.parentBG)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, isPad ? 36 : 16)
            .padding(.bottom, isPad ? 36 : 10)
            .frame(maxWidth: .infinity)
        }
        .background(Color.white.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showParentControl) {
            ParentControlFlowView()
                .environmentObject(store)
        }
        .onAppear {
            if currentTaskID == nil { currentTaskID = activeTasks.first?.id }
            if currentRewardID == nil { currentRewardID = sortedRewards.first?.id }
        }
        .refreshable {
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }
}

// MARK: - Subviews

private struct TakeABreakCard: View {
    let message: String
    var isPad: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(Palette.breakBG)
            .overlay(
                Text(message)
                    .font(.system(size: isPad ? 28 : 24, weight: .bold))
                    .foregroundColor(Palette.breakText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .padding(.horizontal, 18)
            )
            .frame(height: isPad ? 96 : 80)
    }
}

private struct SectionHeader: View {
    let emoji: String
    let title: String
    var isPad: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Text(emoji).font(.system(size: isPad ? 28 : 25))
            Text(title)
                .font(.system(size: isPad ? 28 : 25, weight: .bold))
                .foregroundColor(.black)
        }
    }
}

private struct AllDoneCard: View {
    var body: some View {
        HStack(spacing: 14) {
            Text("🎉").font(.system(size: 28))
            Text("All tasks done!")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.black.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(red: 0.92, green: 0.97, blue: 0.92))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct TodoCard: View {
    let task      : SharedTask
    var isPad     : Bool = false
    var cardWidth: CGFloat? = nil
    let onSubmit  : () -> Void

    @State private var pressed = false

    private var cardHeight: CGFloat {
        isPad ? CardMetrics.todoHeight.pad : CardMetrics.todoHeight.phone
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(task.icon).font(.system(size: isPad ? 36 : 34))
                Spacer()

                if task.isPendingApproval {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14))
                        Text("Pending")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.85))
                    .clipShape(Capsule())
                } else {
                    Button {
                        pressed = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { onSubmit() }
                    } label: {
                        Image(systemName: pressed ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 28))
                            .foregroundColor(pressed ? .green : .black.opacity(0.25))
                            .animation(.easeInOut(duration: 0.15), value: pressed)
                    }
                }
            }

            Text(task.title)
                .font(.system(size: isPad ? 22 : 21, weight: .bold))
                .foregroundColor(Palette.taskText)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Text("+\(task.points) pts")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.black.opacity(0.7))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Palette.taskPill)
                .clipShape(Capsule())
        }
        .padding(18)
        .frame(width: isPad ? nil : (cardWidth ?? CardMetrics.phoneWidth))
        .frame(maxWidth: isPad ? .infinity : nil)
        .frame(height: cardHeight, alignment: .topLeading)
        .background(Palette.taskBG)
        .opacity(task.isPendingApproval ? 0.6 : 1.0)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .disabled(task.isPendingApproval)
        .onChange(of: task.isPendingApproval) { _, newValue in
            if !newValue {
                pressed = false
            }
        }
    }
}

private struct RewardCard: View {
    let reward    : SharedReward
    let unlocked  : Bool
    var isPad     : Bool = false
    var cardWidth: CGFloat? = nil
    let onClaim   : () -> Void

    private var cardHeight: CGFloat {
        isPad ? CardMetrics.rewardHeight.pad : CardMetrics.rewardHeight.phone
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(reward.icon).font(.system(size: isPad ? 36 : 34))

            Text(reward.title)
                .font(.system(size: isPad ? 20 : 19, weight: .bold))
                .foregroundColor(.black.opacity(0.75))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            HStack {
                if reward.isClaimed {
                    // ✅ تظهر علامة الصح وتبقى البطاقة باللون الأخضر حتى موافقة الأهل
                    HStack(spacing: 4) {
                        Text("✅")
                            .font(.system(size: 16))
                        Text("Claimed")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.green.opacity(0.85))
                    }
                } else if unlocked {
                    Button(action: onClaim) {
                        Text("Get it")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black.opacity(0.7))
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Palette.getItPill)
                            .clipShape(Capsule())
                    }
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Palette.lockPill)
                        .clipShape(Capsule())
                }
                Spacer(minLength: 4)
                Text("\(reward.cost) pts")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .padding(18)
        .frame(width: isPad ? nil : (cardWidth ?? CardMetrics.phoneWidth))
        .frame(maxWidth: isPad ? .infinity : nil)
        .frame(height: cardHeight, alignment: .topLeading)
        // ✅ إذا كانت المطالبة مفعلة تأخذ اللون الأخضر فوراً، وإلا تأخذ لون الإتاحة
        .background(reward.isClaimed ? Palette.claimedBG : (unlocked ? Palette.iceCreamBG : Palette.legoBG))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

private struct PageDots: View {
    let count        : Int
    let current      : Int
    var activeColor  : Color = .blue

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == current ? activeColor : Color.gray.opacity(0.3))
                    .frame(width: i == current ? 8 : 6, height: i == current ? 8 : 6)
            }
        }
    }
}

#Preview {
    NavigationStack {
        KidsDashboardView()
    }
    .environmentObject(ActivityStore.shared)
}
