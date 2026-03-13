# Branch: inango_n44889_board_problems_emulation_ios

**Redmine:** [#44889](https://redmine.inango.com/issues/44889)

## Contents

- Board problems emulation on iOS
- Restore communication language and TTS provider settings in Settings
- Use AppStore token for iOS Problems API (remove demo-token fallback; always use authenticated Bearer tokens)

## Changes

- Add board problems emulation (catalog/active/toggle API integration)
- Reintroduce Communication Language and Cloud TTS Provider options in Settings
- Wire selected language to STT/TTS flow
- Remove demo-token fallback from Problems API; use AppStore/session Bearer tokens
