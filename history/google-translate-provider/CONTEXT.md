# Google Translate Provider Context

## Locked Decisions

- Add Google Translate as a curated transcript translation provider alongside Gemini and OpenAI-compatible providers.
- Use Cloud Translation Basic v2 with a dedicated API key stored in macOS Keychain.
- Keep Gemini as the default provider.
- Google Translate uses source/output language codes directly and does not use Meetless' LLM prompt, translation context, model field, or base URL UI.
- Translation failure behavior stays unchanged: recording continues, original text is committed, and the transcript row is marked degraded.
- Saved transcript schema remains unchanged.

## Validation Plan

- Focused tests for Google provider settings, Keychain storage, request URL/query parameters, response parsing, missing key, and malformed response handling.
- Full macOS test suite with signing disabled:
  `xcodebuild test -project Meetless.xcodeproj -scheme Meetless -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=-`
