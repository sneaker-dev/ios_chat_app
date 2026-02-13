//
//  DialogView.swift
//  MVP
//
//  Clean Android-matching dialog screen. No settings page, no avatar selection.
//  Layout: background image → avatar → semi-transparent top bar → chat → speak button

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
    @State private var avatarState: AvatarAnimState = .idle
    @State private var wasVoiceInput = false
    @State private var showTypingIndicator = false
    @State private var showSettings = false

    // Settings (persisted)
    @AppStorage("voiceOutputEnabled") private var voiceOutputEnabled = false
    @AppStorage("alwaysVoiceResponse") private var alwaysVoiceResponse = false
    @AppStorage("typingIndicatorEnabled") private var typingIndicatorEnabled = true
    @AppStorage("genderMatchedVoice") private var genderMatchedVoice = true
    @AppStorage("streamingTextEnabled") private var streamingTextEnabled = true

    private let maxHistoryCount = 500
    private let historyKey = "chatHistory"

    private var dialogLanguage: String { DialogAPIService.getDeviceLanguage() }

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height

            ZStack {
                // LAYER 1: Background image (Android: R.drawable.background, ContentScale.Crop)
                backgroundLayer

                if isLandscape {
                    landscapeLayout(geo: geo)
                } else {
                    portraitLayout(geo: geo)
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .keyboardAvoiding()
        .onAppear {
            loadChatHistory()
            playGreetingIfNeeded()
            setupTTSCallbacks()
        }
        .sheet(isPresented: $showSettings) {
            settingsSheet
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        Group {
            if UIImage(named: "LoginBackground") != nil {
                Image("LoginBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            } else {
                LinearGradient(
                    colors: [Color(hex: 0x1A1A2E), Color(hex: 0x0F0F1E)],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()
            }
        }
    }

    // MARK: - Portrait Layout

    private func portraitLayout(geo: GeometryProxy) -> some View {
        let safeTop = geo.safeAreaInsets.top
        let safeBottom = geo.safeAreaInsets.bottom
        let screenH = geo.size.height + safeTop + safeBottom
        let topBarH: CGFloat = 52
        let speakH: CGFloat = 71 + 16
        let chatH = screenH * 0.62

        return ZStack(alignment: .top) {
            // LAYER 2: Avatar (full area behind content)
            AvatarView(avatarType: avatarType, state: avatarState, scale: 1.0)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // LAYER 3: Content
            VStack(spacing: 0) {
                // Top bar
                topBar
                    .frame(height: topBarH)
                    .padding(.top, safeTop)

                Spacer(minLength: 0)

                // Chat + input
                VStack(spacing: 0) {
                    chatSection

                    if showTypingIndicator && typingIndicatorEnabled {
                        typingIndicatorView
                    }

                    inputRow
                }
                .frame(height: chatH)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.0), Color.black.opacity(0.4), Color.black.opacity(0.6)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                )

                // Speak button
                speakButton
                    .padding(.top, 8)
                    .padding(.bottom, max(safeBottom, 8))
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.6).allowsHitTesting(false))
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Landscape Layout

    private func landscapeLayout(geo: GeometryProxy) -> some View {
        ZStack(alignment: .top) {
            HStack(spacing: 0) {
                // Avatar left 50%
                AvatarView(avatarType: avatarType, state: avatarState, scale: 1.0)
                    .frame(width: geo.size.width * 0.5)
                    .clipped()

                // Chat right 50%
                VStack(spacing: 0) {
                    chatSection

                    if showTypingIndicator && typingIndicatorEnabled {
                        typingIndicatorView
                    }

                    landscapeInputRow
                }
                .background(Color.black.opacity(0.3).allowsHitTesting(false))
            }

            // Top bar overlay
            topBar
        }
    }

    // MARK: - Top Bar (Android: "inango" + Settings icon)

    private var topBar: some View {
        HStack(spacing: 12) {
            Text("inango")
                .font(.system(size: 28, weight: .bold))
                .tracking(2)
                .foregroundColor(.white)

            Spacer()

            // Settings button
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Chat Section

    private var chatSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(messages) { msg in
                        ChatBubbleView(
                            message: msg,
                            displayedCharacterCount: msg.isFromUser ? nil : (msg.id == typingMessageId ? typingDisplayedCount : nil)
                        )
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .onChange(of: messages.count) { _ in scrollToBottom(proxy: proxy) }
            .onChange(of: typingDisplayedCount) { _ in scrollToBottom(proxy: proxy) }
        }
        .frame(maxHeight: .infinity)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = messages.last {
            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }

    // MARK: - Typing Indicator

    private var typingIndicatorView: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .animation(
                        Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(Double(i) * 0.2),
                        value: showTypingIndicator
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Portrait Input Row

    private var inputRow: some View {
        VStack(spacing: 4) {
            if let err = errorMessage {
                errorBanner(err)
            }

            HStack(spacing: 8) {
                // Text field
                TextField("Type your message...", text: $inputText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 15))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(minHeight: 44)
                    .foregroundColor(.white)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .onChange(of: inputText) { val in
                        if !val.isEmpty && avatarState == .idle { avatarState = .thinking }
                        else if val.isEmpty && avatarState == .thinking && !stt.isRecording { avatarState = .idle }
                    }

                // Send button (always visible with primary color)
                Button {
                    wasVoiceInput = false
                    sendMessage(inputText, fromVoice: false)
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.appPrimary)
                        .clipShape(Circle())
                        .opacity(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Landscape Input Row

    private var landscapeInputRow: some View {
        HStack(spacing: 8) {
            TextField("Type your message...", text: $inputText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 15))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .foregroundColor(.white)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .onChange(of: inputText) { val in
                    if !val.isEmpty && avatarState == .idle { avatarState = .thinking }
                    else if val.isEmpty && avatarState == .thinking && !stt.isRecording { avatarState = .idle }
                }

            // Voice
            Button {
                if stt.isRecording { stt.stopRecording() }
                else { startVoiceInput() }
            } label: {
                Image(systemName: stt.isRecording ? "stop.circle.fill" : "mic.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(stt.isRecording ? Color.speakActive1 : Color.speakNormal1)
                    .clipShape(Circle())
            }
            .disabled(isLoading)

            // Send
            Button {
                wasVoiceInput = false
                sendMessage(inputText, fromVoice: false)
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.appPrimary)
                    .clipShape(Circle())
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 13))
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .lineLimit(2)
            Spacer()
            if lastFailedMessage != nil {
                Button("Retry") {
                    retryLastMessage()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.appPrimary)
            }
        }
        .padding(10)
        .background(Color.red.opacity(0.2))
        .cornerRadius(10)
        .padding(.horizontal, 12)
    }

    // MARK: - Speak Button (Android: 234x71dp, RoundedCornerShape(50), dark red gradient)

    private var speakButton: some View {
        Button {
            if stt.isRecording { stt.stopRecording() }
            else { startVoiceInput() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: stt.isRecording ? "stop.circle.fill" : "mic.fill")
                    .font(.system(size: 22))
                Text(stt.isRecording ? "Stop" : "Tap to Speak")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(width: 220, height: 64)
            .background(
                LinearGradient(
                    colors: stt.isRecording
                        ? [Color.speakActive1, Color.speakActive2]
                        : [Color.speakNormal1, Color.speakNormal2],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
        }
        .disabled(isLoading)
    }

    // MARK: - TTS Callbacks

    private func setupTTSCallbacks() {
        tts.onSpeakingStarted = { avatarState = .speaking }
        tts.onSpeakingCompleted = { avatarState = .idle }
    }

    // MARK: - Greeting

    private func playGreetingIfNeeded() {
        guard !hasPlayedGreeting else { return }
        hasPlayedGreeting = true
        let greeting = "Hello! How can I help you today?"
        let msg = ChatMessage(text: greeting, isFromUser: false)
        messages.append(msg)
        startTypewriter(messageId: msg.id, fullText: greeting)
        if voiceOutputEnabled {
            let preferMale = genderMatchedVoice ? (avatarType == .male) : nil
            tts.speak(greeting, language: dialogLanguage, preferMale: preferMale)
        }
    }

    // MARK: - Voice Input

    private func startVoiceInput() {
        errorMessage = nil
        avatarState = .thinking
        wasVoiceInput = true
        stt.requestAuthorization { granted in
            guard granted else {
                errorMessage = stt.errorMessage ?? "Microphone access needed."
                avatarState = .idle; return
            }
            stt.startRecording { text in
                if let text = text, !text.isEmpty {
                    inputText = text
                    sendMessage(text, fromVoice: true)
                } else { avatarState = .idle }
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
            messages.append(ChatMessage(text: trimmed, isFromUser: true, wasVoiceInput: fromVoice, language: dialogLanguage))
        }
        errorMessage = nil; lastFailedMessage = nil; isLoading = true; avatarState = .thinking
        if typingIndicatorEnabled { showTypingIndicator = true }

        Task {
            do {
                let response = try await DialogAPIService.shared.sendMessage(trimmed, language: dialogLanguage)
                await MainActor.run {
                    showTypingIndicator = false
                    let botMsg = ChatMessage(text: response, isFromUser: false, wasVoiceInput: fromVoice, language: dialogLanguage)
                    messages.append(botMsg)
                    isLoading = false
                    let shouldSpeak = (fromVoice || alwaysVoiceResponse) && voiceOutputEnabled
                    if shouldSpeak {
                        let msPerWord = tts.millisecondsPerWord(isFemale: avatarType.isFemale)
                        startTypewriter(messageId: botMsg.id, fullText: response, wordByWord: true, msPerWord: msPerWord)
                        avatarState = .speaking
                        let preferMale = genderMatchedVoice ? (avatarType == .male) : nil
                        tts.speak(response, language: dialogLanguage, preferMale: preferMale) { avatarState = .idle }
                    } else {
                        avatarState = .speaking
                        startTypewriter(messageId: botMsg.id, fullText: response)
                        let displayTime = Double(response.count) * 0.025 + 0.5
                        DispatchQueue.main.asyncAfter(deadline: .now() + displayTime) {
                            if avatarState == .speaking { avatarState = .idle }
                        }
                    }
                    saveChatHistory()
                }
            } catch {
                await MainActor.run {
                    showTypingIndicator = false; isLoading = false
                    errorMessage = error.localizedDescription; lastFailedMessage = trimmed; avatarState = .idle
                    let fallback = ChatMessage(text: "I'm having trouble connecting. Please try again.", isFromUser: false)
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

    // MARK: - Typewriter

    private func startTypewriter(messageId: UUID, fullText: String, wordByWord: Bool = false, msPerWord: Int = 0) {
        typingMessageId = messageId; typingDisplayedCount = 0
        let total = fullText.count
        guard total > 0 else { typingMessageId = nil; return }
        if !streamingTextEnabled { typingDisplayedCount = total; typingMessageId = nil; return }
        if wordByWord && msPerWord > 0 {
            Task { @MainActor in
                let words = fullText.split(separator: " ", omittingEmptySubsequences: false)
                var charCount = 0
                for (i, word) in words.enumerated() {
                    charCount += word.count + (i > 0 ? 1 : 0)
                    typingDisplayedCount = min(charCount, total)
                    if typingMessageId != messageId { return }
                    if i < words.count - 1 { try? await Task.sleep(nanoseconds: UInt64(msPerWord) * 1_000_000) }
                }
                typingDisplayedCount = total; typingMessageId = nil
            }
        } else {
            Task { @MainActor in
                for i in 1...total {
                    try? await Task.sleep(nanoseconds: 25_000_000)
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
        if let data = try? JSONEncoder().encode(toSave) { UserDefaults.standard.set(data, forKey: historyKey) }
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

    // MARK: - Settings Sheet

    private var settingsSheet: some View {
        NavigationView {
            List {
                Section("Voice") {
                    Toggle(isOn: $voiceOutputEnabled) {
                        Label("Voice Output", systemImage: "speaker.wave.2")
                    }
                    .tint(.appPrimary)
                    Toggle(isOn: $alwaysVoiceResponse) {
                        Label("Always Voice Response", systemImage: "waveform")
                    }
                    .tint(.appPrimary)
                    .disabled(!voiceOutputEnabled)
                }

                Section("Display") {
                    Toggle(isOn: $typingIndicatorEnabled) {
                        Label("Typing Indicator", systemImage: "ellipsis.bubble")
                    }
                    .tint(.appPrimary)
                    Toggle(isOn: $streamingTextEnabled) {
                        Label("Streaming Text", systemImage: "text.cursor")
                    }
                    .tint(.appPrimary)
                }

                Section("Chat") {
                    Button(role: .destructive) { clearChatHistory() } label: {
                        Label("Clear Chat History", systemImage: "trash")
                    }
                }

                Section("About") {
                    HStack { Text("App Name"); Spacer(); Text("Inango Chat").foregroundColor(.secondary) }
                    HStack { Text("Version"); Spacer(); Text("v1.0.0").foregroundColor(.secondary) }
                    HStack { Text("Platform"); Spacer(); Text("iOS").foregroundColor(.secondary) }
                }

                Section {
                    Button(role: .destructive) {
                        showSettings = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            AuthService.shared.logout()
                            NotificationCenter.default.post(name: .userDidLogout, object: nil)
                        }
                    } label: {
                        Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showSettings = false }
                        .fontWeight(.semibold)
                        .foregroundColor(.appPrimary)
                }
            }
        }
    }
}
