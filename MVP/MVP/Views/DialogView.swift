import SwiftUI
import WebKit
import AVFoundation

enum AppMode: String, CaseIterable {
    case chat = "Chat"
    case support = "Support"
    case appStore = "AppStore"

    var iconAssetName: String {
        switch self {
        case .chat:
            return "TabChat"
        case .support:
            return "TabSupport"
        case .appStore:
            return "TabAppStore"
        }
    }

    var iconSystemName: String {
        switch self {
        case .chat:
            return "message.fill"
        case .support:
            return "person.2.fill"
        case .appStore:
            return "cart.fill"
        }
    }
}

struct SupportedLanguageItem {
    let code: String
    let displayName: String
}

struct SupportedLanguages {
    static let all: [SupportedLanguageItem] = [
        SupportedLanguageItem(code: "system", displayName: "System Default"),
        SupportedLanguageItem(code: "en-US", displayName: "English (US)"),
        SupportedLanguageItem(code: "es-ES", displayName: "Spanish"),
        SupportedLanguageItem(code: "fr-FR", displayName: "French"),
        SupportedLanguageItem(code: "de-DE", displayName: "German"),
        SupportedLanguageItem(code: "it-IT", displayName: "Italian"),
        SupportedLanguageItem(code: "pt-BR", displayName: "Portuguese (Brazil)"),
        SupportedLanguageItem(code: "ja-JP", displayName: "Japanese"),
        SupportedLanguageItem(code: "ko-KR", displayName: "Korean"),
        SupportedLanguageItem(code: "zh-CN", displayName: "Chinese (Simplified)"),
        SupportedLanguageItem(code: "ru-RU", displayName: "Russian"),
        SupportedLanguageItem(code: "uk-UA", displayName: "Ukrainian"),
        SupportedLanguageItem(code: "ar-SA", displayName: "Arabic"),
        SupportedLanguageItem(code: "he-IL", displayName: "Hebrew"),
        SupportedLanguageItem(code: "hi-IN", displayName: "Hindi"),
        SupportedLanguageItem(code: "id-ID", displayName: "Indonesian"),
        SupportedLanguageItem(code: "pl-PL", displayName: "Polish"),
        SupportedLanguageItem(code: "nl-NL", displayName: "Dutch"),
        SupportedLanguageItem(code: "tr-TR", displayName: "Turkish"),
        SupportedLanguageItem(code: "th-TH", displayName: "Thai"),
        SupportedLanguageItem(code: "vi-VN", displayName: "Vietnamese"),
        SupportedLanguageItem(code: "sv-SE", displayName: "Swedish"),
        SupportedLanguageItem(code: "da-DK", displayName: "Danish"),
        SupportedLanguageItem(code: "fi-FI", displayName: "Finnish"),
        SupportedLanguageItem(code: "nb-NO", displayName: "Norwegian"),
        SupportedLanguageItem(code: "cs-CZ", displayName: "Czech"),
        SupportedLanguageItem(code: "el-GR", displayName: "Greek"),
        SupportedLanguageItem(code: "ro-RO", displayName: "Romanian"),
        SupportedLanguageItem(code: "hu-HU", displayName: "Hungarian")
    ]
}

struct DialogView: View {
    let avatarType: AvatarType

    @StateObject private var stt = SpeechToTextService()
    @StateObject private var tts = TextToSpeechService()

    @State private var messages: [ChatMessage] = []
    @State private var chatMessages: [ChatMessage] = []
    @State private var supportMessages: [ChatMessage] = []
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
    @State private var showLongRequestNotice = false
    @State private var longRequestNoticeTask: Task<Void, Never>?
    @State private var showSettings = false
    @State private var appMode: AppMode = .chat

    @AppStorage("voiceOutputEnabled") private var voiceOutputEnabled = true
    @AppStorage("alwaysVoiceResponse") private var alwaysVoiceResponse = false
    @AppStorage("typingIndicatorEnabled") private var typingIndicatorEnabled = true
    @AppStorage("genderMatchedVoice") private var genderMatchedVoice = true
    @AppStorage("streamingTextEnabled") private var streamingTextEnabled = true
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("showSoftwareKeyboard") private var showSoftwareKeyboard = true

    @AppStorage("ttsSpeed") private var ttsSpeed: Double = 0.5
    @AppStorage("ttsPitch") private var ttsPitch: Double = 0.5
    @AppStorage("ttsVolume") private var ttsVolume: Double = 1.0
    @AppStorage("selectedLanguage") private var selectedLanguage = "system"
    @AppStorage("cloudTTSEnabled") private var cloudTTSEnabled = false
    @AppStorage("cloudTTSProvider") private var cloudTTSProvider = "off"

    private let maxHistoryCount = 500
    private let chatHistoryKey = "chatHistory"
    private let supportHistoryKey = "supportHistory"
    private let lastVersionKey = "lastAppVersion"

    private var historyKey: String {
        appMode == .support ? supportHistoryKey : chatHistoryKey
    }

