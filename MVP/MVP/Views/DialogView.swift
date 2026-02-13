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

    @AppStorage("voiceOutputEnabled") private var voiceOutputEnabled = false
    @AppStorage("alwaysVoiceResponse") private var alwaysVoiceResponse = false
    @AppStorage("typingIndicatorEnabled") private var typingIndicatorEnabled = true
    @AppStorage("genderMatchedVoice") private var genderMatchedVoice = true
    @AppStorage("streamingTextEnabled") private var streamingTextEnabled = true
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("showSoftwareKeyboard") private var showSoftwareKeyboard = true

    private let maxHistoryCount = 500
    private let historyKey = "chatHistory"

    private var dialogLanguage: String { DialogAPIService.getDeviceLanguage() }

    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        let screenW = UIScreen.main.bounds.width
        let screenH = UIScreen.main.bounds.height

        ZStack {
            Color.black.ignoresSafeArea()

            if UIImage(named: "LoginBackground") != nil {
                Image("LoginBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: screenW, height: screenH)
                    .clipped()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            GeometryReader { geo in
                let isLandscape = geo.size.width > geo.size.height

                if isLandscape {
                    landscapeLayout(geo: geo)
                } else {
                    portraitLayout(geo: geo)
                }
            }
        }
        .ignoresSafeArea()
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { n in
            guard showSoftwareKeyboard else { return }
            guard let f = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            withAnimation(.easeOut(duration: 0.25)) { keyboardHeight = f.height }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { keyboardHeight = 0 }
        }
        .onAppear {
            loadChatHistory()
            playGreetingIfNeeded()
            setupTTSCallbacks()
        }
        .onChange(of: showSoftwareKeyboard) { newValue in
            if !newValue {
                withAnimation(.easeOut(duration: 0.25)) { keyboardHeight = 0 }
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .sheet(isPresented: $showSettings) {
            settingsSheet
        }
    }

    private func portraitLayout(geo: GeometryProxy) -> some View {
        let windowTop = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 59
        let windowBottom = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 34
        let screenW = UIScreen.main.bounds.width
        let screenH = UIScreen.main.bounds.height
        let topBarH: CGFloat = 52
        let keyboardUp = keyboardHeight > 0 && showSoftwareKeyboard

        let topBarBottom = windowTop + 6 + topBarH
        let bottomH: CGFloat
        if keyboardUp {
            bottomH = max(screenH - topBarBottom - keyboardHeight - 10, 220)
        } else {
            bottomH = screenH * 0.55
        }

        return ZStack {
            AvatarView(avatarType: avatarType, state: avatarState, scale: 1.0)
                .frame(width: screenW, height: screenH)
                .clipped()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                    .frame(height: topBarH)
                    .padding(.top, windowTop + 6)
                Spacer()
            }

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 0) {
                    chatSection

                    if showTypingIndicator && typingIndicatorEnabled {
                        typingIndicatorView
                    }

                    inputRow

                    speakButton
                        .padding(.top, 6)
                        .padding(.bottom, keyboardUp ? 6 : max(windowBottom - 22, 6))
                        .frame(maxWidth: .infinity)
                }
                .frame(height: bottomH)
            }
            .padding(.bottom, keyboardUp ? keyboardHeight : 0)
        }
    }

    private func landscapeLayout(geo: GeometryProxy) -> some View {
        ZStack(alignment: .top) {
            HStack(spacing: 0) {
                AvatarView(avatarType: avatarType, state: avatarState, scale: 1.0)
                    .frame(width: geo.size.width * 0.5)
                    .clipped()

                VStack(spacing: 0) {
                    chatSection

                    if showTypingIndicator && typingIndicatorEnabled {
                        typingIndicatorView
                    }

                    landscapeInputRow
                }
                .background(Color.black.opacity(0.3).allowsHitTesting(false))
            }

            topBar
        }
    }

    private var topBar: some View {
        HStack(spacing: 4) {
            Text("inango")
                .font(.system(size: 28, weight: .bold))
                .tracking(2)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)

            Spacer()

            Button {
                NotificationCenter.default.post(name: .changeAvatar, object: nil)
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
            }

            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
            }
        }
        .padding(.horizontal, 16)
        .background(Color.black.opacity(0.55))
    }

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

    private var inputRow: some View {
        VStack(spacing: 4) {
            if let err = errorMessage {
                errorBanner(err)
            }

            HStack(spacing: 8) {
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

    private func setupTTSCallbacks() {
        tts.onSpeakingStarted = { avatarState = .speaking }
        tts.onSpeakingCompleted = { avatarState = .idle }
    }

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

    private var settingsSheet: some View {
        NavigationView {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.appPrimary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(KeychainService.shared.getLastEmail() ?? "User")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Free Plan")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("Preferences")) {
                    settingsToggle(icon: "speaker.wave.2", title: "Voice Output", description: "Enable voice responses", isOn: $voiceOutputEnabled)
                    settingsToggle(icon: "waveform", title: "Always Voice Response", description: "Voice response for all messages", isOn: $alwaysVoiceResponse)
                        .disabled(!voiceOutputEnabled)
                        .opacity(voiceOutputEnabled ? 1.0 : 0.5)
                    settingsToggle(icon: "ellipsis.bubble", title: "Typing Indicator", description: "Show when AI is thinking", isOn: $typingIndicatorEnabled)
                    settingsToggle(icon: "person.wave.2", title: "Gender-matched Voice", description: "Voice matches avatar gender", isOn: $genderMatchedVoice)
                    settingsToggle(icon: "text.cursor", title: "Streaming Text", description: "Typewriter effect for responses", isOn: $streamingTextEnabled)
                    settingsToggle(icon: "moon.fill", title: "Dark Mode", description: "Use dark theme", isOn: $darkModeEnabled)
                    settingsToggle(icon: "keyboard", title: "Show Keyboard", description: "Show on-screen keyboard when typing", isOn: $showSoftwareKeyboard)
                }

                Section(header: Text("Data Management")) {
                    HStack {
                        Label("Chat History", systemImage: "clock.arrow.circlepath")
                        Spacer()
                        Text("\(messages.count) messages")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    Button(role: .destructive) { clearChatHistory() } label: {
                        Label("Clear Chat History", systemImage: "trash")
                    }
                    .disabled(messages.isEmpty)
                }

                Section(header: Text("App Info")) {
                    settingsInfoRow(label: "App Name", value: "Inango Chat")
                    settingsInfoRow(label: "Version", value: "v1.0.0")
                    settingsInfoRow(label: "Build", value: "Production")
                    settingsInfoRow(label: "Platform", value: "iOS")
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
                    Button(action: { showSettings = false }) {
                        Text("Done").font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.appPrimary)
                }
            }
            .preferredColorScheme(darkModeEnabled ? .dark : .light)
        }
    }

    private func settingsToggle(icon: String, title: String, description: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.appPrimary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.appPrimary)
        }
        .padding(.vertical, 2)
    }

    private func settingsInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
}
