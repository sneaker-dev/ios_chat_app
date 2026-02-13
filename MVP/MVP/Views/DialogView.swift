//
//  DialogView.swift
//  MVP
//
//  v3.0: Exact Android DialogScreenM3.kt + SettingsScreen.kt parity.
//  Layout: background image, avatar behind content, semi-transparent top bar,
//  30/70 split, Tap to Speak gradient button, full settings page.

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
    @State private var showSettings = false
    @State private var showTypingIndicator = false

    // Settings (persisted) - matches Android SettingsRepository defaults
    @AppStorage("voiceOutputEnabled") private var voiceOutputEnabled = false          // Android: auto_play_voice = false
    @AppStorage("alwaysVoiceResponse") private var alwaysVoiceResponse = false
    @AppStorage("typingIndicatorEnabled") private var typingIndicatorEnabled = true    // Android: typing_indicator = true
    @AppStorage("genderMatchedVoice") private var genderMatchedVoice = true           // Android: gender_matched_voice = true
    @AppStorage("streamingTextEnabled") private var streamingTextEnabled = true        // Android: streaming_text = true
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false                // Android: dark_mode = false

    @Environment(\.colorScheme) private var colorScheme

    private let maxHistoryCount = 500  // Android: max 500 messages
    private let historyKey = "chatHistory"

    private var dialogLanguage: String { DialogAPIService.getDeviceLanguage() }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack {
                // LAYER 1: Background image (Android: R.drawable.background, ContentScale.Crop, fillMaxSize)
                backgroundLayer

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
        .sheet(isPresented: $showSettings) {
            settingsView
        }
        .preferredColorScheme(darkModeEnabled ? .dark : nil)
    }

    // MARK: - Background (Android: full screen background image)

    private var backgroundLayer: some View {
        Group {
            if UIImage(named: "LoginBackground") != nil {
                Image("LoginBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            } else {
                // Android fallback gradient: #1A1A2E → #0F0F1E
                LinearGradient(
                    colors: [Color(hex: 0x1A1A2E), Color(hex: 0x0F0F1E)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Portrait Layout (Android: avatar background, top bar, 30% spacer, 70% content)

    private func portraitLayout(geometry: GeometryProxy) -> some View {
        ZStack {
            // LAYER 2: Avatar behind content (Android: AvatarGifDisplay fillMaxSize, offset(20, 20))
            AvatarView(avatarType: avatarType, state: avatarState, scale: 1.0)
                .offset(x: 20, y: 20)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // LAYER 3: Content column
            VStack(spacing: 0) {
                // Top bar (Android: Surface with 30% overlay)
                topBar

                // Android: Spacer weight(0.3f) — avatar visible through this area
                Spacer()

                // Android: Column weight(0.7f) — chat + input
                VStack(spacing: 0) {
                    // Messages (Android: Box weight(1f), offset 10.dp)
                    chatSection
                        .offset(x: 10) // Android: offset(x = 10.dp)

                    // Typing indicator
                    if showTypingIndicator && typingIndicatorEnabled {
                        typingIndicatorView
                    }

                    // Input area (Android: offset(10, -5))
                    portraitInputSection
                        .offset(x: 10, y: -5)
                }
                .frame(maxHeight: geometry.size.height * 0.62)

                // Tap to Speak button (Android: SemiCircularSpeakButton, bottom 35.dp)
                speakButton
                    .padding(.bottom, max(10, geometry.safeAreaInsets.bottom + 5))
            }
        }
    }

    // MARK: - Landscape Layout (Android: avatar 54% left, chat right)

    private func landscapeLayout(geometry: GeometryProxy) -> some View {
        ZStack {
            HStack(spacing: 0) {
                // Avatar (Android: fillMaxWidth(0.54f), fillMaxHeight(1.0f), centered)
                ZStack {
                    AvatarView(avatarType: avatarType, state: avatarState, scale: 1.0)
                }
                .frame(width: geometry.size.width * 0.54)
                .clipped()

                // Chat area
                VStack(spacing: 0) {
                    chatSection
                    if showTypingIndicator && typingIndicatorEnabled {
                        typingIndicatorView
                    }
                    landscapeInputSection
                }
            }

            // Top bar overlaid
            VStack {
                topBar
                Spacer()
            }
        }
    }

    // MARK: - Top Bar (Android: Surface 30% overlay, "inango" lowercase, Person + Settings)

    private var topBar: some View {
        HStack {
            // Android: app_title_lowercase = "inango", headlineMedium, Bold, letterSpacing 2.sp
            Text("inango")
                .font(.system(size: 28, weight: .bold))
                .tracking(2)
                .foregroundColor(.white)
                .padding(.leading, 8)

            Spacer()

            // Android: Person icon (change avatar)
            Button {
                NotificationCenter.default.post(name: .changeAvatar, object: nil)
            } label: {
                Image(systemName: "person.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            .padding(.trailing, 8)

            // Android: Settings icon
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            // Android: Color.Black.copy(alpha = 0.3f) dark, Color.White.copy(alpha = 0.3f) light
            colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.3)
        )
    }

    // MARK: - Chat Section (Android: LazyColumn, padding 16.dp horizontal, spacing 16.dp, bottom 85.dp)

    private var chatSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) { // Android: verticalArrangement = 16.dp
                    ForEach(messages) { msg in
                        ChatBubbleView(
                            message: msg,
                            displayedCharacterCount: msg.isFromUser ? nil : (msg.id == typingMessageId ? typingDisplayedCount : nil)
                        )
                    }
                }
                .padding(.horizontal, 16) // Android: padding(horizontal = 16.dp)
                .padding(.top, 16)
                .padding(.bottom, 85) // Android: contentPadding bottom 85.dp
            }
            .onChange(of: messages.count) { _ in scrollToBottom(proxy: proxy) }
            .onChange(of: typingDisplayedCount) { _ in scrollToBottom(proxy: proxy) }
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

    // MARK: - Typing Indicator (Android: 3 dots, 8.dp each, spacedBy 6.dp)

    private var typingIndicatorView: some View {
        HStack(spacing: 6) { // Android: spacedBy(6.dp)
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.gray.opacity(0.7)) // Android: Color.Gray animated alpha
                    .frame(width: 8, height: 8)    // Android: size(8.dp)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: showTypingIndicator
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8) // Android: padding(horizontal = 16.dp, vertical = 8.dp)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Portrait Input Section (Android: TextField + Send, offset above speak button)

    private var portraitInputSection: some View {
        VStack(spacing: 4) {
            // Error banner (Android: ErrorBanner RoundedCornerShape(12.dp))
            if let err = errorMessage {
                errorBanner(err)
            }

            HStack(spacing: 8) {
                // Text field (Android: BasicTextField, RoundedCornerShape(24.dp), heightIn(min=48.dp))
                TextField("Type your message...", text: $inputText) // Android: input_type_message
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.horizontal, 16) // Android: horizontal 16.dp
                    .padding(.vertical, 12)   // Android: vertical 12.dp
                    .frame(minHeight: 48)     // Android: heightIn(min = 48.dp)
                    .foregroundColor(.appTextPrimary)
                    .background(
                        // Android: surface.copy(alpha = 0.7f)
                        Color.appCard.opacity(0.7)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24)) // Android: RoundedCornerShape(24.dp)
                    .onChange(of: inputText) { val in
                        if !val.isEmpty && avatarState == .idle {
                            avatarState = .thinking
                        } else if val.isEmpty && avatarState == .thinking && !stt.isRecording {
                            avatarState = .idle
                        }
                    }

                // Send button (Android: AutoMirrored.Filled.Send)
                Button {
                    wasVoiceInput = false
                    sendMessage(inputText, fromVoice: false)
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 24))
                        .foregroundColor(
                            inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? .gray : .appPrimary
                        )
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding(.horizontal, 16) // Android: padding(horizontal = 16.dp, vertical = 8.dp)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Landscape Input (Android: Row with text + voice + send, padding bottom 15.dp)

    private var landscapeInputSection: some View {
        VStack(spacing: 4) {
            if let err = errorMessage { errorBanner(err) }
            HStack(spacing: 8) { // Android: spacedBy(8.dp)
                TextField("Type your message...", text: $inputText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(minHeight: 48)
                    .foregroundColor(.appTextPrimary)
                    .background(Color.appCard.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .onChange(of: inputText) { val in
                        if !val.isEmpty && avatarState == .idle { avatarState = .thinking }
                        else if val.isEmpty && avatarState == .thinking && !stt.isRecording { avatarState = .idle }
                    }

                // Voice button (landscape: circular)
                Button {
                    if stt.isRecording { stt.stopRecording() }
                    else { startVoiceInput() }
                } label: {
                    Image(systemName: stt.isRecording ? "stop.circle.fill" : "mic.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(stt.isRecording ? Color(hex: 0xB71C1C) : Color(hex: 0xD32F2F))
                        .clipShape(Circle())
                }
                .disabled(isLoading)

                // Send button
                Button {
                    wasVoiceInput = false
                    sendMessage(inputText, fromVoice: false)
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.appPrimary)
                        .frame(width: 48, height: 48)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 15) // Android: padding(bottom = 15.dp)
        }
    }

    // MARK: - Error Banner (Android: ErrorBanner, RoundedCornerShape(12.dp), padding(12.dp))

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.red)
                .lineLimit(2)
            Spacer()
            if lastFailedMessage != nil {
                Button("Dismiss") { // Android: action_dismiss
                    errorMessage = nil
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.appPrimary)
            }
        }
        .padding(12) // Android: 12.dp
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(12) // Android: RoundedCornerShape(12.dp)
        .padding(.horizontal, 16)
    }

    // MARK: - Speak Button (Android: SemiCircularSpeakButton, 234x71dp, RoundedCornerShape(50))

    private var speakButton: some View {
        Button {
            if stt.isRecording {
                stt.stopRecording()
            } else {
                startVoiceInput()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: stt.isRecording ? "stop.circle.fill" : "mic.fill")
                    .font(.system(size: 24)) // Android: size(24.dp)

                Text(stt.isRecording ? "Stop" : "Tap to Speak")
                    .font(.system(size: 20, weight: .bold)) // Android: 20.sp, Bold
            }
            .foregroundColor(.white)
            .frame(width: 234, height: 71) // Android: width(234.dp), height(71.dp)
            .background(
                // Android: gradient normalColor1 → normalColor2 (or active)
                LinearGradient(
                    colors: stt.isRecording
                        ? [Color.speakActive1.opacity(0.9), Color.speakActive2.opacity(0.85)]
                        : [Color.speakNormal1.opacity(0.9), Color.speakNormal2.opacity(0.85)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(Capsule()) // Android: RoundedCornerShape(50)
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
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
        let greetingMsg = ChatMessage(text: greeting, isFromUser: false)
        messages.append(greetingMsg)
        startTypewriter(messageId: greetingMsg.id, fullText: greeting)
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
                } else {
                    avatarState = .idle
                }
            }
        }
    }

    // MARK: - Send Message (matches Android DialogViewModel.sendTextMessage exactly)

    private func sendMessage(_ text: String, fromVoice: Bool, isRetry: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        wasVoiceInput = fromVoice
        if !isRetry {
            inputText = ""
            let userMsg = ChatMessage(text: trimmed, isFromUser: true, wasVoiceInput: fromVoice, language: dialogLanguage)
            messages.append(userMsg)
        }
        errorMessage = nil; lastFailedMessage = nil; isLoading = true
        avatarState = .thinking
        if typingIndicatorEnabled { showTypingIndicator = true }

        Task {
            do {
                let response = try await DialogAPIService.shared.sendMessage(trimmed, language: dialogLanguage)
                await MainActor.run {
                    showTypingIndicator = false
                    let botMsg = ChatMessage(text: response, isFromUser: false, wasVoiceInput: fromVoice, language: dialogLanguage)
                    messages.append(botMsg)
                    isLoading = false

                    // Android logic: voice input → text+voice, text input → text only, "always voice" → always
                    let shouldSpeak = (fromVoice || alwaysVoiceResponse) && voiceOutputEnabled

                    if shouldSpeak {
                        // Word-by-word sync (Android: split by spaces, msPerWord delay)
                        let isFemale = avatarType.isFemale
                        let msPerWord = tts.millisecondsPerWord(isFemale: isFemale)
                        startTypewriter(messageId: botMsg.id, fullText: response, wordByWord: true, msPerWord: msPerWord)
                        avatarState = .speaking
                        let preferMale = genderMatchedVoice ? (avatarType == .male) : nil
                        tts.speak(response, language: dialogLanguage, preferMale: preferMale) {
                            avatarState = .idle
                        }
                    } else {
                        // Text only: character-by-character, avatar speaks silently
                        avatarState = .speaking
                        startTypewriter(messageId: botMsg.id, fullText: response)
                        let charCount = response.count
                        let displayTime = Double(charCount) * 0.025 + 0.5
                        DispatchQueue.main.asyncAfter(deadline: .now() + displayTime) {
                            if avatarState == .speaking { avatarState = .idle }
                        }
                    }
                    saveChatHistory()
                }
            } catch {
                await MainActor.run {
                    showTypingIndicator = false; isLoading = false
                    errorMessage = error.localizedDescription; lastFailedMessage = trimmed
                    avatarState = .idle
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

    // MARK: - Typewriter Effect (Android: word-by-word with TTS, char-by-char without)

    private func startTypewriter(messageId: UUID, fullText: String, wordByWord: Bool = false, msPerWord: Int = 0) {
        typingMessageId = messageId; typingDisplayedCount = 0
        let total = fullText.count
        guard total > 0 else { typingMessageId = nil; return }
        if !streamingTextEnabled { typingDisplayedCount = total; typingMessageId = nil; return }

        if wordByWord && msPerWord > 0 {
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
                typingDisplayedCount = total; typingMessageId = nil
            }
        } else {
            // Android: 25ms per character
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

    // MARK: - Chat History (Android: max 500, in-memory but we persist)

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

    // MARK: - Settings View (Android SettingsScreen.kt parity)

    private var settingsView: some View {
        NavigationView {
            ZStack {
                // Android: background image + 30% black overlay
                if UIImage(named: "LoginBackground") != nil {
                    Image("LoginBackground").resizable().scaledToFill().ignoresSafeArea().allowsHitTesting(false)
                }
                Color.black.opacity(0.3).ignoresSafeArea().allowsHitTesting(false)

                ScrollView {
                    VStack(spacing: 16) { // Android: spacedBy(16.dp)

                        // User Info Card (Android: UserInfoCard)
                        settingsCard {
                            HStack(spacing: 16) {
                                // Android: Circle surface with Person icon (56.dp)
                                Image(systemName: "person.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.appPrimary)
                                    .frame(width: 56, height: 56)
                                    .background(Color.appPrimary.opacity(0.1))
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(KeychainService.shared.getLastEmail()?.components(separatedBy: "@").first ?? "User")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.appTextPrimary)
                                    Text(KeychainService.shared.getLastEmail() ?? "")
                                        .font(.system(size: 14))
                                        .foregroundColor(.appTextSecondary)
                                }
                                Spacer()
                            }
                        }

                        // Preferences Section (Android: PreferencesSection, 5 toggles)
                        settingsCard {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Preferences")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.appPrimary)
                                Spacer().frame(height: 12)

                                settingsToggle(
                                    title: "Voice Output",
                                    description: "Enable voice responses (disable for text-only mode)",
                                    isOn: $voiceOutputEnabled
                                )
                                Divider().padding(.vertical, 8)
                                settingsToggle(
                                    title: "Typing Indicator",
                                    description: "Show when AI is thinking",
                                    isOn: $typingIndicatorEnabled
                                )
                                Divider().padding(.vertical, 8)
                                settingsToggle(
                                    title: "Gender-matched Voice",
                                    description: "Voice matches avatar gender",
                                    isOn: $genderMatchedVoice
                                )
                                Divider().padding(.vertical, 8)
                                settingsToggle(
                                    title: "Streaming Text",
                                    description: "Typewriter effect for responses",
                                    isOn: $streamingTextEnabled
                                )
                                Divider().padding(.vertical, 8)
                                settingsToggle(
                                    title: "Dark Mode",
                                    description: "Use dark theme",
                                    isOn: $darkModeEnabled
                                )
                            }
                        }

                        // Data Management (Android: DataManagementSection)
                        settingsCard {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Data Management")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.appPrimary)
                                Spacer().frame(height: 12)

                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Chat History")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.appTextPrimary)
                                        Text("\(messages.count) messages stored")
                                            .font(.system(size: 12))
                                            .foregroundColor(.appTextSecondary)
                                    }
                                    Spacer()
                                    // Android: Delete icon + "Clear" button, error color
                                    Button {
                                        clearChatHistory()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 14))
                                            Text("Clear")
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        .foregroundColor(.red)
                                    }
                                    .disabled(messages.isEmpty)
                                }
                            }
                        }

                        // About Section (Android: AppInfoSection)
                        settingsCard {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("About")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.appPrimary)
                                Spacer().frame(height: 12)

                                settingsInfoRow(title: "App Name", value: "Inango Chat")
                                Divider().padding(.vertical, 8)
                                settingsInfoRow(title: "Version", value: "v1.0.0")
                                Divider().padding(.vertical, 8)
                                settingsInfoRow(title: "Build", value: "Production")
                                Divider().padding(.vertical, 8)
                                settingsInfoRow(title: "Platform", value: "iOS")
                            }
                        }

                        // Change Avatar button
                        settingsCard {
                            Button {
                                showSettings = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    NotificationCenter.default.post(name: .changeAvatar, object: nil)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.system(size: 18))
                                    Text("Change Avatar")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.appPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        // Logout (Android: LogoutSection, error color, ExitToApp icon)
                        Button {
                            showSettings = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                AuthService.shared.logout()
                                NotificationCenter.default.post(name: .userDidLogout, object: nil)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 18))
                                Text("Logout")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(Color.appCard.opacity(0.95))
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 16)

                        Spacer().frame(height: 32)
                    }
                    .padding(16) // Android: padding(16.dp)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSettings = false
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    }
                }
            }
            .modifier(PrimaryNavBarModifier())
        }
    }

    // MARK: - Settings Helpers (Android card styling)

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading) {
            content()
        }
        .padding(16) // Android: padding(16.dp)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard.opacity(0.95)) // Android: surface.copy(alpha = 0.95f)
        .cornerRadius(16) // Android: RoundedCornerShape(16.dp)
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2) // Android: elevation 4.dp
        .padding(.horizontal, 0)
    }

    private func settingsToggle(title: String, description: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.appTextPrimary)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.appPrimary)
        }
    }

    private func settingsInfoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.appTextPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appTextSecondary)
        }
    }
}

// MARK: - iOS 16+ Navigation Bar Styling

private struct PrimaryNavBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .toolbarBackground(Color.appPrimary, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
        } else {
            content
        }
    }
}
