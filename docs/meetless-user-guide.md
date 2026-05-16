# Meetless User Guide

Meetless is a native macOS meeting recorder for local-first meeting capture,
transcription, translation, saved session review, and optional AI-generated
meeting notes.

Meetless records meeting audio and microphone audio as separate local sources,
then turns them into a readable transcript timeline. Saved sessions can be
reopened later, reviewed, deleted, or enriched with a generated summary and
action items.

<!-- Screenshot: Meetless main window / Record screen -->

## What Meetless Does

Meetless is designed for users who want a lightweight local recorder for online
meetings, calls, interviews, and review sessions.

Key capabilities:

- Record meeting/system audio and your microphone as separate audio sources.
- Transcribe recordings locally on the Mac with the bundled Whisper model.
- Choose transcription language for supported local transcription modes.
- Translate transcripts into the configured output language.
- Use Gemini, OpenAI-compatible providers, or Google Translate for transcript
  translation.
- Save completed recording sessions locally.
- Reopen saved sessions with transcript, metadata, notices, and source health.
- Generate permanent meeting notes with Gemini from saved session audio.
- Store provider API keys in macOS Keychain.

## System Requirements

- macOS 15 or newer.
- Microphone access.
- Screen Recording access for meeting/system audio capture.
- Network access only when using online providers:
  - Gemini for notes generation or Gemini transcript translation.
  - OpenAI-compatible API for OpenAI transcript translation.
  - Google Cloud Translation API key for Google Translate.

Meetless stores saved sessions locally under the user's Application Support
directory. Audio and transcript artifacts remain on the Mac unless the user
explicitly confirms a Gemini notes-generation upload.

## Install Meetless From a DMG

1. Download the Meetless `.dmg` file from the trusted distribution source.
2. Double-click the `.dmg` file.
3. Drag `Meetless.app` into the `Applications` folder.
4. Eject the DMG after the copy finishes.
5. Launch Meetless from `Applications`.

<!-- Screenshot: DMG window with Meetless.app and Applications shortcut -->

## Gatekeeper Approval

macOS Gatekeeper may block the first launch when Meetless is distributed as an
internal, ad-hoc signed, or unnotarized build. This is expected for internal
testing builds. Only continue if you trust the source of the DMG.

