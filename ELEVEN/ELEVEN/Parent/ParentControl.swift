//
//  ParentControl.swift
//  ScreenBuddy
//

import SwiftUI
import AudioToolbox

struct ParentControlFlowView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @AppStorage("parentControlCode") private var savedCode: String = ""
    @AppStorage("parentSecurityQuestion") private var savedSecurityQuestion: String = ""
    @AppStorage("parentSecurityAnswer") private var savedSecurityAnswer: String = ""

    @State private var step         : Step  = .enter
    @State private var firstCode           = ""
    @State private var code                = ""
    @State private var statusColor : Color = .customBlue
    @State private var isSecure            = true
    @State private var goToPDashboard      = false

    // Security Question Sheets / Alerts
    @State private var showSetupSecurity = false
    @State private var tempQuestion = ""
    @State private var tempAnswer = ""

    @State private var showAnswerSecurity = false
    @State private var enteredAnswer = ""
    @State private var answerError = false

    private let codeLength = 4

    private var isPad: Bool {
        horizontalSizeClass == .regular
    }

    // MARK: Step enum
    enum Step {
        case enter      // First-time setup: enter new password
        case reenter    // Confirm the new password
        case verify     // Password exists — user must prove they know it
        case verified   // Password matched successfully — show options
    }

    private var pillColor: Color {
        statusColor.opacity(0.18)
    }

    // MARK: Body
    var body: some View {
        VStack(spacing: 0) {

            // Top Navigation Bar
            HStack {
                Button {
                    switch step {
                    case .reenter:
                        step = .enter; code = ""; firstCode = ""; statusColor = .customBlue
                    default:
                        dismiss()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: isPad ? 26 : 22, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: isPad ? 54 : 44, height: isPad ? 54 : 44)
                }
                Spacer()
            }
            .padding(.horizontal, isPad ? 40 : 24)
            .padding(.top, isPad ? 24 : 16)

            if isPad {
                // MARK: iPad Layout (Side-by-Side Dual Pane)
                HStack(alignment: .center, spacing: 60) {
                    
                    // Left Hero Card
                    VStack(alignment: .leading, spacing: 20) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 64))
                            .foregroundColor(statusColor)
                            .animation(.easeInOut(duration: 0.25), value: statusColor)
                        
                        Text("Parent Control")
                            .font(.system(size: 40, weight: .heavy))
                            .foregroundColor(.black)

                        Text(instructionDescription)
                            .font(.system(size: 18))
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)

                        Divider().padding(.vertical, 8)

                        // Toggle Show/Hide Password
                        Button { isSecure.toggle() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isSecure ? "eye" : "eye.slash")
                                Text(isSecure ? "Show password" : "Hide password")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                        }

                        // Forgot Password
                        if step == .verify {
                            Button(action: handleForgotPassword) {
                                Text("Forgot password?")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(36)
                    .frame(maxWidth: 380, alignment: .leading)
                    .background(Color.gray.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 32))

                    // Right Keypad Pane
                    VStack(spacing: 28) {
                        if step == .verified {
                            verifiedView
                        } else {
                            Text(labelText)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.black.opacity(0.8))

                            pinDotsView

                            customKeypad
                        }
                    }
                    .frame(maxWidth: 420)
                }
                .padding(.horizontal, 40)
                .frame(maxHeight: .infinity)

            } else {
                // MARK: iPhone Layout (Stacked)
                VStack(spacing: 0) {
                    Text("Parent Control")
                        .font(.system(size: 32, weight: .heavy))
                        .foregroundColor(.gray)
                        .padding(.vertical, 18)
                        .padding(.horizontal, 28)
                        .background(pillColor)
                        .clipShape(RoundedRectangle(cornerRadius: 35))
                        .padding(.top, 10)
                        .animation(.easeInOut(duration: 0.25), value: statusColor)

                    if step == .verified {
                        verifiedView
                    } else {
                        pinEntryView
                    }

                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .ignoresSafeArea(edges: .bottom)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            step = savedCode.isEmpty ? .enter : .verify
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                code = ""
                goToPDashboard = false
                dismiss()
            }
        }
        .navigationDestination(isPresented: $goToPDashboard) {
            Dashboard()
        }
        // Sheet: Setup security question for the first time
        .sheet(isPresented: $showSetupSecurity) {
            NavigationStack {
                Form {
                    Section {
                        TextField("e.g. My first car", text: $tempQuestion)
                    } header: {
                        Text("Security Question")
                    } footer: {
                        Text("Choose a question only you know the answer to.")
                    }

                    Section {
                        TextField("Answer", text: $tempAnswer)
                    } header: {
                        Text("Your Secret Answer")
                    }
                }
                .navigationTitle("Set Security Question")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            savedSecurityQuestion = tempQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
                            savedSecurityAnswer = tempAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
                            showSetupSecurity = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                goToPDashboard = true
                            }
                        }
                        .disabled(tempQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  tempAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        // Sheet: Answer security question on forgot password
        .sheet(isPresented: $showAnswerSecurity) {
            NavigationStack {
                Form {
                    Section {
                        Text(savedSecurityQuestion.isEmpty ? "What is your secret answer?" : savedSecurityQuestion)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black.opacity(0.8))
                    } header: {
                        Text("Security Question")
                    }

                    Section {
                        TextField("Enter your answer", text: $enteredAnswer)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        
                        if answerError {
                            Text("Incorrect answer. Please try again.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    } header: {
                        Text("Answer")
                    }
                }
                .navigationTitle("Verification")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showAnswerSecurity = false
                            enteredAnswer = ""
                            answerError = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Verify") {
                            let cleanEntered = enteredAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                            let cleanSaved = savedSecurityAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                            
                            if cleanEntered == cleanSaved {
                                showAnswerSecurity = false
                                enteredAnswer = ""
                                answerError = false
                                resetAndEnterNewCode()
                            } else {
                                answerError = true
                            }
                        }
                        .disabled(enteredAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Subviews

    private var pinDotsView: some View {
        HStack(spacing: isPad ? 24 : 20) {
            ForEach(0..<codeLength, id: \.self) { index in
                let filled = index < code.count
                ZStack {
                    Circle()
                        .fill(filled ? statusColor : Color.gray.opacity(0.3))
                        .frame(width: isPad ? 58 : 50, height: isPad ? 58 : 50)

                    if filled && !isSecure {
                        let charIndex = code.index(code.startIndex, offsetBy: index)
                        Text(String(code[charIndex]))
                            .font(.system(size: isPad ? 28 : 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: filled)
                .animation(.easeInOut(duration: 0.25), value: statusColor)
            }
        }
    }

    private var pinEntryView: some View {
        VStack(spacing: 0) {
            Text(labelText)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.black.opacity(0.7))
                .padding(.top, 24)

            pinDotsView
                .padding(.top, 24)

            Button { isSecure.toggle() } label: {
                HStack(spacing: 6) {
                    Image(systemName: isSecure ? "eye" : "eye.slash")
                    Text(isSecure ? "Show password" : "Hide password")
                }
                .font(.system(size: 15))
                .foregroundColor(.gray)
            }
            .padding(.top, 16)

            if step == .verify {
                Button(action: handleForgotPassword) {
                    Text("Forgot password?")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.top, 12)
            }

            Spacer(minLength: 20)

            customKeypad
                .padding(.bottom, 20)
        }
    }

    // MARK: - Keypad Component

    private var customKeypad: some View {
        let buttonSize: CGFloat = isPad ? 85 : 75
        let spacing: CGFloat = isPad ? 20 : 16

        let columns = [
            GridItem(.fixed(buttonSize)),
            GridItem(.fixed(buttonSize)),
            GridItem(.fixed(buttonSize))
        ]

        return LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(1...9, id: \.self) { num in
                keypadButton(number: "\(num)", size: buttonSize)
            }

            Color.clear.frame(width: buttonSize, height: buttonSize)

            keypadButton(number: "0", size: buttonSize)

            Button(action: deleteDigit) {
                ZStack {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: buttonSize, height: buttonSize)
                    Image(systemName: "delete.left.fill")
                        .font(.system(size: isPad ? 28 : 24))
                        .foregroundColor(.black.opacity(0.7))
                }
            }
        }
    }

    private func keypadButton(number: String, size: CGFloat) -> some View {
        Button {
            appendDigit(number)
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: size, height: size)
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)

                Text(number)
                    .font(.system(size: isPad ? 32 : 30, weight: .medium))
                    .foregroundColor(.black)
            }
        }
    }

    // MARK: - Verified View

    private var verifiedView: some View {
        VStack(spacing: 28) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: isPad ? 80 : 68))
                .foregroundColor(.blue)
                .padding(.top, isPad ? 20 : 44)

            Text("Access granted")
                .font(.system(size: isPad ? 28 : 26, weight: .semibold))
                .foregroundColor(.black.opacity(0.7))

            VStack(spacing: 14) {
                Button {
                    goToPDashboard = true
                } label: {
                    Text("Continue")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                }
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Actions & Logic

    private func appendDigit(_ digit: String) {
        guard code.count < codeLength else { return }
        AudioServicesPlaySystemSound(1104)
        code.append(digit)
        if code.count == codeLength {
            handleCompletedEntry()
        }
    }

    private func deleteDigit() {
        guard !code.isEmpty else { return }
        AudioServicesPlaySystemSound(1155)
        code.removeLast()
    }

    private var labelText: String {
        switch step {
        case .enter:    return "Enter new password"
        case .reenter:  return "Re-enter to confirm"
        case .verify:   return "Enter your password"
        case .verified: return ""
        }
    }

    private var instructionDescription: String {
        switch step {
        case .enter:
            return "Create a secure 4-digit PIN to restrict changes and manage dashboard activities."
        case .reenter:
            return "Please re-type the exact same PIN to ensure you remember it accurately."
        case .verify:
            return "Authentication required. Enter your 4-digit PIN to access parent settings."
        case .verified:
            return "Identity verified successfully. You can now proceed to the dashboard."
        }
    }

    private func handleCompletedEntry() {
        switch step {

        case .enter:
            firstCode = code
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                code = ""; step = .reenter
            }

        case .reenter:
            if code == firstCode {
                savedCode   = code
                statusColor = .blue
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    if savedSecurityQuestion.isEmpty || savedSecurityAnswer.isEmpty {
                        showSetupSecurity = true
                    } else {
                        goToPDashboard = true
                    }
                }
            } else {
                statusColor = .orange
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    code = ""; firstCode = ""; step = .enter; statusColor = .customBlue
                }
            }

        case .verify:
            if code == savedCode {
                statusColor = .blue
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    code = ""; step = .verified
                    goToPDashboard = true
                }
            } else {
                statusColor = .orange
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    code = ""; statusColor = .customBlue
                }
            }

        case .verified:
            break
        }
    }

    private func handleForgotPassword() {
        if savedSecurityQuestion.isEmpty || savedSecurityAnswer.isEmpty {
            resetAndEnterNewCode()
        } else {
            showAnswerSecurity = true
        }
    }

    private func resetAndEnterNewCode() {
        savedCode   = ""
        code        = ""
        firstCode   = ""
        statusColor = .customBlue
        step        = .enter
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ParentControlFlowView()
    }
    .environmentObject(ActivityStore.shared)
}
