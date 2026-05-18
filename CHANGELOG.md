# Changelog

## Unreleased

- Added Meeting/Me recording lane toggles so each saved recording can capture either or both audio sources.
- Added custom transcript translation prompt templates with required placeholders, live validation, and prompt-writing guidance for LLM providers.
- Expanded transcription and transcript output language selectors into alphabetized dropdown catalogs, including Auto Detect for transcription.
- Limited transcription and transcript output language selectors to scrollable popovers so large language catalogs stay usable in Settings.
- Filtered protected transcript markers (`Bắt đầu`, `Kết thúc`) before translation, display, and saved transcript snapshots.
- Added Korean transcription support by switching the bundled Whisper model to the multilingual `ggml-base.bin` model.
- Added selectable local Whisper transcription model presets with download, install, remove, smoke-test, and fallback handling.
- Added richer Whisper model details in Settings, including storage footprint, relative CPU/RAM cost, multilingual or English-only support, quantized status, and recommended use.
- Added transcript output language settings for English, Korean, and Vietnamese.
- Added Gemini, OpenAI-compatible, and Google Translate transcript translation providers with Keychain-backed API key storage.
- Added Test Key actions for Gemini, OpenAI, and Google Translate API keys without persisting typed secrets.
- Added a custom About window with Meetless product messaging and Tobiccino branding.
- Added Gemini translation model presets for stable, preview, latest-alias, and compatibility model IDs while keeping custom model entry available.
- Added translation context selection with fixed read-only prompt previews for domain-aware transcript translation.
- Added live transcript rows so partial transcript and translation progress can stream in the recording view before persisted chunks commit.
- Kept the live recording transcript scrolled to the newest row as transcript content updates.
- Paused live transcript auto-scroll while the user reviews earlier rows, resuming only after they scroll back to the bottom.
- Buffered split transcript fragments before translation so incomplete phrases are not sent to the translation API until a sentence boundary, size/time threshold, or Stop flush.
- Skipped translation API calls when the transcription input language and transcript output language are the same.
- Preserved and displayed original transcript text above translated transcript rows, with italic styling and spacing, when translation succeeds.
- Updated DMG packaging to verify the multilingual model and support ad-hoc local signing.
- Kept local Whisper model binaries out of Git and made bootstrap download the multilingual model when missing.
