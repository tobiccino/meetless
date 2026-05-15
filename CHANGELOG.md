# Changelog

## Unreleased

- Added Korean transcription support by switching the bundled Whisper model to the multilingual `ggml-base.bin` model.
- Added transcript output language settings for English, Korean, and Vietnamese.
- Added Gemini and OpenAI-compatible transcript translation providers with Keychain-backed API key storage.
- Preserved original transcript text as hidden metadata when translated display text is saved.
- Updated DMG packaging to verify the multilingual model and support ad-hoc local signing.
- Kept local Whisper model binaries out of Git and made bootstrap download the multilingual model when missing.
