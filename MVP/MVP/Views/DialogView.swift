import SwiftUI
import WebKit
import AVFoundation
import os

enum AppMode: String, CaseIterable {
    case chat = "Chat"
    case support = "Support"
    case appStore = "AppStore"
    case problems = "Problems"

    var iconAssetName: String {
        switch self {
        case .chat:    return "TabChat"
        case .support: return "TabSupport"
        case .appStore: return "TabAppStore"
        case .problems: return "TabProblems"
        }
    }

    var iconSystemName: String {
        switch self {
        case .chat:    return "message.fill"
        case .support: return "person.2.fill"
        case .appStore: return "cart.fill"
        case .problems: return "exclamationmark.triangle.fill"
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
    @StateObject private var cloudTTS = CloudTTSService.shared
    @StateObject private var azureTTS = AzureTTSService.shared

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
    @State private var typingTargetCount: Int = 0
    @State private var avatarState: AvatarAnimState = .idle
    @State private var wasVoiceInput = false
    @State private var showTypingIndicator = false
    @State private var showLongRequestNotice = false
    @State private var longRequestNoticeTask: Task<Void, Never>?
    @State private var showSettings = false
    @State private var showWebGateway = false
    @State private var webButtonTapped = false
    @SceneStorage("dialogViewAppMode") private var persistedAppMode = AppMode.chat.rawValue
    @State private var appMode: AppMode = .chat

    private var isInangoUser: Bool {
        KeychainService.shared.getLastEmail()?.hasSuffix("@inango-systems.com") == true
    }

    private var visibleModes: [AppMode] {
        AppMode.allCases.filter { $0 != .problems || isInangoUser }
    }

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
    private var tabSpacing: CGFloat { visibleModes.count >= 4 ? 4 : 6 }
    private var tabHorizontalInset: CGFloat { visibleModes.count >= 4 ? 2 : 4 }

    private func messages(for mode: AppMode) -> [ChatMessage] {
        switch mode {
        case .chat:
            return chatMessages
        case .support:
            return supportMessages
        default:
            return []
        }
    }

    private func setMessages(_ updated: [ChatMessage], for mode: AppMode) {
        switch mode {
        case .chat:
            chatMessages = updated
        case .support:
            supportMessages = updated
        default:
            return
        }
        if appMode == mode {
            messages = updated
        }
    }

    private func appendMessage(_ message: ChatMessage, to mode: AppMode) {
        var updated = messages(for: mode)
        updated.append(message)
        setMessages(updated, for: mode)
    }

    private var activeMessages: [ChatMessage] {
        messages(for: appMode)
    }

    private var isAnyTTSPlaying: Bool {
        tts.isSpeaking || cloudTTS.isSpeaking || azureTTS.isSpeaking
    }

    private var dialogLanguage: String {
        if appMode == .support { return "en-US" }
        if selectedLanguage == "system" { return DialogAPIService.getDeviceLanguage() }
        return selectedLanguage
    }

    @State private var keyboardHeight: CGFloat = 0
    private let landscapeTopContentInset: CGFloat = 122

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let screenH = geo.size.height
            let isLandscape = w > geo.size.height
            let webViewTopPad: CGFloat = isLandscape ? 90 : {
                let winTop = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first?.windows.first?.safeAreaInsets.top ?? 47
                // Align AppStore/Problems content exactly with portrait top-bar bottom edge.
                return (winTop + 6) / 2 + 166
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

                if appMode == .appStore, let url = URL(string: APIConfig.appStoreURL) {
                    let landscapeBarH: CGFloat = landscapeTopContentInset + 14
                    if isLandscape {
                        VStack(spacing: 0) {
                            Spacer().frame(height: landscapeBarH)
                            AppStoreWebView(url: url, token: AuthService.shared.token(), isLandscape: true)
                                .frame(width: w, height: screenH - landscapeBarH)
                        }
                    } else {
                        AppStoreWebView(url: url, token: AuthService.shared.token(), isLandscape: false)
                            .frame(width: w, height: screenH - webViewTopPad)
                            .padding(.top, webViewTopPad)
                    }
                }

                // Problems screen — sits at the same layer as the AppStore WebView
                if appMode == .problems {
                    let landscapeBarH: CGFloat = landscapeTopContentInset + 14
                    if isLandscape {
                        VStack(spacing: 0) {
                            Spacer().frame(height: landscapeBarH)
                            ProblemsView()
                                .frame(width: w, height: screenH - landscapeBarH)
                        }
                    } else {
                        ProblemsView()
                            .frame(width: w, height: screenH - webViewTopPad)
                            .padding(.top, webViewTopPad)
                    }
                }

                // WEB gateway screen — shown when user taps the WEB button in the top bar
                if showWebGateway {
                    let landscapeBarH: CGFloat = landscapeTopContentInset + 14
                    if isLandscape {
                        VStack(spacing: 0) {
                            Spacer().frame(height: landscapeBarH)
                            WebGatewayView()
                                .frame(width: w, height: screenH - landscapeBarH)
                        }
                    } else {
                        WebGatewayView()
                            .frame(width: w, height: screenH - webViewTopPad)
                            .padding(.top, webViewTopPad)
                    }
                }

                if isLandscape && (appMode == .appStore || appMode == .problems || showWebGateway) {
                    VStack {
                        landscapeFullWidthTopBar
                            .frame(width: w)
                        Spacer()
                    }
                    .zIndex(0)
                }

                if !isLandscape {
                    let winTop2 = UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .first?.windows.first?.safeAreaInsets.top ?? 47
                    VStack {
                        topBar.frame(width: w).padding(.top, (winTop2 + 6) / 2)
                        Spacer()
                    }
                    .zIndex(0)
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
            if let restoredMode = AppMode(rawValue: persistedAppMode) {
                appMode = restoredMode
            }
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
            let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
            AppLogger.navigation.info("DialogView appeared version=\(version, privacy: .public) build=\(build, privacy: .public) avatar=\(avatarType.rawValue, privacy: .public)")
            loadAllHistories()
            messages = messages(for: appMode)
            setupTTSCallbacks()
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onChange(of: appMode) { newMode in
            guard ensureAuthenticatedOrRedirect() else { return }
            AppLogger.navigation.info("tab switched to=\(newMode.rawValue, privacy: .public)")
            persistedAppMode = newMode.rawValue
            if newMode == .chat || newMode == .support {
                messages = messages(for: newMode)
            }
            // .appStore and .problems don't use the chat message list
            typingMessageId = nil
            showTypingIndicator = false
            stopLongRequestNoticeTimer()
            isLoading = false
            errorMessage = nil
            typingTargetCount = 0
        }
        .onChange(of: showSoftwareKeyboard) { newValue in
            if !newValue {
                withAnimation(.easeOut(duration: 0.25)) { keyboardHeight = 0 }
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .onChange(of: tts.spokenCharacterCount) { newCount in
            if typingMessageId != nil {
                typingDisplayedCount = min(newCount, typingTargetCount)
            }
        }
        .onChange(of: cloudTTS.spokenCharacterCount) { newCount in
            if typingMessageId != nil && cloudTTS.isSpeaking {
                typingDisplayedCount = min(newCount, typingTargetCount)
            }
        }
        .onChange(of: azureTTS.spokenCharacterCount) { newCount in
            if typingMessageId != nil && azureTTS.isSpeaking {
                typingDisplayedCount = min(newCount, typingTargetCount)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            if appMode == .chat || appMode == .support {
                messages = messages(for: appMode)
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
            if appMode != .appStore && appMode != .problems {
                AvatarView(avatarType: avatarType, state: avatarState, scale: 1.0)
                    .scaleEffect(1.15)
                    .frame(width: w, height: h * 0.65)
                    .allowsHitTesting(false)
                    .padding(.top, topBarBottom)
                    .zIndex(10)

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
                .zIndex(20)
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
            if appMode != .appStore && appMode != .problems {
                AvatarView(avatarType: avatarType, state: avatarState, scale: 0.85, useAspectFit: true)
                    .frame(width: w, height: h)
                    .offset(y: topBarH * 0.20 + 38)
                    .allowsHitTesting(false)
                    .zIndex(10)

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
                .zIndex(20)
            }

            if appMode != .appStore && appMode != .problems {
                landscapeFullWidthTopBar
                    .frame(width: w)
                    .zIndex(0)
            }
        }
        .frame(width: w, height: h)
    }

    private var landscapeFullWidthTopBar: some View {
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                brandLogo(width: 107, height: 43)
                    .padding(.leading, 16)

                Spacer()

                HStack(spacing: 4) {
                    Button {
                        NotificationCenter.default.post(name: .changeAvatar, object: nil)
                    } label: {
                        topActionIcon(assetName: "AvatarSelect", fallbackSystemName: "person.2.circle.fill", iconSize: 105, buttonSize: 105)
                    }

                    Button {
                        webButtonTapped = true
                        withAnimation(.easeInOut(duration: 0.2)) { showWebGateway.toggle() }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { webButtonTapped = false }
                    } label: {
                        topActionIcon(assetName: "WebIcon", fallbackSystemName: "globe", iconSize: 76, buttonSize: 105)
                    }
                    .overlay(
                        webButtonTapped
                            ? RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.appPrimary, lineWidth: 2)
                                .padding(6)
                            : nil
                    )

                    Button { showSettings = true } label: {
                        topActionIcon(assetName: "SettingsIcon", fallbackSystemName: "gearshape.fill", iconSize: 105, buttonSize: 105)
                    }
                }
            }
            .offset(y: -30)

            HStack(spacing: tabSpacing) {
                ForEach(visibleModes, id: \.self) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { appMode = mode }
                    } label: {
                        modeTabButton(mode: mode, isLandscape: true, modeCount: visibleModes.count)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .offset(y: -60)
            .padding(.horizontal, tabHorizontalInset)
            .padding(.vertical, 2)
            .background(Color.clear)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 2)
        .background(Color.clear)
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
                        topActionIcon(assetName: "AvatarSelect", fallbackSystemName: "person.2.circle.fill", iconSize: 87, buttonSize: 87)
                    }

                    Button {
                        webButtonTapped = true
                        withAnimation(.easeInOut(duration: 0.2)) { showWebGateway.toggle() }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { webButtonTapped = false }
                    } label: {
                        topActionIcon(assetName: "WebIcon", fallbackSystemName: "globe", iconSize: 62, buttonSize: 87)
                    }
                    .overlay(
                        webButtonTapped
                            ? RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.appPrimary, lineWidth: 2)
                                .padding(6)
                            : nil
                    )

                    Button { showSettings = true } label: {
                        topActionIcon(assetName: "SettingsIcon", fallbackSystemName: "gearshape.fill", iconSize: 87, buttonSize: 87)
                    }
                }
            }

            HStack(spacing: tabSpacing) {
                ForEach(visibleModes, id: \.self) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { appMode = mode }
                    } label: {
                        modeTabButton(mode: mode, isLandscape: false, modeCount: visibleModes.count)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, tabHorizontalInset)
            .padding(.bottom, 4)
            .background(Color.clear)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .background(Color.black.opacity(0.55))
    }

    private func modeTabButton(mode: AppMode, isLandscape: Bool, modeCount: Int) -> some View {
        let scale: CGFloat = modeCount >= 4 ? 1.0 / 1.2 : 1.0
        let baseButtonWidth: CGFloat = (isLandscape ? 157 : 117) * scale
        let iconSize: CGFloat = (isLandscape ? 109.2 : 115) * scale
        let textSize: CGFloat = (isLandscape ? 19 : 18) * scale
        let buttonHeight: CGFloat = ((isLandscape ? 76 : 80) + 3) * scale
        let iconPaddingBottom: CGFloat = (isLandscape ? 6 : 20) * scale
        let textPaddingBottom: CGFloat = (isLandscape ? 11 : 29) * scale
        let textLift: CGFloat = isLandscape ? -8 : 0
        let screenWidth = isLandscape
            ? max(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
            : UIScreen.main.bounds.width
        let horizontalReserved: CGFloat = isLandscape ? 32 : 44
        let rowSpacing: CGFloat = modeCount >= 4 ? 4 : 6
        let sideGutter: CGFloat = isLandscape ? 0 : (modeCount >= 4 ? 6 : 4)
        let maxRowWidth = max(
            0,
            screenWidth
                - horizontalReserved
                - (sideGutter * 2)
                - rowSpacing * CGFloat(max(modeCount - 1, 0))
        )
        let fittedButtonWidth = floor(maxRowWidth / CGFloat(max(modeCount, 1)))
        let requestedButtonWidth = baseButtonWidth * (isLandscape ? 1.56 : 1.1)
        let widenedFittedButtonWidth = floor(fittedButtonWidth * (isLandscape ? 1.2 : 1.1))
        let buttonWidth: CGFloat = modeCount >= 4
            ? min(requestedButtonWidth, widenedFittedButtonWidth)
            : baseButtonWidth

        return ZStack(alignment: .bottom) {
            tabIcon(for: mode, size: iconSize)
                .padding(.bottom, iconPaddingBottom)
            Text(mode.rawValue)
                .font(.system(size: textSize, weight: appMode == mode ? .semibold : .regular))
                .foregroundColor(appMode == mode ? .white : Color.black.opacity(0.82))
                .lineLimit(1)
                .padding(.bottom, textPaddingBottom)
                .offset(y: textLift)
        }
        .frame(width: buttonWidth, height: buttonHeight)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(appMode == mode ? Color.appPrimary : Color.white.opacity(0.45))
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
                        ForEach(activeMessages) { msg in
                            ChatBubbleView(
                                message: msg,
                                displayedCharacterCount: msg.isFromUser ? nil : (msg.id == typingMessageId ? typingDisplayedCount : nil)
                            )
                        }
                    }
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .onChange(of: activeMessages.count) { _ in scrollToBottom(proxy: proxy) }
            .onChange(of: typingDisplayedCount) { _ in scrollToBottom(proxy: proxy) }
        }
        .frame(maxHeight: .infinity)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = activeMessages.last {
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
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading || isAnyTTSPlaying)
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
            .disabled(isLoading || isAnyTTSPlaying)

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
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading || isAnyTTSPlaying)
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
        .disabled(isLoading || isAnyTTSPlaying)
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

    private func finishSynchronizedSpeechUI() {
        typingDisplayedCount = typingTargetCount
        typingMessageId = nil
        typingTargetCount = 0
        avatarState = .idle
    }

    private func setupTTSCallbacks() {
        tts.onSpeakingStarted = { avatarState = .speaking }
        tts.onSpeakingCompleted = { finishSynchronizedSpeechUI() }
        CloudTTSService.shared.onSpeakingStarted = { avatarState = .speaking }
        CloudTTSService.shared.onSpeakingCompleted = { finishSynchronizedSpeechUI() }
        AzureTTSService.shared.onSpeakingStarted = { avatarState = .speaking }
        AzureTTSService.shared.onSpeakingCompleted = { finishSynchronizedSpeechUI() }
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
            appendMessage(msg, to: appMode)
            startTypewriter(messageId: msg.id, fullText: greeting)
            if voiceOutputEnabled {
                speakResponse(greeting)
            }
        }
    }

