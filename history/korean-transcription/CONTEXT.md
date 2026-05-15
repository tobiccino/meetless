# Korean Transcription Context

## Locked Decisions

- Meetless supports two fixed local transcription languages for v1: English
  (`en`) and Korean (`ko`).
- The selected language is global Settings state backed by `UserDefaults`.
- The default language is English.
- Language changes apply to the next recording session and the next smoke
  transcription run.
- Korean transcripts are kept as Korean text. Meetless does not translate them
  to English.
- The bundled Whisper model is multilingual `ggml-base.bin`; the English-only
  `ggml-tiny.en.bin` model is no longer bundled.

## Validation

- Focused settings and bridge tests passed on 2026-05-15:
  `xcodebuild test -project Meetless.xcodeproj -scheme Meetless -destination 'platform=macOS,arch=arm64' -only-testing:MeetlessTests/GeminiAPIKeyStoreTests CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=-`
- Full test suite passed on 2026-05-15: 62 tests, 0 failures.
- Release build with signing disabled passed on 2026-05-15, and the built app
  contained `Contents/Resources/ggml-base.bin` plus the embedded `whisper`
  framework binary.
