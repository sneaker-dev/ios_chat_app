CHANGELOG - iOS (MVP)
=====================

This file records notable changes to the iOS app over time.
Entries are listed from newest to oldest.


2026-01-28

  UI improvements: top bar spacing, icon sizes, and tab layout

  Adjusted the spacing above and below the Inango logo so both gaps are
  visually equal. Increased the avatar and settings icon sizes by 1.2x.
  Tab buttons now size themselves dynamically based on icon and text height,
  with a clean 5pt gap between the icon and the label. Updated internal
  layout offsets to keep the avatar and chat area correctly positioned below
  the top bar.

  Reduced the two large empty areas that appeared above and below the Inango
  logo row. The root cause was that the safe-area padding and the button row
  height were never being adjusted by earlier spacing edits. Both are now
  correctly halved.

  Moved the Inango logo slightly to the right to match the Android layout.
  Removed the visible divider border around the three tab buttons. Reduced
  the height of the tab buttons and brought the icon and text label closer
  together.

  Made the Inango logo 3x smaller after it was accidentally enlarged in a
  previous pass. Doubled the size of all five icons (avatar, settings, and
  three tabs). Set button heights to naturally accommodate the larger icons.

  Restored the Inango logo image asset after it was accidentally replaced
  with plain text during a conflict resolution. Removed the dark transparent
  background from the avatar and settings icon buttons. Tripled the logo
  size and halved the tab button heights.

  Restored full iOS UI parity with Android: removed unnecessary dark
  backgrounds from top-right icons, doubled icon sizes for avatar and
  settings buttons, and halved the height of all three mode tab buttons.


2026-01-20

  Restored custom PNG icon assets for top bar and tabs

  Reintroduced the InangoTopbarLogo, TabChat, TabSupport, TabAppStore,
  AvatarSelect, and SettingsIcon image assets. Icons now use their original
  colors instead of being tinted white. Implemented a zoom-inside-clip
  approach to make icons appear larger and clearer within their frames.


2026-01-18

  App Store WebView authentication hardened

  The App Store tab now performs a native login before loading the WebView.
  The app tries multiple API endpoints and HTTP methods to obtain a session
  token and server cookies, then injects them into the WebView before the
  page loads. This ensures the user is already authenticated when the App
  Store opens, without requiring a manual login every time.

  Added a credential-based fallback: if token injection does not result in
  a logged-in state, the app fills and submits the login form automatically
  using the credentials saved from the last successful login.


2026-01-15

  Restored language and TTS provider settings (Bug 44821)

  The Communication Language and Cloud TTS Provider options were missing
  from the Settings tab after a branch sync. These have been reintroduced.
  The selected language is now wired to the speech recognition and TTS
  flow, and the provider selection (Local, Google, Azure) controls playback
  behavior correctly again.


2026-01-10

  Problems tab added for Inango users (Bug 44889)

  A new Problems tab appears as the fourth mode in the tab bar, but only
  for users whose email address ends with @inango-systems.com. The tab
  shows a list of emulatable board problems fetched from the Problems API.
  Each problem can be individually enabled or disabled with a toggle.
  The screen handles loading, error, and retry states. Changes are applied
  optimistically and rolled back if the server returns an error.

  The Problems API previously used a temporary demo-token for
  authentication. This has been replaced with the real AppStore session
  token, following a backend update that removed demo-token support.


2025-12-01

  Initial iOS project baseline

  Core chat interface with voice input, text input, and avatar display.
  App Store tab with WKWebView integration. Login and registration screens
  with Keychain-based credential storage. Support for multiple dialog modes
  (Chat, Support, AppStore).
