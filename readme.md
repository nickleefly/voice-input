# VoiceInput

A macOS menu-bar voice input app. **Hold Fn to record, release to
inject** the transcribed text into whatever field has focus —
Slack, browser, IDE, anything.

- 🎙 Streaming transcription via Apple's Speech Recognition framework
- 🌐 Nine languages out of the box (Simplified/Traditional Chinese,
  English, Japanese, Korean, Spanish, French, German, Russian)
- 🤖 Optional LLM refinement (any OpenAI-compatible API) to fix
  homophone and mixed-language recognition errors
- 🎨 Frameless capsule HUD with live waveform driven by mic RMS
- 🪶 Menu-bar only — no Dock icon, no window clutter
- 🧠 CJK input-method aware paste (won't be eaten by Pinyin/Kana IMEs)

## Install

Requires **macOS 14+**. Open Terminal (⌘+Space → "Terminal") and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/nickleefly/voice-input/main/install.sh | bash
```

Then:

1. When System Settings opens, toggle **VoiceInput** ON under
   **Privacy & Security → Accessibility**.
2. Quit VoiceInput from the menu bar (icon → Quit).
3. Relaunch from `/Applications/VoiceInput.app`.
4. Hold **Fn** to record, release to inject.

> The installer downloads the latest release, strips macOS quarantine,
> re-signs the app locally so Accessibility permissions stick across
> launches, and clears any stale TCC grants left by earlier installs.

## Usage

| Action | How |
|---|---|
| Record | Hold **Fn** |
| Stop & inject | Release **Fn** |
| Change language | Menu bar icon → Language |
| Toggle LLM refinement | Menu bar icon → LLM Refinement |
| Configure LLM API | Menu bar icon → LLM Refinement → Settings… |
| Quit | Menu bar icon → Quit |

### LLM refinement (optional)

If you enable LLM refinement, VoiceInput sends the raw transcript to
an OpenAI-compatible endpoint to correct obvious recognition errors
(e.g. `配森` → `Python`, `杰森` → `JSON`). The system prompt is
conservative — it won't rewrite or polish content that already looks
correct.

Configure in the Settings window:

- **API Base URL** — e.g. `https://api.openai.com/v1`, or any
  compatible gateway (DeepSeek, Together, local Ollama, etc.)
- **API Key**
- **Model** — e.g. `gpt-4o-mini`

After release, the HUD briefly shows "Refining…" before pasting the
refined text.

## Troubleshooting

**Pressing Fn does nothing.**
Open `~/.voiceinput-debug.log`:

- `ERROR: CGEvent.tapCreate returned nil` → Accessibility permission
  isn't actually applied to the running binary. Re-run the installer
  — it re-signs locally and resets stale TCC entries, which is the
  fix in ~99% of cases.
- `SUCCESS: Event tap created` but no `Fn DOWN` lines → the key
  you're pressing isn't being delivered as Fn. On newer Macs, check
  **System Settings → Keyboard → Press 🌐 key to** is set to
  *Do Nothing* (or *Change Input Source*). Karabiner-Elements and
  similar remappers will also intercept Fn before this app sees it.

**It worked, then suddenly stopped after a macOS update.**
macOS sometimes invalidates ad-hoc-signed app entries on update.
Re-run the installer.

**No microphone input / Speech Recognition fails.**
Check **System Settings → Privacy & Security → Microphone** and
**Speech Recognition** — both must be ON for VoiceInput.

**Paste doesn't appear in Chinese/Japanese/Korean apps.**
VoiceInput temporarily switches to ABC keyboard before pasting, then
restores your IME. If you've remapped Cmd+V or the IME doesn't
expose ABC as a fallback, paste may fail — let me know which app.

## Build from source

Requires **Swift 5.9+** and **macOS 14+**.

```bash
make build      # Build .app bundle
make run        # Build and launch
make install    # Install to /Applications
make clean      # Clean build artifacts
```

After install, grant Accessibility permission in
**System Settings → Privacy & Security → Accessibility**.

## Architecture

| File | Role |
|---|---|
| `FnKeyMonitor.swift` | Global CGEvent tap; detects Fn via both `flagsChanged` (`maskSecondaryFn`) and `keyDown/Up` (keyCode 63), with debounced release |
| `SpeechRecognitionManager.swift` | Streaming Apple Speech Recognition + audio RMS metering for the waveform |
| `FloatingWindowController.swift` | Frameless capsule HUD (`NSPanel` + `NSVisualEffectView .hudWindow`) |
| `WaveformView.swift` | 5-bar live waveform driven by mic RMS, with attack/release envelope and jitter |
| `TextInjector.swift` | Clipboard + simulated ⌘V; auto-switches CJK IMEs to ABC before pasting |
| `LLMRefiner.swift` | OpenAI-compatible refinement client with conservative correction prompt |
| `StatusBarController.swift` | Menu bar UI, language selection, LLM toggle, glue |
| `SettingsWindowController.swift` | API Base URL / Key / Model configuration |

App runs in `LSUIElement` mode (menu-bar only, no Dock icon).

## Origin

This app was bootstrapped with a single Claude Code prompt — see
[`PROMPT.md`](PROMPT.md) for the full specification.

## License

MIT