Apple's recommended approval path is to explicitly allow the app from System
Settings after macOS blocks the first launch. Reference:
[Apple Support: Safely open apps on your Mac](https://support.apple.com/en-ca/102445).

### Recommended Gatekeeper Bypass

Use these steps for macOS 15 and newer:

1. Open `Applications`.
2. Double-click `Meetless.app`.
3. If macOS shows a warning such as `Meetless Not Opened` or says Apple could
   not verify the app, click `Done` or close the warning.
4. Open `System Settings`.
5. Go to `Privacy & Security`.
6. Scroll down to the `Security` section.
7. Find the message saying Meetless was blocked.
8. Click `Open Anyway`.
9. Confirm with Touch ID, administrator password, or the system confirmation
   prompt.
10. In the final warning dialog, click `Open`.
11. Meetless should now launch normally.

<!-- Screenshot: Privacy & Security showing Open Anyway for Meetless -->

After this approval, macOS should remember the decision for this copied app.
If you replace Meetless with a new build, you may need to repeat the same steps.

### Alternative Control-Click Method

On some macOS versions or warning types, this path is enough:

1. Open `Applications`.
2. Hold `Control` and click `Meetless.app`.
3. Choose `Open`.
4. Confirm by clicking `Open` in the warning dialog.

If macOS still blocks the app, use the recommended `Privacy & Security` flow
above.

### Fallback Terminal Approval for Trusted Internal Builds

Use this only for a Meetless build you trust and intentionally installed. This
removes the quarantine attribute from the copied app bundle:

```zsh
xattr -dr com.apple.quarantine /Applications/Meetless.app
```

Then open the app:

```zsh
open /Applications/Meetless.app
```

Do not run this command on apps from unknown sources. Prefer the System Settings
approval flow whenever possible.

## First Launch

When Meetless opens, the left sidebar contains the main sections:

- `Record`: Start and stop local meeting recording.
- `Sessions`: Browse saved sessions.
- `Settings`: Configure transcription, translation, models, and API keys.

The bottom of the sidebar shows the local app status.

<!-- Screenshot: First launch with sidebar -->

## Grant macOS Permissions

Meetless asks for permissions only when recording needs them. Recording cannot
start fully until the required access is granted.

### Microphone Permission

1. Open Meetless.
2. Go to `Record`.
3. Click `Start Recording`.
4. If macOS asks for microphone access, allow it.
5. If Meetless shows a microphone repair action, click the action to open
   Microphone settings.
6. In `System Settings > Privacy & Security > Microphone`, enable Meetless.
7. Return to Meetless.
8. Click `Retry Recording`.

### Screen Recording Permission

Screen Recording permission is required for meeting/system audio capture.

1. Open Meetless.
2. Go to `Record`.
3. Click `Start Recording`.
4. If Meetless reports missing Screen Recording access, click
   `Open Screen Recording Settings`.
5. In `System Settings > Privacy & Security > Screen & System Audio Recording`
   or `Screen Recording`, enable Meetless.
6. Quit Meetless completely.
7. Reopen Meetless.
8. Go back to `Record`.
9. Click `Start Recording` again.

Screen Recording changes require quitting and reopening the app before macOS
applies the permission to recording capture.

<!-- Screenshot: Meetless permission repair state -->

## Configure Settings

Open `Settings` from the sidebar before your first real recording.

<!-- Screenshot: Settings screen -->

### Local Transcription

Use this section to configure local Whisper transcription.

1. Open `Settings`.
2. Choose the transcription language.
3. Choose the local Whisper model preset if multiple presets are available.
4. Use the model smoke test when available to confirm that the selected model
   can load and transcribe the bundled sample.

The selected transcription language applies to the next recording.

### Transcript Output Language

Meetless can keep the transcript in the source language or translate it.

1. Open `Settings`.
2. Select the transcript output language.
3. If the output language is the same as the transcription language, Meetless
   skips translation.
4. If the output language differs, Meetless uses the selected translation
   provider during recording.

### Translation Provider

Meetless supports these transcript translation providers:

- `Gemini`: Uses the saved Gemini API key.
- `OpenAI-compatible`: Uses a separate saved OpenAI API key.
- `Google Translate`: Uses a separate Google Cloud Translation API key.

For Gemini and OpenAI-compatible providers, Settings also shows LLM-specific
controls such as model, base URL, translation context, and prompt preview.
Google Translate hides those LLM-only controls.

### Save API Keys

API keys are stored in macOS Keychain.

Gemini key:

1. Open `Settings`.
2. Find the Gemini API key section.
3. Paste the Gemini API key.
4. Click `Save Key`.

OpenAI-compatible key:

1. Open `Settings`.
2. Find the OpenAI section.
3. Paste the API key.
4. Click `Save Key`.

Google Translate key:

1. Open `Settings`.
2. Find the Google Translate section.
3. Paste the Cloud Translation API key.
4. Click `Save Key`.

If a provider rejects a saved key during translation, Meetless keeps recording
and saves the original transcript text with a warning.

## Record a Meeting

1. Open Meetless.
2. Go to `Record`.
3. Confirm the transcription and translation settings are correct.
4. Click `Start Recording`.
5. Join or continue the meeting normally.
6. Watch the live transcript rows appear as Meetless transcribes committed
   windows.
7. Click `Stop Recording` when finished.
8. Wait for Meetless to finalize the saved session.

Meetless records two local source lanes:

- `Meeting`: meeting/system audio captured through ScreenCaptureKit.
- `Me`: microphone audio.

The final saved transcript merges committed transcript rows into one timeline.

<!-- Screenshot: Active recording with live transcript -->

## Review Saved Sessions

1. Open `Sessions` from the sidebar.
2. Click `Refresh` if you expect newly saved sessions.
3. Review the table:
   - `Name`: saved session title.
   - `Date`: recording date.
   - `Duration`: completed duration or in-progress state.
   - `Status`: completed, warning, or incomplete state.
4. Click `Detail` for a session you want to inspect.
5. Click the trash button to delete a saved session you no longer need.

<!-- Screenshot: Sessions list -->

## Session Detail

The session detail screen shows:

- Transcript timeline.
- Session metadata.
- Notices.
- Input health and source health.
- Generated notes when available.

Use `Back` to return to the sessions list.

<!-- Screenshot: Session detail with transcript and metadata -->

## Generate Meeting Notes

Gemini notes generation is optional and user-confirmed. It uploads saved audio
artifacts for the selected session to Gemini.

Before generating notes:

1. Open `Settings`.
2. Save a valid Gemini API key.
3. Record and save a session.
4. Open `Sessions`.
5. Click `Detail` for the saved session.

Generate notes:

1. Click `Generate`.
2. Read the confirmation dialog.
3. Confirm only if you want Meetless to upload saved audio for that session to
   Gemini.
4. Wait for generation to finish.
5. Review the generated `Summary` and `Action Items`.

Notes are permanent for the current version. After notes exist for a session,
the generate action is disabled for that session.

<!-- Screenshot: Generated notes section -->

## Delete a Session

1. Open `Sessions`.
2. Click the trash button for a row, or open `Detail` and click `Delete`.
3. Confirm the deletion.

Deleting a session removes the local session bundle, including transcript
snapshot and saved audio artifacts.

## Common Warnings

### Input Health Warning

An input health warning means one source continued with reduced capture or
transcription health. Meetless still preserves the saved session with the
available transcript and audio artifacts.

### Translation Warning

A translation warning means the selected provider could not translate a
transcript window. Meetless keeps recording and saves the original transcript
text.

Common causes:

- Missing provider API key.
- Invalid or rejected API key.
- Network failure.
- Provider response error.

### Incomplete Session

An incomplete session means recording stopped unexpectedly or Meetless had to
save after an interrupted stop. Open the session detail to inspect available
audio, transcript, metadata, and notices.

## Troubleshooting

### Meetless Does Not Open

1. Confirm the app is in `/Applications`.
2. Follow the Gatekeeper approval steps in this guide.
3. If the app was copied from an untrusted or modified DMG, delete it and
   install again from the trusted source.

### Recording Is Blocked

1. Open `Record`.
2. Check the repair action shown by Meetless.
3. Grant Microphone access if requested.
4. Grant Screen Recording access if requested.
5. Quit and reopen Meetless after changing Screen Recording access.
6. Click `Retry Recording`.

### Transcript Does Not Translate

1. Open `Settings`.
2. Confirm the transcript output language differs from the transcription
   language.
3. Confirm the selected provider has a saved API key.
4. For Gemini or OpenAI-compatible providers, confirm model and base URL values.
5. Try a short new recording.
6. Review notices in the saved session detail if translation still fails.

### Generate Is Disabled

Generate can be disabled when:

- A Gemini API key is missing.
- The session already has generated notes.
- Session detail is still loading.
- The saved session does not have usable audio artifacts.

### Where to Check Logs

Use Console.app:

1. Open `Console`.
2. Search for `Meetless`.
3. Filter by process name `Meetless` or bundle identifier `com.themrb.meetless`.

Use Terminal for live logs:

```zsh
log stream --predicate 'process == "Meetless"' --style compact
```

## Data and Privacy Notes

- Recording and transcription are local by default.
- Saved sessions are stored locally on the Mac.
- API keys are stored in macOS Keychain.
- Gemini notes generation uploads saved audio only after user confirmation.
- Transcript translation uses the selected online provider only when source and
  output languages differ.
- If translation fails, Meetless keeps the original transcript text.

## Screenshot Checklist

Add screenshots for these areas when available:

- DMG installation window.
- Gatekeeper block dialog.
- Privacy & Security `Open Anyway` approval.
- First launch / sidebar.
- Settings with transcription and translation controls.
- API key provider sections.
- Active recording with live transcript.
- Sessions list.
- Session detail.
- Generated notes.
- Permission repair state.
