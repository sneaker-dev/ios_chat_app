 Changelog – iOS Voice Assistant

All notable changes to this project are documented in this file.
[Unreleased]

 Added
- Structured crash diagnostics logging across iOS services (#44935):
  - Introduce centralized `AppLogger` categories (auth, keychain, dialog, stt, tts, appstore, navigation)
  - Add contextual log breadcrumbs for app launch/navigation, auth flows, dialog requests, and voice interactions
  - Keep sensitive values masked while improving failure visibility for post-crash investigation

- App Store tab auto-login with saved credentials (#44921):
  - Password persisted in Keychain on successful login
  - Native HTTP login attempt on App Store tab open; credential injection as fallback
  - `AppStoreAuthService` extracted to Services layer for all App Store auth logic
  - `appStoreURL` uses `appstore-demo.inango.com` with `MVP_APP_STORE_URL` env override

 Changed
- Custom top-bar icons and tab-button layout (#44919):
  - Replace default top-bar icons with custom AvatarSelect, SettingsIcon, and Inango logo assets
  - Refactor tab buttons with ZStack overlay so text sits close to the icon
  - Remove divider background from tab button row
  - Uniform icon sizing and visual parity with Android
  - Align avatar position with top-bar bottom edge

Fixed
- iOS client feedback bundle for BugID #44961:
  - Synchronize streamed response text with local/cloud TTS playback and block new input while speaking
  - Align Support endpoint resolution with Android-compatible route handling
  - Refine landscape top bar and mode tabs (size/position/width/height/spacing) for responsive layout
  - Isolate Conversation and Support histories to prevent cross-tab message mixing
  - Keep App Store/Problems content below mode tabs and improve inactive tab contrast/readability
  - Apply App Store landscape rendering stabilization so content remains upright and responsive
  - Regenerate required AppIcon assets for App Store validation-critical sizes


 [2026-03-11]

 Added
- Restore Communication Language and Cloud TTS Provider settings in Settings tab (#44920):
  - Language selection wired to STT/TTS flow
  - Cloud TTS Provider options: Local, Google, Azure
- App Store URL fix: use `appstore-demo.inango.com`, landscape login form for App Store tab

[2026-03-10]

 Fixed
- Cloud TTS not applied to long responses (#44821):
  - Split long TTS text into chunks so Google Cloud and Azure handle responses of any length
  - Moved shared chunking and playback logic to `BaseTTSService`

 Fixed
- Stop all TTS services before starting a new voice request to prevent overlapping playback

 [2026-03-09]

 Fixed
- Re-authentication flow for HTTP 401 responses:
  - Single global session-expired notification for clustered 401 responses
  - Auto-logout and prompt to log in again

 [2026-03-08]

 Improved
- Offline STT fallback for air-gapped mode (#44798):
  - Prefer on-device speech recognition for Tap to Speak
  - Clear offline error handling when on-device recognition is unavailable

 [2026-03-07]

 Added
- No-speech tag filtering: suppress empty `<no-speech>` responses from being spoken or displayed
- Long-request processing notice: show a waiting indicator for slow server responses
- Stop previous TTS playback when Tap to Speak is activated

 [2026-02-16]

 Added
- Initial code commit: iOS Voice Assistant app with Chat, Support, and App Store tabs; avatar view; TTS (Local/Google/Azure); STT; login/register flow; Settings sheet
