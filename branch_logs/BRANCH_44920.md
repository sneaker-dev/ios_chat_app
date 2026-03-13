# Branch: inango_n44920_settings_language_tts_ios

**Redmine:** [#44920](https://redmine.inango.com/issues/44920)

## Contents

- Reintroduce Communication Language and Cloud TTS Provider options in Settings
- Wire selected language to STT/TTS flow
- Restore provider-based playback (Local/Google/Azure) behavior missing from current branch

## Changes

- Add SupportedLanguageItem and SupportedLanguages
- Add @AppStorage for selectedLanguage, cloudTTSEnabled, cloudTTSProvider
- Add Language and Cloud TTS sections to Settings sheet
- Add speakResponse() function for provider-based TTS
- Update SpeechToTextService to accept language parameter