    private func startVoiceInput() {
        guard ensureAuthenticatedOrRedirect() else { return }
        AppLogger.stt.info("startVoiceInput mode=\(appMode.rawValue, privacy: .public)")
        guard !isAnyTTSPlaying else { return }
        tts.stop()
        CloudTTSService.shared.stop()
        AzureTTSService.shared.stop()
        errorMessage = nil
        avatarState = .thinking
        wasVoiceInput = true
        stt.requestAuthorization { granted in
            guard granted else {
                AppLogger.stt.warning("startVoiceInput authorization denied")
                errorMessage = stt.errorMessage ?? "Microphone access needed."
                avatarState = .idle; return
            }
            stt.startRecording(language: dialogLanguage) { text in
                if let text = text, !text.isEmpty {
                    AppLogger.stt.info("voice input captured textLength=\(text.count, privacy: .public)")
                    inputText = text
                    sendMessage(text, fromVoice: true)
                } else {
                    AppLogger.stt.info("voice input captured no text")
                    avatarState = .idle
                }
            }
        }
    }

    private func sendMessage(_ text: String, fromVoice: Bool, isRetry: Bool = false) {
        guard ensureAuthenticatedOrRedirect() else { return }
        let requestMode = appMode
        guard requestMode == .chat || requestMode == .support else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isAnyTTSPlaying else {
            errorMessage = "Please wait for the current voice response to finish."
            return
        }
        AppLogger.dialog.info("sendMessage mode=\(appMode.rawValue, privacy: .public) fromVoice=\(fromVoice, privacy: .public) isRetry=\(isRetry, privacy: .public) textLength=\(trimmed.count, privacy: .public)")
        wasVoiceInput = fromVoice
        if !isRetry {
            inputText = ""
            appendMessage(ChatMessage(text: trimmed, isFromUser: true, wasVoiceInput: fromVoice, language: dialogLanguage), to: requestMode)
        }
        errorMessage = nil; lastFailedMessage = nil; isLoading = true; avatarState = .thinking
        if typingIndicatorEnabled { showTypingIndicator = true }
        startLongRequestNoticeTimer()

        Task {
            do {
                let apiBaseURL: String? = requestMode == .support ? APIConfig.supportBaseURL : nil
                let response = try await DialogAPIService.shared.sendMessage(trimmed, language: dialogLanguage, baseURL: apiBaseURL)
                await MainActor.run {
                    stopLongRequestNoticeTimer()
                    showTypingIndicator = false
                    let displayText = stripNoSpeechForDisplay(response)
                    let ttsText = stripNoSpeechForTTS(response)
                    let botMsg = ChatMessage(text: displayText, isFromUser: false, wasVoiceInput: fromVoice, language: dialogLanguage)
                    appendMessage(botMsg, to: requestMode)
                    isLoading = false
                    let shouldSpeak = voiceOutputEnabled
                        && (fromVoice || alwaysVoiceResponse)
                        && !ttsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    if shouldSpeak {
                        if appMode == requestMode {
                            typingMessageId = botMsg.id
                            typingDisplayedCount = 0
                            typingTargetCount = displayText.count
                        }
                        // Avatar/text are switched to "speaking" exactly when TTS playback actually starts.
                        speakResponse(ttsText)
                    } else {
                        if appMode == requestMode {
                            avatarState = .speaking
                            startTypewriter(messageId: botMsg.id, fullText: displayText)
                            let displayTime = Double(displayText.count) * 0.025 + 0.5
                            DispatchQueue.main.asyncAfter(deadline: .now() + displayTime) {
                                if avatarState == .speaking { avatarState = .idle }
                            }
                        }
                    }
                    saveChatHistory(for: requestMode)
                }
            } catch {
                await MainActor.run {
                    AppLogger.dialog.error("sendMessage failed mode=\(appMode.rawValue, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
                    stopLongRequestNoticeTimer()
                    showTypingIndicator = false; isLoading = false
                    errorMessage = error.localizedDescription; lastFailedMessage = trimmed; avatarState = .idle
                    let fallback = ChatMessage(text: "I'm having trouble connecting. Please try again.", isFromUser: false)
                    appendMessage(fallback, to: requestMode)
                    if appMode == requestMode {
                        startTypewriter(messageId: fallback.id, fullText: fallback.text)
                    }
                    saveChatHistory(for: requestMode)
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

    private func saveChatHistory(for mode: AppMode) {
        guard mode == .chat || mode == .support else { return }
        let toSave = Array(messages(for: mode).suffix(maxHistoryCount))
        setMessages(toSave, for: mode)
        let key = (mode == .support) ? supportHistoryKey : chatHistoryKey
        if let data = try? JSONEncoder().encode(toSave) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadAllHistories() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        let fullVersion = "\(currentVersion).\(currentBuild)"
        let lastVersion = UserDefaults.standard.string(forKey: lastVersionKey) ?? ""
        AppLogger.navigation.info("loadAllHistories currentVersion=\(fullVersion, privacy: .public) lastVersion=\(lastVersion, privacy: .public)")
        if fullVersion != lastVersion {
            AppLogger.navigation.info("version changed — clearing chat history and resetting avatar")
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
        if appMode == .chat {
            setMessages([], for: .chat)
            UserDefaults.standard.removeObject(forKey: chatHistoryKey)
        } else if appMode == .support {
            setMessages([], for: .support)
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
                        Text("\(activeMessages.count) messages")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    Button(role: .destructive) { clearChatHistory() } label: {
                        Label("Clear Chat History", systemImage: "trash")
                    }
                    .disabled(activeMessages.isEmpty)
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
    private var didAttemptCredentialAutoLogin = false

    func resetAuthInjectionReloadFlag() {}
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

    // Mirror Android WebView fix: neutralize forced HTML rotation and orientation media-query behavior.
    private let appStoreRotationFixJS = """
    (function(){
        if (window.__mvpRotationFixInstalled) {
            if (window._mvpFixHtmlRotation) { window._mvpFixHtmlRotation(); }
            return;
        }
        window.__mvpRotationFixInstalled = true;
        var s=document.createElement('style');
        s.textContent='html,html[style]{transform:none!important;width:100vw!important;height:auto!important;min-height:100vh!important;overflow:auto!important;position:relative!important;top:0!important;left:0!important;margin:0!important;}body{width:100vw!important;margin:0!important;position:relative!important;top:0!important;left:0!important;}';
        (document.head||document.documentElement).appendChild(s);
        try { Object.defineProperty(window,'orientation',{get:function(){return 0;},configurable:true}); } catch(e) {}
        try {
            Object.defineProperty(screen,'orientation',{
                get:function(){return{type:'portrait-primary',angle:0,addEventListener:function(){},removeEventListener:function(){},lock:function(){return Promise.resolve();},unlock:function(){}};},
                configurable:true
            });
        } catch(e) {}
        var origMM=window.matchMedia;
        window.matchMedia=function(q){
            if(q&&q.indexOf('orientation')!==-1){
                q=q.replace(/orientation\\s*:\\s*landscape/gi,'orientation: portrait');
            }
            return origMM.call(window,q);
        };
        window._mvpFixHtmlRotation=function(){
            var html=document.documentElement;
            if(!html) return;
            var cs=window.getComputedStyle(html);
            if(cs.transform&&cs.transform!=='none'){
                html.style.setProperty('transform','none','important');
                html.style.setProperty('width','100vw','important');
                html.style.setProperty('height','auto','important');
                html.style.setProperty('min-height','100vh','important');
                html.style.setProperty('overflow','auto','important');
                html.style.setProperty('position','relative','important');
                html.style.setProperty('top','0','important');
                html.style.setProperty('left','0','important');
                html.style.setProperty('margin','0','important');
                if(document.body){
                    document.body.style.setProperty('width','100vw','important');
                    document.body.style.setProperty('margin','0','important');
                    document.body.style.setProperty('position','relative','important');
                    document.body.style.setProperty('top','0','important');
                    document.body.style.setProperty('left','0','important');
                }
                window.scrollTo(0,0);
            }
        };
        var mo=new MutationObserver(function(){window._mvpFixHtmlRotation();});
        document.addEventListener('DOMContentLoaded',function(){
            mo.observe(document.documentElement,{attributes:true,attributeFilter:['style','class']});
            window._mvpFixHtmlRotation();
        });
        window._mvpFixHtmlRotation();
        setTimeout(window._mvpFixHtmlRotation,1000);
        setTimeout(window._mvpFixHtmlRotation,3000);
    })();
    """

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        injectAuthSession(webView)
        scheduleCredentialAutoLogin(webView)
        applyRotationFix(webView)
    }

    private func applyRotationFix(_ webView: WKWebView) {
        webView.evaluateJavaScript(appStoreRotationFixJS, completionHandler: nil)
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

    private func scheduleCredentialAutoLogin(_ webView: WKWebView) {
        guard !didAttemptCredentialAutoLogin else { return }
        guard savedEmail != nil, !(savedEmail ?? "").isEmpty,
              savedPassword != nil, !(savedPassword ?? "").isEmpty
        else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self, weak webView] in
            guard let self, let webView, !self.didAttemptCredentialAutoLogin else { return }
            self.injectCredentialAutoLogin(webView)
        }
    }

    private func injectCredentialAutoLogin(_ webView: WKWebView) {
        guard !didAttemptCredentialAutoLogin else { return }
        guard
            let email = savedEmail, !email.isEmpty,
            let password = savedPassword, !password.isEmpty
        else { return }

        let emailB64 = Data(email.utf8).base64EncodedString()
        let pwdB64 = Data(password.utf8).base64EncodedString()
        let js = """
        (function() {
            var email = atob('\(emailB64)');
            var pwd = atob('\(pwdB64)');
            var desc = Object.getOwnPropertyDescriptor(window.HTMLInputElement && window.HTMLInputElement.prototype, 'value');
            var setter = desc && desc.set;
            var inputs = document.querySelectorAll('input');
            var e = null, p = null;
            for (var i = 0; i < inputs.length; i++) {
                var inp = inputs[i];
                if ((inp.type === 'email' || inp.type === 'text') &&
                    ((inp.placeholder || '').toLowerCase().indexOf('email') !== -1 || inp.name === 'email' || (inp.id || '').toLowerCase().indexOf('email') !== -1)) {
                    e = inp; break;
                }
            }
            for (var i = 0; i < inputs.length; i++) {
                var inp = inputs[i];
                if (inp.type === 'password' || (inp.placeholder || '').toLowerCase().indexOf('password') !== -1 || (inp.name || '').toLowerCase().indexOf('password') !== -1 || (inp.autocomplete || '').indexOf('password') !== -1) {
                    p = inp; break;
                }
            }
            if (!e) e = document.querySelector('input[type="email"],input[name="email"],#lf_email');
            if (!p) p = document.querySelector('input[type="password"],input[name="password"],input[autocomplete*="password"],#lf_pass');
            if (!e || !p) return false;
            if ((e.value || '').length > 0 && (p.value || '').length > 0) return false;
            function fillInp(inp, val) {
                if (setter) setter.call(inp, val);
                else inp.value = val;
                inp.focus();
                inp.dispatchEvent(new Event('input', { bubbles: true }));
                inp.dispatchEvent(new Event('change', { bubbles: true }));
                inp.dispatchEvent(new Event('blur', { bubbles: true }));
            }
            fillInp(e, email);
            fillInp(p, pwd);
            var btn = document.querySelector('button[type="submit"],button#lf_btn,.btn');
            if (!btn) {
                var btns = document.querySelectorAll('button');
                for (var j = 0; j < btns.length; j++) {
                    var txt = (btns[j].textContent || '').trim().toLowerCase();
                    if (txt === 'continue' || txt === 'login' || txt === 'sign in' || txt === 'log in') {
                        btn = btns[j]; break;
                    }
                }
            }
            if (btn) setTimeout(function() { p.focus(); btn.click(); }, 600);
            return true;
        })();
        """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            if let didSubmit = result as? Bool, didSubmit {
                self?.didAttemptCredentialAutoLogin = true
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
    private var lastIsLandscape: Bool?
    private var appStoreAuthTask: Task<Void, Never>?
    let navDelegate = AppStoreNavDelegate()

    func getOrCreate(url: URL, token: String?, isLandscape: Bool) -> WKWebView {
        if let wv = webView {
            syncSession(url: url, token: token, in: wv)
            updateOrientation(isLandscape, in: wv)
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
        lastIsLandscape = isLandscape
        navDelegate.isLandscape = isLandscape
        syncSession(url: url, token: token, in: wv, forceReload: true)
        return wv
    }

    func updateOrientation(_ isLandscape: Bool, in webView: WKWebView? = nil) {
        let target = webView ?? self.webView
        guard let target else { return }
        navDelegate.isLandscape = isLandscape
        lastIsLandscape = isLandscape

        // Android-parity path: run the in-page rotation-fix hook on orientation updates.
        let reapplyFixJS = """
        (function () {
            try {
                if (window._mvpFixHtmlRotation) { window._mvpFixHtmlRotation(); }
                window.dispatchEvent(new Event('resize'));
            } catch (e) {}
        })();
        """
        target.evaluateJavaScript(reapplyFixJS, completionHandler: nil)
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
                    if let t = bootstrap?.token {
                        KeychainService.shared.saveAppStoreToken(t)
                    }
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
        lastIsLandscape = nil
    }
}

struct AppStoreWebView: UIViewRepresentable {
    let url: URL
    let token: String?
    var isLandscape: Bool = false

    func makeUIView(context: Context) -> WKWebView {
        let wv = AppStoreWebViewStore.shared.getOrCreate(url: url, token: token, isLandscape: isLandscape)
        AppStoreWebViewStore.shared.navDelegate.isLandscape = isLandscape
        return wv
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let store = AppStoreWebViewStore.shared
        store.syncSession(url: url, token: token, in: webView)
        store.updateOrientation(isLandscape, in: webView)
        DispatchQueue.main.async {
            store.syncSession(url: url, token: token, in: webView)
            webView.setNeedsLayout()
            webView.layoutIfNeeded()
        }
    }
}

// MARK: - WebGatewayView

/// Full-screen panel shown when the WEB button in the top bar is active.
/// Detects the default LAN gateway via SystemConfiguration and loads
/// http://<gateway>:80 in a WKWebView. Shows an inline message when the
/// device is not on a local network or port 80 is unreachable.
struct WebGatewayView: View {

    private enum LoadState {
        case detecting
        case loading(url: URL)
        case notOnLAN
        case unreachable(ip: String)
    }

    @State private var state: LoadState = .detecting
    @State private var webView: WKWebView? = nil

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            switch state {
            case .detecting:
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.4)
                    Text("Detecting local gateway…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

            case .loading(let url):
                WebGatewayWebView(url: url)

            case .notOnLAN:
                inlineMessage(
                    systemImage: "wifi.slash",
                    title: "Not on a local network",
                    body: "Connect to a Wi-Fi network whose gateway is accessible on port 80."
                )

            case .unreachable(let ip):
                inlineMessage(
                    systemImage: "antenna.radiowaves.left.and.right.slash",
                    title: "Gateway not responding",
                    body: "The gateway at \(ip) is not reachable on port 80.\nMake sure the device has a web interface enabled."
                )
            }
        }
        .task {
            await detect()
        }
    }

    // MARK: - Helpers

    private func detect() async {
        state = .detecting
        let result = await GatewayService.shared.resolve()
        await MainActor.run {
            switch result {
            case .found(let ip):
                if let url = URL(string: "http://\(ip)") {
                    state = .loading(url: url)
                } else {
                    state = .unreachable(ip: ip)
                }
            case .notOnLAN:
                state = .notOnLAN
            case .unreachable(let ip):
                state = .unreachable(ip: ip)
            }
        }
    }

    @ViewBuilder
    private func inlineMessage(systemImage: String, title: String, body: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 52, weight: .light))
                .foregroundColor(.secondary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Button {
                Task { await detect() }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.appPrimary.opacity(0.15))
                    .foregroundColor(Color.appPrimary)
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - WebGatewayWebView (UIViewRepresentable)

/// Lightweight single-use WKWebView that loads the gateway URL.
/// Each WebGatewayView instance gets its own WKWebView — no shared state needed
/// because the gateway URL is local and stateless.
private struct WebGatewayWebView: UIViewRepresentable {

    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true
        wv.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10))
        return wv
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
