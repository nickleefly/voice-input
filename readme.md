# VoiceInput

A macOS menu-bar voice input app. Hold Fn to record, release to
inject transcribed text into the focused input field.

## Install (recommended)

Requires macOS 14+. Open Terminal (⌘+Space → "Terminal") and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/nickleefly/voice-input/main/install.sh | bash
```

Then:

1. When System Settings opens, toggle **VoiceInput** ON under
   **Privacy & Security → Accessibility**.
2. Quit VoiceInput from the menu bar (icon → Quit).
3. Relaunch from `/Applications/VoiceInput.app`.
4. Hold the **Fn** key to record, release to inject.

The installer downloads the latest release, strips the macOS
quarantine attribute, re-signs the app locally so Accessibility
permissions stick, and clears any stale TCC grants.

If the Fn key still doesn't trigger after granting permission,
check `~/.voiceinput-debug.log`.

## Build from source

Requires Swift 5.9+.

```bash
make build          # Build .app bundle
make run            # Build and launch
make install        # Install to /Applications
make clean          # Clean build artifacts
```

After install, grant Accessibility permission in
System Settings → Privacy & Security → Accessibility.

## Cutting a release

Tagging a `v*` tag triggers `.github/workflows/release.yml`, which
builds the `.app` and uploads `VoiceInput.zip` to a GitHub Release.
The `install.sh` script always pulls from the latest release.

```bash
git tag v1.0.0 && git push --tags
```

## Prompt

```
claude \
  --dangerously-skip-permissions \
  --output-format=stream-json \
  --verbose \
  -p "Please implement a macOS menu-bar voice input
app (Swift, macOS 14+) with the following requirements:

1. Hold the Fn key to record, release to inject the
   transcribed text into the currently focused input
   field. Use streaming transcription (Apple Speech
   Recognition framework) as preferred approach.
   Monitor Fn key globally via CGEvent tap, suppressing
   the Fn event to prevent triggering the emoji picker.

2. Default language must be Simplified Chinese (zh-CN),
   ensuring Chinese input recognition works out of the
   box. Also provide language switching options in the
   menu bar (English, Simplified Chinese, Traditional
   Chinese, Japanese, Korean). Language selection is
   stored in UserDefaults.

3. While recording, display an elegant frameless
   capsule-shaped floating window centered at the
   bottom of the screen — no traffic lights or
   titlebar. Use NSPanel (nonactivatingPanel) +
   NSVisualEffectView (.hudWindow material), sufficient
   height (56px, corner radius 28px), containing:
   - 5 vertical bar waveform animation on the left
     (44×32px), driven by real-time audio RMS levels
     (no hardcoded fake animations) — louder speech
     produces larger waveforms, quiet moments produce
     smaller ones. Bar weights are
     [0.5, 0.8, 1.0, 0.75, 0.55] creating a natural
     center-high, sides-low effect. Smooth envelope
     (attack 40%, release 15%), add ±4% random jitter
     per bar for organic feel. Waveforms should be
     large enough to be clearly visible.
   - Text label on the right (elastic width 160-560px)
     showing real-time transcription, capsule
     elastically widens as text grows
   - Entry spring animation (0.35s), text width smooth
     transition (0.25s), exit scale animation (0.22s)

4. Text injection uses clipboard + simulated Cmd+V
   paste. Before injection, detect the current input
   method: if it is a CJK input method, temporarily
   switch to an ASCII input source (ABC/US keyboard)
   before pasting, then restore the original input
   method after paste completes — this prevents CJK
   input methods from intercepting Cmd+V. Restore
   original clipboard contents after injection.

5. Integrate LLM to improve speech recognition
   accuracy, especially for mixed Chinese-English
   scenarios. Use an OpenAI-compatible API (configurable
   API Base URL, API Key, Model) to refine transcribed
   text. The LLM system prompt must be very conservative
   in corrections: only fix obvious speech recognition
   errors (e.g., Chinese homophone errors, English
   technical terms mistakenly converted to Chinese like
   配森→Python, 杰森→JSON). Never rewrite, polish, or
   remove any content that appears correct — if the
   input looks correct, return it as-is.

6. Provide an LLM Refinement submenu in the menu bar
   with an enable/disable toggle and a Settings entry.
   The Settings window contains three input fields: API
   Base URL, API Key, Model — the API Key field must
   support being fully cleared — plus Test and Save
   buttons. After releasing Fn, if LLM is enabled and
   configured, the floating window shows a Refining...
   status, waiting for the LLM response before
   injecting the final text.

7. The app runs in LSUIElement mode (menu bar icon
   only, no Dock icon). Build with Swift Package
   Manager, provide a Makefile (build/run/install/
   clean), build output is a signed .app bundle."
```
