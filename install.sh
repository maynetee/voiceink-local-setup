#!/bin/zsh
# install.sh — set up the whole local dictation stack on an Apple silicon Mac.
#
#   ./install.sh             install, or bring an existing install back in line
#   ./install.sh --rebuild   also recompile VoiceInk even if a local build is installed
#   ./install.sh --dry-run   print what would be done, change nothing
#
# Idempotent: every step checks the current state first. VoiceInk is only compiled
# when /Applications holds no local build, because each compile changes the ad-hoc
# signature and makes macOS ask for the Microphone and Accessibility permissions again.
emulate -L zsh
set -euo pipefail

REPO=${0:A:h}
DRY=0; REBUILD=0
for a in "$@"; do
  case $a in
    --dry-run) DRY=1 ;;
    --rebuild) REBUILD=1 ;;
    *) print -u2 "usage: ./install.sh [--rebuild] [--dry-run]"; exit 2 ;;
  esac
done

step() { print "\n==> $*"; }
run()  { if (( DRY )); then print "    [dry-run] $*"; else "$@"; fi }
ok()   { print "    ok: $*"; }

MODELS=$HOME/Models
LABEL=local.voiceink-setup.launch
AGENT=$HOME/Library/LaunchAgents/$LABEL.plist
VI_SUPPORT="$HOME/Library/Application Support/com.prakashjoshipax.VoiceInk"
FLUID="$HOME/Library/Application Support/FluidAudio"

step "Prerequisites"
[[ $(uname -m) == arm64 ]] || { print -u2 "Apple silicon required"; exit 1; }
command -v brew >/dev/null || { print -u2 "Install Homebrew first: https://brew.sh"; exit 1; }
xcodebuild -version >/dev/null 2>&1 || {
  print -u2 "Install Xcode from the App Store, then run:"
  print -u2 "  sudo xcodebuild -license accept && sudo xcodebuild -runFirstLaunch"
  print -u2 "  xcodebuild -downloadComponent MetalToolchain"
  exit 1; }
ok "$(xcodebuild -version | head -1), Homebrew"

step "File transcription (whisperkit-cli)"
if command -v whisperkit-cli >/dev/null; then ok "already installed"
else run brew install whisperkit-cli; fi
run ln -sf "$REPO/transcrire.sh" "$(brew --prefix)/bin/transcrire"

step "Model storage (~/Models)"
run mkdir -p "$MODELS"/{huggingface,parakeet,whisperkit,torch,gguf} "$HOME/.local/bin"
run cp "$REPO/config/models-env.sh" "$MODELS/env.sh"
run cp "$REPO/config/models-audit.sh" "$MODELS/audit.sh"
run cp "$REPO/config/models-README.md" "$MODELS/README.md"
run chmod +x "$MODELS/audit.sh"
run ln -sf "$MODELS/audit.sh" "$HOME/.local/bin/models-audit"
if grep -q 'Models/env.sh' "$HOME/.zshenv" 2>/dev/null; then ok "~/.zshenv already loads env.sh"
elif (( DRY )); then print "    [dry-run] append env.sh loader to ~/.zshenv"
else print '\n# Local AI model storage — see ~/Models/README.md\n[ -f "$HOME/Models/env.sh" ] && . "$HOME/Models/env.sh"' >> "$HOME/.zshenv"; fi
if [[ ! -e $HOME/.cache/huggingface ]]; then
  run mkdir -p "$HOME/.cache"
  run ln -s "$MODELS/huggingface" "$HOME/.cache/huggingface"
fi
# VoiceInk has no setting for its model folder: point it at ~/Models before it downloads anything.
if [[ -L $FLUID ]]; then ok "FluidAudio link in place"
elif [[ -d $FLUID ]]; then print -u2 "    $FLUID is a real folder; move its content to $MODELS/parakeet and rerun"; exit 1
else run ln -s "$MODELS/parakeet" "$FLUID"; fi

step "VoiceInk"
local_build=0
if [[ -d /Applications/VoiceInk.app ]] &&
   codesign -dv /Applications/VoiceInk.app 2>&1 | grep -q 'TeamIdentifier=not set'; then
  local_build=1
fi
if (( local_build && ! REBUILD )); then
  ok "local build already installed (use --rebuild to recompile)"
else
  (( local_build )) || [[ ! -d /Applications/VoiceInk.app ]] ||
    print "    replacing the official (licensed) build with a local one"
  run "$REPO/build-voiceink.sh"
fi

step "VoiceInk settings and dictionary"
if (( DRY )); then
  print "    [dry-run] launch VoiceInk once, quit it, import config/voiceink/*.json"
else
  if [[ ! -f $VI_SUPPORT/dictionary.store ]]; then
    open -g -a /Applications/VoiceInk.app
    for _ in {1..60}; do [[ -f $VI_SUPPORT/dictionary.store ]] && break; sleep 1; done
  fi
  osascript -e 'quit app "VoiceInk"' 2>/dev/null || true
  for _ in {1..40}; do pgrep -qf "VoiceInk.app/Contents/MacOS/VoiceInk" || break; sleep 0.25; done
  python3 "$REPO/voiceink-settings.py" import
  killall -u "$USER" cfprefsd 2>/dev/null || true
fi

step "Start at login"
if (( DRY )); then print "    [dry-run] write $AGENT and load it"
else
  mkdir -p "$REPO/logs" "${AGENT:h}"
  sed -e "s|__LOG__|$REPO/logs/voiceink-launch.err|" "$REPO/config/voiceink-launch.plist.template" > "$AGENT"
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$AGENT"
  ok "$LABEL loaded"
fi

print "\nDone. Remaining manual steps:"
print "  1. System Settings > Privacy & Security > Microphone and Accessibility:"
print "     remove any old VoiceInk entry with '−', add /Applications/VoiceInk.app, enable it."
print "  2. If Parakeet V3 is not downloaded yet: open VoiceInk > AI Models > Parakeet V3 > Download."
print "  3. Optional: hide VoiceInk in System Settings > Menu Bar."
print "  The WhisperKit model downloads itself on the first 'transcrire' call."