    private var dialogLanguage: String {
        if appMode == .support { return "en-US" }
        if selectedLanguage == "system" { return DialogAPIService.getDeviceLanguage() }
        return selectedLanguage
    }

    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let screenH = UIScreen.main.bounds.height
            let isLandscape = w > screenH
            let webViewTopPad: CGFloat = isLandscape ? 90 : {
                let winTop = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first?.windows.first?.safeAreaInsets.top ?? 47
                return (winTop + 6) / 2 + 187
            }()

            ZStack {
                Color.black

                if UIImage(named: "LoginBackground") != nil {
                    Image("LoginBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(width: w, height: screenH)
                        .clipped()
                        .allowsHitTesting(false)
                }

                if isLandscape {
                    landscapeLayout(geo: geo)
                } else {
                    portraitLayout(w: w, h: screenH)
                }

                if let url = URL(string: APIConfig.appStoreURL) {
                    let landscapeBarH: CGFloat = 72
                    if isLandscape {
                        VStack(spacing: 0) {
                            Spacer().frame(height: landscapeBarH)
                            AppStoreWebView(url: url, token: AuthService.shared.token(), isLandscape: true)
                                .frame(width: w, height: screenH - landscapeBarH)
                        }
                        .opacity(appMode == .appStore ? 1 : 0)
                        .allowsHitTesting(appMode == .appStore)
                    } else {
                        AppStoreWebView(url: url, token: AuthService.shared.token(), isLandscape: false)
                            .frame(width: w, height: screenH - webViewTopPad)
                            .padding(.top, webViewTopPad)
                            .opacity(appMode == .appStore ? 1 : 0)
                            .allowsHitTesting(appMode == .appStore)
                    }
                }

                if isLandscape && appMode == .appStore {
                    VStack {
                        landscapeFullWidthTopBar
                            .frame(width: w)
                        Spacer()
                    }
                }

                if !isLandscape {
                    let winTop2 = UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .first?.windows.first?.safeAreaInsets.top ?? 47
                    VStack {
                        topBar.frame(width: w).padding(.top, (winTop2 + 6) / 2)
                        Spacer()
                    }
                }
            }
            .frame(width: w, height: screenH)
            .clipped()
        }
        .ignoresSafeArea(.all, edges: .all)
        .ignoresSafeArea(.keyboard)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { n in
            guard showSoftwareKeyboard else { return }
            guard let f = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            withAnimation(.easeOut(duration: 0.25)) { keyboardHeight = f.height }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { keyboardHeight = 0 }
        }
        .onAppear {
            guard ensureAuthenticatedOrRedirect() else { return }
            loadAllHistories()
            messages = chatMessages
            setupTTSCallbacks()
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onChange(of: appMode) { newMode in
            guard ensureAuthenticatedOrRedirect() else { return }
            if newMode == .chat {
                supportMessages = messages
                messages = chatMessages
            } else if newMode == .support {
                chatMessages = messages
                messages = supportMessages
            }
            tts.stop()
            typingMessageId = nil
            showTypingIndicator = false
            stopLongRequestNoticeTimer()
            isLoading = false
            errorMessage = nil
        }
        .onChange(of: showSoftwareKeyboard) { newValue in
            if !newValue {
                withAnimation(.easeOut(duration: 0.25)) { keyboardHeight = 0 }
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .onChange(of: tts.spokenCharacterCount) { newCount in
            if typingMessageId != nil {
                typingDisplayedCount = newCount
            }
        }
        .sheet(isPresented: $showSettings) {
            settingsSheet
        }
    }

    private func portraitLayout(w: CGFloat, h: CGFloat) -> some View {
        let windowTop = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 47
        let windowBottom = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 34
        let topBarH: CGFloat = 160
        let keyboardUp = keyboardHeight > 0 && showSoftwareKeyboard
        let topBarBottom = windowTop + 6 + topBarH
        let availableH: CGFloat = keyboardUp ? h - keyboardHeight : h
        let bottomH: CGFloat = keyboardUp
            ? max(availableH - topBarBottom - 10, 200)
            : h * 0.55

        return ZStack(alignment: .top) {
            if appMode != .appStore {
                AvatarView(avatarType: avatarType, state: avatarState, scale: 1.0)
                    .frame(width: w, height: h * 0.65)
                    .clipped()
                    .allowsHitTesting(false)
                    .padding(.top, topBarBottom + 20)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    VStack(spacing: 0) {
                        chatSection

                        if showTypingIndicator && typingIndicatorEnabled {
                            typingIndicatorView
                        }
                        if showLongRequestNotice {
                            longRequestNoticeView
                        }

                        inputRow

                        speakButton
                            .padding(.top, 6)
                            .padding(.bottom, keyboardUp ? 6 : max(windowBottom, 12))
                    }
                    .frame(width: w, height: bottomH)
                }
                .frame(width: w, height: availableH)
            }
        }
        .frame(width: w, height: h)
        .clipped()
    }

    private func landscapeLayout(geo: GeometryProxy) -> some View {
        let w = geo.size.width
        let h = geo.size.height
        let topBarH: CGFloat = 70
        let bottomH: CGFloat = h * 0.45

        return ZStack(alignment: .top) {
            if appMode != .appStore {
                AvatarView(avatarType: avatarType, state: avatarState, scale: 0.85, useAspectFit: true)
                    .frame(width: w, height: h)
                    .offset(y: topBarH * 0.75)
                    .clipped()
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    VStack(spacing: 0) {
                        chatSection

                        if showTypingIndicator && typingIndicatorEnabled {
                            typingIndicatorView
                        }
                        if showLongRequestNotice {
                            longRequestNoticeView
                        }

                        landscapeInputRow
                            .padding(.bottom, 8)
                    }
                    .frame(width: w, height: bottomH)
                    .background(Color.clear)
                }
                .frame(width: w, height: h)
            }

            if appMode != .appStore {
                landscapeFullWidthTopBar
                    .frame(width: w)
            }
        }
        .frame(width: w, height: h)
    }

