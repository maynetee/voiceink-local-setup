#!/bin/zsh
# build-voiceink — compile VoiceInk from ./VoiceInk and install it in /Applications,
# keeping every build artefact inside this repo.
#
# Upstream hardcodes two locations outside the repo:
#   - the Xcode project expects whisper.xcframework under $HOME/VoiceInk-Dependencies;
#   - `make local` copies the finished app to ~/Downloads.
# Rather than patching upstream (to be redone on every update), this script builds
# the dependency in ./build/deps, exposes it through a temporary symlink for the
# duration of the build only, and installs the app straight from the build folder.
#
# Usage: ./build-voiceink.sh [git-ref]    (default: latest release tag)
emulate -L zsh
set -euo pipefail

REPO=${0:A:h}
SRC=$REPO/VoiceInk
DEPS=$REPO/build/deps
LINK=$HOME/VoiceInk-Dependencies
CREATED_LINK=0

cleanup() {
  (( CREATED_LINK )) && rm -f "$LINK"
  rm -rf "$HOME/Downloads/VoiceInk.app" "$SRC/.local-build"
}
trap cleanup EXIT

[[ -d $SRC/.git ]] || git clone https://github.com/Beingpax/VoiceInk.git "$SRC"
cd "$SRC"
git fetch --tags --quiet
ref=${1:-$(git tag --sort=-v:refname | head -1)}
git checkout --quiet "$ref"
print "VoiceInk $ref"

if [[ -e $LINK && ! -L $LINK ]]; then
  print -u2 "$LINK exists as a real folder; remove it first (it is only a build cache)."
  exit 1
fi
mkdir -p "$DEPS"
ln -sfn "$DEPS" "$LINK"
CREATED_LINK=1

make local DEPS_DIR="$DEPS" LOCAL_CODESIGN_IDENTITY=-

app=$SRC/.local-build/Build/Products/Release/VoiceInk.app
[[ -d $app ]] || { print -u2 "build produced no app"; exit 1; }

osascript -e 'quit app "VoiceInk"' 2>/dev/null || true
for _ in {1..40}; do pgrep -qf "MacOS/VoiceInk" || break; sleep 0.25; done
rm -rf /Applications/VoiceInk.app
ditto "$app" /Applications/VoiceInk.app
xattr -cr /Applications/VoiceInk.app

# The in-app updater would replace this build with the licensed official one.
defaults write com.prakashjoshipax.VoiceInk VoiceInkChecksForUpdatesOnLaunch -bool false
defaults write com.prakashjoshipax.VoiceInk SUEnableAutomaticChecks -bool false
defaults write com.prakashjoshipax.VoiceInk SUAutomaticallyUpdate -bool false
open -g -a /Applications/VoiceInk.app

print "Installed VoiceInk $ref. macOS will ask again for Microphone and Accessibility:"
print "remove VoiceInk with '−' and re-add it in System Settings > Privacy & Security."
