//
//  DialogView.swift
//  MVP
//
//  v2.0: Enhanced with Android-matching features:
//  - Voice input → response in text + voice (avatar speaks)
//  - Text input → response in text only (avatar stays idle)
//  - Config option "Always use voice response"
//  - Avatar state management (IDLE → THINKING → SPEAKING)
//  - Word-by-word TTS text synchronization
//  - Female voice rate adjustment
//  - Locale normalization (Hebrew/Ukrainian fix)
//  - Typing indicator
//  - Chat history persistence

import SwiftUI

struct DialogView: View {
    let avatarType: AvatarType
    @StateObject private var stt = SpeechToTextService()
    @StateObject private var tts = TextToSpeechService()
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastFailedMessage: String?
    @State private var hasPlayedGreeting = false
    @State private var typingMessageId: UUID?
    @State private var typingDisplayedCount: Int = 0
    
    // v2.0: Avatar state management
    @State private var avatarState: AvatarAnimState = .idle
    
    // v2.0: Track input method for TTS decision
    @State private var wasVoiceInput = false
    
    // v2.0: Settings (will be moved to SettingsManager later)
    @AppStorage("alwaysVoiceResponse") private var alwaysVoiceResponse = false
    @AppStorage("voiceOutputEnabled") private var voiceOutputEnabled = true
    @AppStorage("typingIndicatorEnabled") private var typingIndicatorEnabled = true
    @AppStorage("streamingTextEnabled") private var streamingTextEnabled = true
    
    // v2.0: Typing indicator
    @State private var showTypingIndicator = false
    
    // v2.0: Chat history persistence
    private let maxHistoryCount = 500
    private let historyKey = "chatHistory"

    private var dialogLanguage: String {
        DialogAPIService.getDeviceLanguage()
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Avatar + Chat
                chatSection

                // Typing indicator
                if showTypingIndicator {
                    typingIndicatorView
                }
                
                // Input + Mic
                inputSection
            }
            .keyboardAvoiding()
            .background(Color(.systemGroupedBackground))
            .onAppear {
                loadChatHistory()
                playGreetingIfNeeded()
                setupTTSCallbacks()
            }
            .navigationTitle("Inango Chat")
            .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: goBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - TTS Callbacks
    
    private func setupTTSCallbacks() {
        tts.onSpeakingStarted = {
            avatarState = .speaking
        }
        tts.onSpeakingCompleted = {
            avatarState = .idle
        }
    }

    private func goBack() {
        AuthService.shared.logout()
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
    }

    // MARK: - Chat Section
    
