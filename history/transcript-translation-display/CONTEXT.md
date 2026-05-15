# Transcript Translation Display Context

## Locked Decisions

- Meetless keeps "Transcription language" as the Whisper source language.
- Meetless adds "Transcript output language" for displayed and saved transcript rows.
- V1 output languages are English (`en`), Korean (`ko`), and Vietnamese (`vi`), defaulting to English.
- Translation runs per committed Whisper window after filtering and before the chunk is appended or published.
- If source and output languages match, Meetless skips LLM translation and commits the original text.
- Gemini is the default translation provider and reuses the existing Gemini Keychain API key.
- OpenAI is available as a translation provider using its own Keychain-backed API key and the Responses API.
- Translation failure must not stop recording or block Stop. Meetless commits original text and records a degraded translation status.
- Saved `transcript.json` rows display `text` only. Original transcript text may be stored in hidden fields for audit/debug but is not shown in v1.

## Validation Plan

- Focused unit tests for settings defaults/persistence/fallbacks, provider request shape/parsing, translation success/failure/skip, and legacy transcript loading.
- Full macOS test suite with signing disabled:
  `xcodebuild test -project Meetless.xcodeproj -scheme Meetless -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=-`

