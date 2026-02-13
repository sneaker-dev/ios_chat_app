//
//  DialogView.swift
//  MVP
//
//  v2.0: Complete production-ready chat screen matching Android app.
//  Features: Settings sheet, avatar state management, TTS sync,
//  typing indicator, chat history, landscape support, "Tap to Speak"

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

    // Avatar state management
    @State private var avatarState: AvatarAnimState = .idle
    @State private var wasVoiceInput = false

    // UI state
    @State private var showSettings = false
    @State private var showTypingIndicator = false

    // Settings (persisted)
    @AppStorage("alwaysVoiceResponse") private var alwaysVoiceResponse = false
    @AppStorage("voiceOutputEnabled") private var voiceOutputEnabled = true
    @AppStorage("typingIndicatorEnabled") private var typingIndicatorEnabled = true
    @AppStorage("streamingTextEnabled") private var streamingTextEnabled = true

    // Chat history
    private let maxHistoryCount = 500
    private let historyKey = "chatHistory"

    private var dialogLanguage: String {
        DialogAPIService.getDeviceLanguage()
    }

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height

                ZStack {
                    // Background image (subtle)
                    backgroundView

                    if isLandscape {
                        landscapeLayout(geometry: geometry)
                    } else {
                        portraitLayout(geometry: geometry)
                    }
                }
            }
            .keyboardAvoiding()
            .onAppear {
                loadChatHistory()
                playGreetingIfNeeded()
                setupTTSCallbacks()
            }
            .navigationTitle("Inango Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: goBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            NotificationCenter.default.post(name: .changeAvatar, object: nil)
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(
                    voiceOutputEnabled: $voiceOutputEnabled,
                    alwaysVoiceResponse: $alwaysVoiceResponse,
                    typingIndicatorEnabled: $typingIndicatorEnabled,
                    streamingTextEnabled: $streamingTextEnabled,
                    onClearHistory: {
                        clearChatHistory()
                    },
                    onChangeAvatar: {
                        showSettings = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            NotificationCenter.default.post(name: .changeAvatar, object: nil)
                        }
                    }
                )
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Background

    private var backgroundView: some View {
        Group {
            if UIImage(named: "LoginBackground") != nil {
                Image("LoginBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .opacity(0.15)
            }
            Color(.systemGroupedBackground).opacity(0.85)
                .ignoresSafeArea()
        }
    }

    // MARK: - Portrait Layout

    private func portraitLayout(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Avatar area (top 35%)
            avatarSection
                .frame(height: geometry.size.height * 0.35)

            // Chat messages
            chatSection

            // Typing indicator
            if showTypingIndicator {
                typingIndicatorView
            }

            // Input area
            inputSection
        }
    }

    // MARK: - Landscape Layout

    private func landscapeLayout(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Avatar on left (35%)
            avatarSection
                .frame(width: geometry.size.width * 0.35)

            // Chat + input on right
            VStack(spacing: 0) {
                chatSection
                if showTypingIndicator {
                    typingIndicatorView
                }
                inputSection
            }
        }
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        ZStack {
            AvatarBackgroundView(avatarType: avatarType)
                .overlay(Color.black.opacity(0.25))

            AvatarView(avatarType: avatarType, state: avatarState, scale: 1.0)
                .padding(16)

            // State indicator
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    if avatarState != .idle {
                        Text(avatarState == .thinking ? "Thinking..." : "Speaking...")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                            .padding(8)
                    }
                }
            }
        }
        .clipped()
    }

    // MARK: - Chat Section

    private var chatSection: some View {
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
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: typingDisplayedCount) { _ in
                scrollToBottom(proxy: proxy)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = messages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Typing Indicator

    private var typingIndicatorView: some View {
        HStack(spacing: 5) {
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
        VStack(spacing: 8) {
            // Error bar
            if let err = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                    Spacer()
                    if lastFailedMessage != nil {
                        Button("Try again") {
                            retryLastMessage()
                        }
                        .font(.caption.bold())
                        .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(.systemBackground).opacity(0.95))
                .cornerRadius(8)
                .padding(.horizontal, 12)
            }

            // Input row
            HStack(alignment: .bottom, spacing: 10) {
                // Text field
                TextField("Type a message...", text: $inputText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(minHeight: 44)
                    .foregroundColor(.primary)
                    .background(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.primary.opacity(0.25), lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .lineLimit(4)
                    .onChange(of: inputText) { newValue in
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

                // Tap to Speak button
                Button {
                    if stt.isRecording {
                        stt.stopRecording()
                    } else {
                        startVoiceInput()
                    }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: stt.isRecording ? "stop.circle.fill" : "mic.fill")
                            .font(.system(size: 22))
                        Text(stt.isRecording ? "Stop" : "Tap to Speak")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 70, height: 52)
                    .background(
                        stt.isRecording
                            ? Color.red
                            : Color(red: 0.72, green: 0.11, blue: 0.11) // Dark red
                    )
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
                }
                .disabled(isLoading)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .padding(.top, 4)
        .background(
            Color(.systemBackground).opacity(0.95)
                .shadow(color: .black.opacity(0.05), radius: 4, y: -2)
        )
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

    // MARK: - Navigation

    private func goBack() {
        AuthService.shared.logout()
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
    }

    // MARK: - Greeting

    private func playGreetingIfNeeded() {
        guard !hasPlayedGreeting else { return }
        hasPlayedGreeting = true
        let greeting = NSLocalizedString("Hello! How can I help you today?", comment: "Default greeting")
        let greetingMsg = ChatMessage(text: greeting, isFromUser: false)
        messages.append(greetingMsg)
        startTypewriter(messageId: greetingMsg.id, fullText: greeting)

        if voiceOutputEnabled {
            tts.speak(greeting, language: dialogLanguage, preferMale: avatarType == .male)
        }
    }

    // MARK: - Voice Input

    private func startVoiceInput() {
        errorMessage = nil
        avatarState = .thinking
        wasVoiceInput = true

        stt.requestAuthorization { granted in
            guard granted else {
                errorMessage = stt.errorMessage ?? "Microphone access needed. Enable in Settings."
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

        // Avatar state
        avatarState = .thinking

        // Typing indicator
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

                    // TTS behavior:
                    // Voice input → text + voice response
                    // Text input (default) → text only
                    // "Always voice" ON → always play TTS
                    let shouldSpeak = (fromVoice || alwaysVoiceResponse) && voiceOutputEnabled

                    if shouldSpeak {
                        // Word-by-word synchronized with TTS
                        let msPerWord = tts.millisecondsPerWord(isFemale: avatarType.isFemale)
                        startTypewriter(messageId: botMsg.id, fullText: response, wordByWord: true, msPerWord: msPerWord)

                        avatarState = .speaking
                        tts.speak(response, language: dialogLanguage, preferMale: avatarType == .male) {
                            avatarState = .idle
                        }
                    } else {
                        // Fast text display, no voice
                        // Avatar speaks silently (visual only)
                        avatarState = .speaking
                        startTypewriter(messageId: botMsg.id, fullText: response)

                        // Return to idle after text finishes displaying
                        let charCount = response.count
                        let displayTime = Double(charCount) * 0.025 + 0.5
                        DispatchQueue.main.asyncAfter(deadline: .now() + displayTime) {
                            if avatarState == .speaking {
                                avatarState = .idle
                            }
                        }
                    }

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

    // MARK: - Typewriter Effect

    private func startTypewriter(messageId: UUID, fullText: String, wordByWord: Bool = false, msPerWord: Int = 0) {
        typingMessageId = messageId
        typingDisplayedCount = 0
        let total = fullText.count
        guard total > 0 else {
            typingMessageId = nil
            return
        }

        if !streamingTextEnabled {
            // Instant display
            typingDisplayedCount = total
            typingMessageId = nil
            return
        }

        if wordByWord && msPerWord > 0 {
            // Word-by-word synchronized with TTS
            Task { @MainActor in
                let words = fullText.split(separator: " ", omittingEmptySubsequences: false)
                var charCount = 0
                for (index, word) in words.enumerated() {
                    charCount += word.count + (index > 0 ? 1 : 0)
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
            // Character-by-character (fast mode)
            Task { @MainActor in
                for i in 1...total {
                    try? await Task.sleep(nanoseconds: 25_000_000) // 25ms
                    if typingMessageId != messageId { return }
                    typingDisplayedCount = i
                }
                typingMessageId = nil
            }
        }
    }

    // MARK: - Chat History

    private func saveChatHistory() {
        let toSave = Array(messages.suffix(maxHistoryCount))
        if let data = try? JSONEncoder().encode(toSave) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    private func loadChatHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let saved = try? JSONDecoder().decode([ChatMessage].self, from: data) else { return }
        messages = saved
    }

    private func clearChatHistory() {
        messages.removeAll()
        UserDefaults.standard.removeObject(forKey: historyKey)
        hasPlayedGreeting = false
        playGreetingIfNeeded()
    }
}

// MARK: - Settings Sheet (embedded, no pbxproj changes needed)

struct SettingsSheet: View {
    @Binding var voiceOutputEnabled: Bool
    @Binding var alwaysVoiceResponse: Bool
    @Binding var typingIndicatorEnabled: Bool
    @Binding var streamingTextEnabled: Bool
    var onClearHistory: () -> Void
    var onChangeAvatar: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                // Voice Settings
                Section {
                    Toggle(isOn: $voiceOutputEnabled) {
                        Label("Voice Output", systemImage: "speaker.wave.2")
                    }
                    Toggle(isOn: $alwaysVoiceResponse) {
                        Label("Always Voice Response", systemImage: "waveform")
                    }
                    .disabled(!voiceOutputEnabled)
                } header: {
                    Text("Voice")
                } footer: {
                    Text("When disabled, voice responses only play for voice input. Enable 'Always Voice Response' to hear responses for text input too.")
                }

                // Display Settings
                Section {
                    Toggle(isOn: $typingIndicatorEnabled) {
                        Label("Typing Indicator", systemImage: "ellipsis.bubble")
                    }
                    Toggle(isOn: $streamingTextEnabled) {
                        Label("Streaming Text", systemImage: "text.cursor")
                    }
                } header: {
                    Text("Display")
                } footer: {
                    Text("Streaming text shows responses word by word. When disabled, the full response appears instantly.")
                }

                // Avatar
                Section("Avatar") {
                    Button {
                        onChangeAvatar()
                    } label: {
                        Label("Change Avatar", systemImage: "person.crop.circle.badge.plus")
                    }
                }

                // Chat
                Section("Chat") {
                    Button(role: .destructive) {
                        onClearHistory()
                    } label: {
                        Label("Clear Chat History", systemImage: "trash")
                    }
                }

                // About
                Section("About") {
                    HStack {
                        Label("App Name", systemImage: "app")
                        Spacer()
                        Text("Inango Chat")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("v1.0.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Label("Platform", systemImage: "iphone")
                        Spacer()
                        Text("iOS")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
