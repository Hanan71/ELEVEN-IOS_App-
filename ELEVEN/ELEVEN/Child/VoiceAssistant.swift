import SwiftUI
import Speech
import AVFoundation
import Combine

// MARK: - Voice Assistant Manager (مجاني 100% — من الآيفون نفسه + Groq)

final class VoiceAssistantManager: ObservableObject {

    @Published var isListening = false
    @Published var transcript = ""
    @Published var response = ""
    @Published var statusMessage = "Tap the mic and speak"

    var finalHandler: (() -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ar-SA"))
    private let synthesizer = AVSpeechSynthesizer()
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var processed = false

    // ✅ الأذونات
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { speechStatus in
            guard speechStatus == .authorized else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            AVAudioSession.sharedInstance().requestRecordPermission { micAllowed in
                DispatchQueue.main.async { completion(micAllowed) }
            }
        }
    }

   
    func startListening() {
        transcript = ""
        response = ""
        processed = false
        statusMessage = "Listening… speak now 🎙️"

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()
        try? engine.start()
        isListening = true

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.transcript = result.bestTranscription.formattedString
                    if result.isFinal { self?.finalize() }
                }
                if error != nil { self?.finalize() }
            }
        }
    }

   
    func finalize() {
        guard !processed else { return }
        processed = true
        isListening = false
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        statusMessage = "Thinking…"
        finalHandler?()
    }

  
    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        let isArabic = text.range(of: #"[\u0600-\u06FF]"#, options: .regularExpression) != nil
        utterance.voice = AVSpeechSynthesisVoice(language: isArabic ? "ar-SA" : "en-US")
        synthesizer.speak(utterance)
    }

   
    func handleCommand(store: ActivityStore, childName: String) {
        let text = transcript.lowercased()
        guard !text.isEmpty else {
            finish("I didn't hear anything. Try again.")
            return
        }

        
        if text.contains("نقاط") || text.contains("points") || text.contains("point") {
            finish("\(childName) has \(store.totalPoints) points right now.")
            return
        }

       
        if text.contains("وافق") || text.contains("approve") {
            if let pending = store.tasks.first(where: { $0.isPendingApproval }) {
                store.completeTask(id: pending.id)
                finish("Done! I approved \(pending.title) and added \(pending.points) points.")
            } else {
                finish("There are no pending requests right now.")
            }
            return
        }

       
        if text.contains("مهام") || text.contains("tasks") || text.contains("task") {
            let count = store.tasks.filter { !$0.isCompleted }.count
            finish("There are \(count) active tasks on the list.")
            return
        }

      
        askGroq(text)
    }

    private func finish(_ r: String) {
        response = r
        statusMessage = "Tap the mic to speak again"
        speak(r)
    }

   
    private func askGroq(_ question: String) {
        Task {
            do {
                let answer = try await callGroq(question)
                DispatchQueue.main.async { self.finish(answer) }
            } catch {
                DispatchQueue.main.async {
                    self.finish("Sorry, I couldn't connect to the AI right now.")
                }
            }
        }
    }

    private func callGroq(_ question: String) async throws -> String {
        guard let url = URL(string: GeminiConfig.endpoint) else { throw AIError.invalidURL }

        let body: [String: Any] = [
            "model": "llama-3.1-8b-instant",
            "messages": [
                ["role": "system", "content": "You are a friendly parenting assistant inside a screen-time app. Answer in ONE short sentence (max 20 words)."],
                ["role": "user", "content": question]
            ],
            "temperature": 0.8,
            "max_tokens": 100
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(GeminiConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIError.serverError("Groq error")
        }
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let text = message["content"] as? String
        else { throw AIError.invalidResponse }
        return text
    }
}

// MARK: - Assistant Sheet UI

struct AssistantSheet: View {
    @EnvironmentObject private var store: ActivityStore
    @AppStorage("childName") private var childName: String = ""
    @StateObject private var manager = VoiceAssistantManager()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.97, blue: 0.97).ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                    }
                    Spacer()
                    Text("Voice Assistant")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                    Spacer()
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20))
                        .opacity(0)
                }
                .padding(.horizontal)

               
                Button {
                    if manager.isListening {
                        manager.finalize()
                    } else {
                        manager.requestPermissions { ok in
                            if ok {
                                manager.startListening()
                            } else {
                                manager.statusMessage = "Please allow microphone & speech access in Settings."
                            }
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(manager.isListening ? Color.red.opacity(0.85) : Color(red: 0.42, green: 0.62, blue: 0.88))
                            .frame(width: 110, height: 110)
                            .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                        Image(systemName: manager.isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)

                Text(manager.statusMessage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.gray)

                // ✅ كلامك
                if !manager.transcript.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("You said:")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.gray)
                        Text(manager.transcript)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(18)
                }

                
                if !manager.response.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Assistant:")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.gray)
                        Text(manager.response)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Color(red: 0.25, green: 0.35, blue: 0.45))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(red: 0.80, green: 0.87, blue: 0.95))
                    .cornerRadius(18)

                    Button {
                        manager.speak(manager.response)
                    } label: {
                        Label("Repeat answer", systemImage: "speaker.wave.2.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(red: 0.25, green: 0.35, blue: 0.45))
                    }
                }

                Spacer()
            }
            .padding(20)
        }
        .onAppear {
            manager.finalHandler = { [weak manager] in
                manager?.handleCommand(store: store, childName: childName.isEmpty ? "your child" : childName)
            }
        }
    }
}