    private var chatSection: some View {
        ZStack {
            AvatarBackgroundView(avatarType: avatarType)
                .overlay(Color.black.opacity(0.35))
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(messages) { msg in
                            ChatBubbleView(
                                message: msg,
                                displayedCharacterCount: msg.isFromUser ? nil : (msg.id == typingMessageId ? typingDisplayedCount : nil)
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Typing Indicator
    
    private var typingIndicatorView: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .opacity(showTypingIndicator ? 1 : 0.3)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: showTypingIndicator
                    )
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    // MARK: - Input Section
    
    private var inputSection: some View {
        VStack(spacing: 0) {
            if let err = errorMessage {
                HStack(spacing: 8) {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                    if lastFailedMessage != nil {
                        Button("Try again") {
                            retryLastMessage()
                        }
                        .font(.caption.bold())
                    }
                }
                .padding(4)
                .frame(maxWidth: .infinity)
            }
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Type a message...", text: $inputText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(minHeight: 48)
                    .foregroundColor(.primary)
                    .background(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.primary.opacity(0.3), lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .lineLimit(4)
                    .onChange(of: inputText) { newValue in
                        // v2.0: Switch to THINKING mode when typing starts
                        if !newValue.isEmpty && avatarState == .idle {
                            avatarState = .thinking
                        } else if newValue.isEmpty && avatarState == .thinking && !stt.isRecording {
                            avatarState = .idle
                        }
                    }

                // Send button
                Button {
                    wasVoiceInput = false
                    sendMessage(inputText, fromVoice: false)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .accentColor)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)

                // Mic button
                Button {
                    if stt.isRecording {
                        stt.stopRecording()
                    } else {
                        startVoiceInput()
                    }
                } label: {
                    Image(systemName: stt.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(stt.isRecording ? .red : Color(red: 0.72, green: 0.11, blue: 0.11)) // Dark red
                }
                .disabled(isLoading)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
    }

    // MARK: - Greeting
    
    private func playGreetingIfNeeded() {
        guard !hasPlayedGreeting else { return }
        hasPlayedGreeting = true
        let greeting = NSLocalizedString("Hello! How can I help you today?", comment: "Default greeting")
        let greetingMsg = ChatMessage(text: greeting, isFromUser: false)
        messages.append(greetingMsg)
        startTypewriter(messageId: greetingMsg.id, fullText: greeting)
        
        // Play greeting with voice
        if voiceOutputEnabled {
            tts.speak(greeting, language: dialogLanguage, preferMale: avatarType == .male)
        }
    }

    // MARK: - Typewriter Effect
    
    private func startTypewriter(messageId: UUID, fullText: String, wordByWord: Bool = false, msPerWord: Int = 0) {
        typingMessageId = messageId
        typingDisplayedCount = 0
        let total = fullText.count
        guard total > 0 else {
            typingMessageId = nil
            return
        }
        
        if wordByWord && msPerWord > 0 {
            // v2.0: Word-by-word synchronized with TTS
            Task { @MainActor in
                let words = fullText.split(separator: " ", omittingEmptySubsequences: false)
                var charCount = 0
                for (index, word) in words.enumerated() {
                    charCount += word.count + (index > 0 ? 1 : 0) // +1 for space
                    typingDisplayedCount = min(charCount, total)
                    if typingMessageId != messageId { return }
                    if index < words.count - 1 {
                        try? await Task.sleep(nanoseconds: UInt64(msPerWord) * 1_000_000)
                    }
                }
                typingDisplayedCount = total
                typingMessageId = nil
            }
        } else {
            // Character-by-character (fast mode for text-only)
            Task { @MainActor in
                for i in 1...total {
                    try? await Task.sleep(nanoseconds: 25_000_000) // 25ms per character
                    if typingMessageId != messageId { return }
                    typingDisplayedCount = i
                }
                typingMessageId = nil
            }
        }
    }

    // MARK: - Voice Input
    
    private func startVoiceInput() {
        errorMessage = nil
        
        // v2.0: Set THINKING state immediately when user presses speak
        avatarState = .thinking
        wasVoiceInput = true
        
        stt.requestAuthorization { granted in
            guard granted else {
                errorMessage = stt.errorMessage ?? "Microphone access needed"
                avatarState = .idle
                return
            }
            stt.startRecording { text in
                if let text = text, !text.isEmpty {
                    inputText = text
                    sendMessage(text, fromVoice: true)
                } else {
                    avatarState = .idle
                }
            }
        }
    }

    // MARK: - Send Message
    
    private func sendMessage(_ text: String, fromVoice: Bool, isRetry: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        wasVoiceInput = fromVoice
        
        if !isRetry {
            inputText = ""
            let userMsg = ChatMessage(text: trimmed, isFromUser: true, wasVoiceInput: fromVoice, language: dialogLanguage)
            messages.append(userMsg)
        }
        errorMessage = nil
        lastFailedMessage = nil
        isLoading = true
        
        // v2.0: Avatar state based on input method
        let shouldPlayTTS = fromVoice || alwaysVoiceResponse
        if shouldPlayTTS {
            avatarState = .thinking
        }
        
        // Show typing indicator
        if typingIndicatorEnabled {
            showTypingIndicator = true
        }

        Task {
            do {
                let response = try await DialogAPIService.shared.sendMessage(trimmed, language: dialogLanguage)
                await MainActor.run {
                    showTypingIndicator = false
                    
                    let botMsg = ChatMessage(text: response, isFromUser: false, wasVoiceInput: fromVoice, language: dialogLanguage)
                    messages.append(botMsg)
                    isLoading = false
                    
                    // v2.0: TTS behavior based on input method
                    // Voice input → response in text + voice (avatar speaks)
                    // Text input (default) → response in text only
                    // "Always voice" ON → always play TTS
                    let shouldSpeak = (fromVoice || alwaysVoiceResponse) && voiceOutputEnabled
                    
                    if shouldSpeak {
                        // Word-by-word synchronized with TTS
                        let msPerWord = tts.millisecondsPerWord(isFemale: avatarType.isFemale)
                        startTypewriter(messageId: botMsg.id, fullText: response, wordByWord: true, msPerWord: msPerWord)
                        
                        // Start TTS (avatar state managed by callbacks)
                        avatarState = .speaking
                        tts.speak(response, language: dialogLanguage, preferMale: avatarType == .male) {
                            // TTS completed
                            avatarState = .idle
                        }
                    } else {
                        // Fast text display, no voice
                        startTypewriter(messageId: botMsg.id, fullText: response)
                        avatarState = .idle
                    }
                    
                    // Persist chat history
                    saveChatHistory()
                }
            } catch {
                await MainActor.run {
                    showTypingIndicator = false
                    isLoading = false
                    errorMessage = error.localizedDescription
                    lastFailedMessage = trimmed
                    avatarState = .idle
                    
                    let fallback = ChatMessage(
                        text: "The voice server didn't respond. This is usually temporary—tap \"Try again\" below or send another message.",
                        isFromUser: false
                    )
                    messages.append(fallback)
                    startTypewriter(messageId: fallback.id, fullText: fallback.text)
                    
                    saveChatHistory()
                }
            }
        }
    }

    private func retryLastMessage() {
        guard let text = lastFailedMessage else { return }
        sendMessage(text, fromVoice: wasVoiceInput, isRetry: true)
    }
    
    // MARK: - Chat History Persistence
    
    private func saveChatHistory() {
        // Keep only last N messages
        let messagesToSave = Array(messages.suffix(maxHistoryCount))
        if let data = try? JSONEncoder().encode(messagesToSave) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
    
    private func loadChatHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let saved = try? JSONDecoder().decode([ChatMessage].self, from: data) else { return }
        messages = saved
    }
}