    private var landscapeFullWidthTopBar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                brandLogo(width: 107, height: 43)
                    .padding(.leading, 16)

                Spacer()

                HStack(spacing: 4) {
                    Button {
                        NotificationCenter.default.post(name: .changeAvatar, object: nil)
                    } label: {
                        topActionIcon(assetName: "AvatarSelect", fallbackSystemName: "person.2.circle.fill", iconSize: 173, buttonSize: 173)
                    }

                    Button { showSettings = true } label: {
                        topActionIcon(assetName: "SettingsIcon", fallbackSystemName: "gearshape.fill", iconSize: 173, buttonSize: 173)
                    }
                }
            }

            HStack(spacing: 6) {
                ForEach(AppMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { appMode = mode }
                    } label: {
                        modeTabButton(mode: mode, isLandscape: true)
                    }
                }
            }
            .padding(4)
            .background(Color.clear)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.25))
    }

    private var topBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                brandLogo(width: 120, height: 48)
                    .padding(.leading, 16)

                Spacer()

                HStack(spacing: 4) {
                    Button {
                        NotificationCenter.default.post(name: .changeAvatar, object: nil)
                    } label: {
                        topActionIcon(assetName: "AvatarSelect", fallbackSystemName: "person.2.circle.fill", iconSize: 96, buttonSize: 96)
                    }

                    Button { showSettings = true } label: {
                        topActionIcon(assetName: "SettingsIcon", fallbackSystemName: "gearshape.fill", iconSize: 96, buttonSize: 96)
                    }
                }
            }

            HStack(spacing: 6) {
                ForEach(AppMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { appMode = mode }
                    } label: {
                        modeTabButton(mode: mode, isLandscape: false)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
            .background(Color.clear)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .background(Color.black.opacity(0.55))
    }

    private func modeTabButton(mode: AppMode, isLandscape: Bool) -> some View {
        let buttonWidth: CGFloat = isLandscape ? 157 : 117
        let iconSize: CGFloat = isLandscape ? 132 : 115
        let textSize: CGFloat = isLandscape ? 19 : 18
        let buttonHeight: CGFloat = isLandscape ? 92 : 80

        return ZStack(alignment: .bottom) {
            tabIcon(for: mode, size: iconSize)
                .padding(.bottom, 20)
            Text(mode.rawValue)
                .font(.system(size: textSize, weight: appMode == mode ? .semibold : .regular))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.bottom, 29)
        }
        .frame(width: buttonWidth, height: buttonHeight)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(appMode == mode ? Color.appPrimary : Color.white.opacity(0.12))
        )
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    @ViewBuilder
    private func brandLogo(width: CGFloat, height: CGFloat) -> some View {
        if UIImage(named: "InangoTopbarLogo") != nil {
            Image("InangoTopbarLogo")
                .resizable()
                .scaledToFit()
                .frame(width: width, height: height)
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        } else if UIImage(named: "InangoLogo") != nil {
            Image("InangoLogo")
                .resizable()
                .scaledToFit()
                .frame(width: width, height: height)
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        } else {
            Text("inango")
                .font(.system(size: 28, weight: .bold))
                .tracking(2)
                .foregroundColor(.white.opacity(0.35))
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        }
    }

    @ViewBuilder
    private func tabIcon(for mode: AppMode, size: CGFloat) -> some View {
        if UIImage(named: mode.iconAssetName) != nil {
            Image(mode.iconAssetName)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: mode.iconSystemName)
                .font(.system(size: size * 0.9, weight: .semibold))
        }
    }

    @ViewBuilder
    private func topActionIcon(assetName: String, fallbackSystemName: String, iconSize: CGFloat, buttonSize: CGFloat) -> some View {
        if UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .frame(width: buttonSize, height: buttonSize)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
        } else {
            Image(systemName: fallbackSystemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: buttonSize, height: buttonSize)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
        }
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
                    .foregroundColor(.black)
                    .background(Color.white.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
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
        HStack(spacing: 10) {
            TextField("Type your message...", text: $inputText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 15))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .foregroundColor(.black)
                .background(Color.white.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
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
                    .frame(width: 44, height: 44)
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
                    .frame(width: 44, height: 44)
                    .background(Color.appPrimary)
                    .clipShape(Circle())
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(.horizontal, 24)
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

    private var longRequestNoticeView: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.yellow)
                .font(.system(size: 13))
            Text("Still processing your request...")
                .font(.system(size: 13))
                .foregroundColor(.white)
                .lineLimit(2)
            Spacer()
        }
        .padding(10)
        .background(Color.yellow.opacity(0.18))
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

    private var ttsRate: Float {
        let speed = Float(ttsSpeed)
        let minRate = AVSpeechUtteranceMinimumSpeechRate
        let maxRate = AVSpeechUtteranceMaximumSpeechRate
        if genderMatchedVoice {
            let genderBase = avatarType.isFemale
                ? AVSpeechUtteranceDefaultSpeechRate * 0.92
                : AVSpeechUtteranceDefaultSpeechRate * 0.95
            if speed <= 0.5 {
                return minRate + (genderBase - minRate) * (speed / 0.5)
            } else {
                return genderBase + (maxRate - genderBase) * ((speed - 0.5) / 0.5)
            }
        }
        return minRate + (maxRate - minRate) * speed
    }
    private var ttsPitchValue: Float {
        let p = Float(ttsPitch)
        if genderMatchedVoice {
            let genderBase: Float = avatarType.isFemale ? 1.35 : 0.75
            if p <= 0.5 {
                return 0.5 + (genderBase - 0.5) * (p / 0.5)
            } else {
                return genderBase + (2.0 - genderBase) * ((p - 0.5) / 0.5)
            }
        }
        return 0.5 + p * 1.5
    }
    private var ttsVolumeValue: Float {
        Float(ttsVolume)
    }

    private func setupTTSCallbacks() {
        tts.onSpeakingStarted = { avatarState = .speaking }
        tts.onSpeakingCompleted = { avatarState = .idle }
    }

    /// Guard protected flows while user is inside Dialog screen.
    /// If auth is gone for any reason, immediately force the global re-auth flow.
    @MainActor
    private func ensureAuthenticatedOrRedirect() -> Bool {
        let hasToken = !(AuthService.shared.token() ?? "").isEmpty
        guard SessionManager.shared.isAuthenticated && hasToken else {
            SessionManager.shared.handleUnauthorized()
            return false
        }
        return true
    }

    private func playGreetingIfNeeded() {
        guard !hasPlayedGreeting else { return }
        hasPlayedGreeting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let greeting = "Hello! How can I help you today?"
            let msg = ChatMessage(text: greeting, isFromUser: false)
            messages.append(msg)
            startTypewriter(messageId: msg.id, fullText: greeting)
            if voiceOutputEnabled {
                speakResponse(greeting)
            }
        }
    }

    private func startVoiceInput() {
        guard ensureAuthenticatedOrRedirect() else { return }
        tts.stop()
        CloudTTSService.shared.stop()
        AzureTTSService.shared.stop()
        errorMessage = nil
        avatarState = .thinking
        wasVoiceInput = true
        stt.requestAuthorization { granted in
            guard granted else {
                errorMessage = stt.errorMessage ?? "Microphone access needed."
                avatarState = .idle; return
            }
            stt.startRecording(language: dialogLanguage) { text in
                if let text = text, !text.isEmpty {
                    inputText = text
                    sendMessage(text, fromVoice: true)
                } else { avatarState = .idle }
            }
        }
    }

    private func sendMessage(_ text: String, fromVoice: Bool, isRetry: Bool = false) {
        guard ensureAuthenticatedOrRedirect() else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Stop any ongoing TTS before starting a new request (#44825).
        tts.stop()
        CloudTTSService.shared.stop()
        AzureTTSService.shared.stop()
        wasVoiceInput = fromVoice
        if !isRetry {
            inputText = ""
            messages.append(ChatMessage(text: trimmed, isFromUser: true, wasVoiceInput: fromVoice, language: dialogLanguage))
        }
        errorMessage = nil; lastFailedMessage = nil; isLoading = true; avatarState = .thinking
        if typingIndicatorEnabled { showTypingIndicator = true }
        startLongRequestNoticeTimer()

        Task {
            do {
                let apiBaseURL: String? = appMode == .support ? APIConfig.supportBaseURL : nil
                let response = try await DialogAPIService.shared.sendMessage(trimmed, language: dialogLanguage, baseURL: apiBaseURL)
                await MainActor.run {
                    stopLongRequestNoticeTimer()
                    showTypingIndicator = false
                    let displayText = stripNoSpeechForDisplay(response)
                    let ttsText = stripNoSpeechForTTS(response)
                    let botMsg = ChatMessage(text: displayText, isFromUser: false, wasVoiceInput: fromVoice, language: dialogLanguage)
                    messages.append(botMsg)
                    isLoading = false
                    let shouldSpeak = voiceOutputEnabled && !ttsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    if shouldSpeak {
                        typingMessageId = botMsg.id
                        typingDisplayedCount = 0
                        avatarState = .speaking
                        speakResponse(ttsText) {
                            typingDisplayedCount = displayText.count
                            typingMessageId = nil
                            avatarState = .idle
                        }
                    } else {
                        avatarState = .speaking
                        startTypewriter(messageId: botMsg.id, fullText: displayText)
                        let displayTime = Double(displayText.count) * 0.025 + 0.5
                        DispatchQueue.main.asyncAfter(deadline: .now() + displayTime) {
                            if avatarState == .speaking { avatarState = .idle }
                        }
                    }
                    saveChatHistory()
                }
            } catch {
                await MainActor.run {
                    stopLongRequestNoticeTimer()
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

    private func stripNoSpeechForDisplay(_ text: String) -> String {
        text.replacingOccurrences(
            of: "</?no-sp(?:ee|ea)ch>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    private func stripNoSpeechForTTS(_ text: String) -> String {
        text.replacingOccurrences(
            of: "<no-sp(?:ee|ea)ch>[\\s\\S]*?</no-sp(?:ee|ea)ch>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    private func startLongRequestNoticeTimer() {
        stopLongRequestNoticeTimer()
        longRequestNoticeTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if isLoading {
                    showLongRequestNotice = true
                }
            }
        }
    }

    private func stopLongRequestNoticeTimer() {
        longRequestNoticeTask?.cancel()
        longRequestNoticeTask = nil
        showLongRequestNotice = false
    }

    private func retryLastMessage() {
        guard let text = lastFailedMessage else { return }
        sendMessage(text, fromVoice: wasVoiceInput, isRetry: true)
    }

    private func speakResponse(_ text: String, completion: (() -> Void)? = nil) {
        let preferMale = genderMatchedVoice ? (avatarType == .male) : nil
        let isFemale = preferMale == false
        switch cloudTTSProvider {
        case "google":
            CloudTTSService.shared.speak(text: text, language: dialogLanguage, isFemale: isFemale, completion: completion)
        case "azure":
            AzureTTSService.shared.speak(text: text, language: dialogLanguage, isFemale: isFemale, completion: completion)
        default:
            tts.speak(
                text,
                language: dialogLanguage,
                preferMale: preferMale,
                rate: ttsRate,
                pitch: ttsPitchValue,
                volume: ttsVolumeValue,
                completion: completion
            )
        }
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
                    try? await Task.sleep(nanoseconds: 10_000_000)
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
        if appMode == .chat {
            chatMessages = messages
        } else if appMode == .support {
            supportMessages = messages
        }
    }

    private func loadAllHistories() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        let fullVersion = "\(currentVersion).\(currentBuild)"
        let lastVersion = UserDefaults.standard.string(forKey: lastVersionKey) ?? ""
        if fullVersion != lastVersion {
            UserDefaults.standard.removeObject(forKey: chatHistoryKey)
            UserDefaults.standard.removeObject(forKey: supportHistoryKey)
            UserDefaults.standard.set(fullVersion, forKey: lastVersionKey)
            KeychainService.shared.resetAvatarSelection()
            chatMessages = []
            supportMessages = []
            return
        }
        if let data = UserDefaults.standard.data(forKey: chatHistoryKey),
           let saved = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            chatMessages = saved
        }
        if let data = UserDefaults.standard.data(forKey: supportHistoryKey),
           let saved = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            supportMessages = saved
        }
    }

    private func clearChatHistory() {
        messages.removeAll()
        if appMode == .chat {
            chatMessages.removeAll()
            UserDefaults.standard.removeObject(forKey: chatHistoryKey)
        } else if appMode == .support {
            supportMessages.removeAll()
            UserDefaults.standard.removeObject(forKey: supportHistoryKey)
        }
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

                Section(header: Text("Voice Configuration")) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "hare")
                                .font(.system(size: 16))
                                .foregroundColor(.appPrimary)
                                .frame(width: 28)
                            Text("Voice Speed")
                                .font(.system(size: 15))
                            Spacer()
                            Text(String(format: "%.0f%%", ttsSpeed * 100))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $ttsSpeed, in: 0.0...1.0, step: 0.05)
                            .tint(.appPrimary)
                        HStack {
                            Text("Slow").font(.system(size: 11)).foregroundColor(.secondary)
                            Spacer()
                            Text("Fast").font(.system(size: 11)).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "waveform.path")
                                .font(.system(size: 16))
                                .foregroundColor(.appPrimary)
                                .frame(width: 28)
                            Text("Voice Pitch")
                                .font(.system(size: 15))
                            Spacer()
                            Text(String(format: "%.0f%%", ttsPitch * 100))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $ttsPitch, in: 0.0...1.0, step: 0.05)
                            .tint(.appPrimary)
                        HStack {
                            Text("Low").font(.system(size: 11)).foregroundColor(.secondary)
                            Spacer()
                            Text("High").font(.system(size: 11)).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "speaker.wave.3")
                                .font(.system(size: 16))
                                .foregroundColor(.appPrimary)
                                .frame(width: 28)
                            Text("Voice Volume")
                                .font(.system(size: 15))
                            Spacer()
                            Text(String(format: "%.0f%%", ttsVolume * 100))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $ttsVolume, in: 0.0...1.0, step: 0.05)
                            .tint(.appPrimary)
                        HStack {
                            Text("Quiet").font(.system(size: 11)).foregroundColor(.secondary)
                            Spacer()
                            Text("Loud").font(.system(size: 11)).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .disabled(!voiceOutputEnabled)
                .opacity(voiceOutputEnabled ? 1.0 : 0.5)

                Section(header: Text("Language")) {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 18))
                            .foregroundColor(.appPrimary)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Communication Language")
                                .font(.system(size: 15))
                            Text("Used for speech recognition and voice output")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)

                    Picker("Language", selection: $selectedLanguage) {
                        ForEach(SupportedLanguages.all, id: \.code) { lang in
                            Text(lang.displayName).tag(lang.code)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(header: Text("Cloud TTS")) {
                    HStack(spacing: 12) {
                        Image(systemName: "cloud")
                            .font(.system(size: 18))
                            .foregroundColor(.appPrimary)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TTS Provider")
                                .font(.system(size: 15))
                            Text("Cloud voices sound more natural. Off uses local iOS TTS.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)

                    Picker("Provider", selection: $cloudTTSProvider) {
                        Text("Off (Local TTS)").tag("off")
                        Text("Google Cloud TTS").tag("google")
                        Text("Microsoft Azure TTS").tag("azure")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: cloudTTSProvider) { newValue in
                        cloudTTSEnabled = newValue != "off"
                    }
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
                    settingsInfoRow(label: "Version", value: "v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                    settingsInfoRow(label: "Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
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

final class AppStoreNavDelegate: NSObject, WKNavigationDelegate {
    var isLandscape: Bool = false
    var authToken: String?
    var savedEmail: String?
    var savedPassword: String?
    private var didReloadAfterAuthInjection = false
    private var didAttemptCredentialAutoLogin = false

    func resetAuthInjectionReloadFlag() {
        didReloadAfterAuthInjection = false
    }

    func resetCredentialAutoLoginFlag() {
        didAttemptCredentialAutoLogin = false
    }

    private let landscapeFormHTML = """
    <html><head><meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <style>*{box-sizing:border-box;margin:0;padding:0}html,body{width:100%;height:100%;overflow:hidden}body{font-family:-apple-system,Helvetica,sans-serif;background:#fff;display:flex;flex-direction:column;align-items:center;justify-content:flex-start;padding:20px 24px 0 24px}
    h2{font-size:17px;color:#1a1a4e;font-weight:bold;margin-bottom:6px;text-align:left;width:100%;max-width:460px}
    input{width:100%;max-width:460px;padding:8px 12px;margin-bottom:6px;border:1px solid #ddd;border-radius:8px;font-size:13px;outline:none}
    input:focus{border-color:#e86833}
    .btn{width:100%;max-width:460px;padding:10px;background:#e86833;color:#fff;border:none;border-radius:8px;font-size:14px;font-weight:bold;cursor:pointer;margin-top:2px}
    .logo{margin-top:8px;font-size:11px;color:#999;text-align:center;max-width:460px;width:100%}</style></head>
    <body><h2>Login</h2>
    <input id="lf_email" type="email" placeholder="Email Address" autocomplete="email" autofocus>
    <input id="lf_pass" type="password" placeholder="Password" autocomplete="current-password">
    <button class="btn" id="lf_btn">Login</button>
    <p id="lf_err" style="color:red;font-size:11px;margin-top:4px;max-width:460px;display:none"></p>
    <div class="logo">inango</div>
    <script>
    setTimeout(function(){document.getElementById('lf_email').focus()},100);
    document.getElementById('lf_btn').onclick=function(){
        var e=document.getElementById('lf_email').value,p=document.getElementById('lf_pass').value;
        if(!e||!p){document.getElementById('lf_err').style.display='block';document.getElementById('lf_err').textContent='Please enter email and password';return}
        document.getElementById('lf_btn').textContent='Logging in...';document.getElementById('lf_btn').disabled=true;
        fetch(window._appStoreBase+'/api/auth/login',{method:'POST',headers:{'Content-Type':'application/json','Accept':'application/json'},body:JSON.stringify({email:e,password:p}),credentials:'include'})
        .then(function(r){return r.json().then(function(d){return{ok:r.ok,data:d}})})
        .then(function(res){
            if(res.ok&&res.data.token){document.cookie='token='+res.data.token+';path=/;secure';window.location.href=window._appStoreBase+'?token='+res.data.token}
            else if(res.ok){window.location.href=window._appStoreBase}
            else{document.getElementById('lf_err').style.display='block';document.getElementById('lf_err').textContent=res.data.message||'Login failed';document.getElementById('lf_btn').textContent='Login';document.getElementById('lf_btn').disabled=false}
        }).catch(function(err){
            document.getElementById('lf_err').style.display='block';document.getElementById('lf_err').textContent='Network error: '+err.message;
            document.getElementById('lf_btn').textContent='Login';document.getElementById('lf_btn').disabled=false
        })
    };
    document.querySelectorAll('input').forEach(function(inp){inp.addEventListener('keydown',function(ev){if(ev.key==='Enter')document.getElementById('lf_btn').click()})});
    </script></body></html>
    """

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        injectAuthSession(webView)
        injectCredentialAutoLogin(webView)
        guard isLandscape else { return }
        guard let currentURL = webView.url?.absoluteString else { return }
        if currentURL.contains("token=") { return }
        injectLandscapeForm(webView)
    }

    private func injectAuthSession(_ webView: WKWebView) {
        guard let token = authToken, !token.isEmpty else { return }
        let escapedToken = token
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let js = """
        try {
            window.localStorage.setItem('token', '\(escapedToken)');
            window.localStorage.setItem('access_token', '\(escapedToken)');
            window.localStorage.setItem('jwt', '\(escapedToken)');
            document.cookie = 'token=\(escapedToken); path=/; secure; samesite=lax';
            document.cookie = 'access_token=\(escapedToken); path=/; secure; samesite=lax';
            document.cookie = 'jwt=\(escapedToken); path=/; secure; samesite=lax';
            document.cookie = 'next-auth.session-token=\(escapedToken); path=/; secure; samesite=lax';
        } catch (e) {}
        """
        webView.evaluateJavaScript(js)
    }

    private func injectCredentialAutoLogin(_ webView: WKWebView) {
        guard !didAttemptCredentialAutoLogin else { return }
        guard
            let email = savedEmail, !email.isEmpty,
            let password = savedPassword, !password.isEmpty
        else { return }

        let escapedEmail = email
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let escapedPassword = password
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let js = """
        (function() {
            var e = document.querySelector('input[type="email"],input[name="email"],#lf_email');
            var p = document.querySelector('input[type="password"],input[name="password"],#lf_pass');
            var b = document.querySelector('button[type="submit"],button#lf_btn,.btn');
            if (!e || !p || !b) { return false; }
            if ((e.value || '').length > 0 && (p.value || '').length > 0) { return false; }
            e.value = '\(escapedEmail)';
            p.value = '\(escapedPassword)';
            e.dispatchEvent(new Event('input', { bubbles: true }));
            p.dispatchEvent(new Event('input', { bubbles: true }));
            setTimeout(function() { b.click(); }, 80);
            return true;
        })();
        """
        webView.evaluateJavaScript(js) { result, _ in
            if let didSubmit = result as? Bool, didSubmit {
                self.didAttemptCredentialAutoLogin = true
            }
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if let http = navigationResponse.response as? HTTPURLResponse,
           navigationResponse.isForMainFrame,
           http.statusCode == 401 {
            DispatchQueue.main.async {
                SessionManager.shared.handleUnauthorized()
            }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func injectLandscapeForm(_ webView: WKWebView) {
        let checkJS = "(document.querySelector('input[type=\"password\"]') !== null) ? 'login' : ((document.getElementById('lf_email') !== null) ? 'already' : 'other')"
        webView.evaluateJavaScript(checkJS) { result, _ in
            let pageType = result as? String ?? "other"
            if pageType == "already" {
                webView.evaluateJavaScript("document.getElementById('lf_email').focus();")
                return
            }
            guard pageType == "login" else { return }
            let baseURL = APIConfig.appStoreURL
            let setBaseJS = "window._appStoreBase = '\(baseURL)';"
            webView.evaluateJavaScript(setBaseJS)
            let escapedHTML = self.landscapeFormHTML
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "")
            let replaceJS = "document.open(); document.write('\(escapedHTML)'); document.close(); window._appStoreBase = '\(baseURL)'; setTimeout(function(){document.getElementById('lf_email').focus()},200);"
            webView.evaluateJavaScript(replaceJS)
        }
    }
}

final class AppStoreWebViewStore {
    private struct AppStoreAuthBootstrap {
        let token: String?
        let cookies: [HTTPCookie]
    }

    static let shared = AppStoreWebViewStore()
    private(set) var webView: WKWebView?
    private var loadedToken: String?
    private var appStoreAuthTask: Task<Void, Never>?
    let navDelegate = AppStoreNavDelegate()

    func getOrCreate(url: URL, token: String?) -> WKWebView {
        if let wv = webView {
            syncSession(url: url, token: token, in: wv)
            return wv
        }

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.websiteDataStore = .default()

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.scrollView.bounces = true
        wv.allowsBackForwardNavigationGestures = true
        wv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        wv.scrollView.contentInsetAdjustmentBehavior = .always
        wv.navigationDelegate = navDelegate

        webView = wv
        syncSession(url: url, token: token, in: wv, forceReload: true)
        return wv
    }

    func syncSession(url: URL, token: String?, in webView: WKWebView? = nil, forceReload: Bool = false) {
        let target = webView ?? self.webView
        guard let target else { return }
        if token != loadedToken {
            navDelegate.resetAuthInjectionReloadFlag()
            navDelegate.resetCredentialAutoLoginFlag()
        }
        navDelegate.authToken = token
        navDelegate.savedEmail = KeychainService.shared.getLastEmail()
        navDelegate.savedPassword = KeychainService.shared.getLastPassword()
        guard forceReload || loadedToken != token else { return }

        load(url: url, token: token, in: target)
        loadedToken = token
    }

    private func load(url: URL, token: String?, in webView: WKWebView) {
        if let email = navDelegate.savedEmail, !email.isEmpty,
           let password = navDelegate.savedPassword, !password.isEmpty {
            let fallbackToken = token
            appStoreAuthTask?.cancel()
            appStoreAuthTask = Task { [weak self, weak webView] in
                guard let self = self else { return }
                let bootstrap = await self.fetchAppStoreAuthBootstrap(email: email, password: password)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let webView = webView else { return }
                    let effectiveToken = bootstrap?.token ?? fallbackToken
                    self.applyServerCookies(bootstrap?.cookies ?? [], in: webView) {
                        self.navDelegate.authToken = effectiveToken
                        self.applySessionAndLoad(url: url, token: effectiveToken, in: webView)
                    }
                }
            }
            return
        }

        applySessionAndLoad(url: url, token: token, in: webView)
    }

    private func fetchAppStoreAuthBootstrap(email: String, password: String) async -> AppStoreAuthBootstrap? {
        let paths = ["/api/auth/login", "/api/v1/auth/login"]
        let methods = ["POST", "PUT"]
        let body: [String: String] = ["email": email, "password": password]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        for path in paths {
            guard let loginURL = URL(string: APIConfig.appStoreURL + path) else { continue }
            for method in methods {
                var request = URLRequest(url: loginURL)
                request.httpMethod = method
                request.timeoutInterval = 12
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.httpBody = bodyData

                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard let http = response as? HTTPURLResponse else { continue }
                    guard (200...299).contains(http.statusCode) else { continue }
                    let cookies = extractCookies(from: http, for: loginURL)
                    let token = parseToken(from: data)
                    if token != nil || !cookies.isEmpty {
                        return AppStoreAuthBootstrap(token: token, cookies: cookies)
                    }
                } catch {
                    continue
                }
            }
        }
        return nil
    }

    private func applyServerCookies(_ cookies: [HTTPCookie], in webView: WKWebView, completion: @escaping () -> Void) {
        guard !cookies.isEmpty else {
            completion()
            return
        }
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        let cookieGroup = DispatchGroup()
        for cookie in cookies {
            cookieGroup.enter()
            cookieStore.setCookie(cookie) {
                cookieGroup.leave()
            }
        }
        cookieGroup.notify(queue: .main, execute: completion)
    }

    private func extractCookies(from response: HTTPURLResponse, for url: URL) -> [HTTPCookie] {
        var headers: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            guard let keyString = key as? String, let valueString = value as? String else { continue }
            headers[keyString] = valueString
        }
        return HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
    }

    private func parseToken(from data: Data) -> String? {
        if let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           text.contains("."),
           text.count > 40,
           !text.hasPrefix("{"),
           !text.hasPrefix("[") {
            return text
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return findToken(in: json)
    }

    private func findToken(in value: Any) -> String? {
        if let dict = value as? [String: Any] {
            for key in ["token", "access_token", "access", "jwt"] {
                if let token = dict[key] as? String, !token.isEmpty {
                    return token
                }
            }
            for child in dict.values {
                if let token = findToken(in: child) {
                    return token
                }
            }
        } else if let arr = value as? [Any] {
            for child in arr {
                if let token = findToken(in: child) {
                    return token
                }
            }
        }
        return nil
    }

    private func applySessionAndLoad(url: URL, token: String?, in webView: WKWebView) {
        var finalURL = url
        if let token = token {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            var items = components?.queryItems ?? []
            items.removeAll { $0.name == "token" }
            items.append(URLQueryItem(name: "token", value: token))
            components?.queryItems = items
            finalURL = components?.url ?? url

            var request = URLRequest(url: finalURL)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let domain = url.host ?? "appstore-demo.inango.com"
            let cookieNames = ["token", "access_token", "jwt", "next-auth.session-token"]
            let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
            let cookieGroup = DispatchGroup()
            var didSetAnyCookie = false
            for cookieName in cookieNames {
                if let cookie = HTTPCookie(properties: [
                    .domain: domain,
                    .path: "/",
                    .name: cookieName,
                    .value: token,
                    .secure: "TRUE",
                    .expires: Date(timeIntervalSinceNow: 86400)
                ]) {
                    didSetAnyCookie = true
                    cookieGroup.enter()
                    cookieStore.setCookie(cookie) {
                        cookieGroup.leave()
                    }
                }
            }
            if didSetAnyCookie {
                cookieGroup.notify(queue: .main) {
                    webView.load(request)
                }
            } else {
                webView.load(request)
            }
        } else {
            webView.load(URLRequest(url: finalURL))
        }
    }

    func reset() {
        appStoreAuthTask?.cancel()
        appStoreAuthTask = nil
        webView = nil
        loadedToken = nil
    }
}

struct AppStoreWebView: UIViewRepresentable {
    let url: URL
    let token: String?
    var isLandscape: Bool = false

    func makeUIView(context: Context) -> WKWebView {
        let wv = AppStoreWebViewStore.shared.getOrCreate(url: url, token: token)
        AppStoreWebViewStore.shared.navDelegate.isLandscape = isLandscape
        return wv
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let store = AppStoreWebViewStore.shared
        store.navDelegate.isLandscape = isLandscape
        DispatchQueue.main.async {
            store.syncSession(url: url, token: token, in: webView)
            webView.setNeedsLayout()
            webView.layoutIfNeeded()
            if isLandscape {
                store.navDelegate.injectLandscapeForm(webView)
            }
        }
    }
}
