#!/bin/zsh
# transcrire — local file transcription with WhisperKit (Apple Neural Engine).
# Usage: transcrire fichier.(m4a|mp3|mp4|wav|aiff|mov) [fr|en] [--diarize]
#
# Models live in ~/Models/whisperkit (see ~/Models/README.md). Nothing leaves
# the machine: the model downloads once, then everything runs offline.
emulate -L zsh
set -e

in="$1"
if [[ -z $in || ! -f $in ]]; then
  print -u2 "usage: transcrire <fichier audio/video> [fr|en] [--diarize]"
  exit 1
fi
lang="${2:-fr}"
[[ $lang == --* ]] && { lang=fr; set -- "$1" fr "${@:2}"; }

models="${WHISPERKIT_MODELS:-$HOME/Models/whisperkit}"
outdir="${in:a:h}"
base="${${in:t}:r}"
tmp="${TMPDIR:-/tmp}/${base}.wav"

extra=()
[[ " $* " == *" --diarize "* ]] && extra+=(--diarization)

# WhisperKit wants 16 kHz mono PCM; afconvert handles every container ffmpeg would.
afconvert -f WAVE -d LEI16@16000 -c 1 "$in" "$tmp"

whisperkit-cli transcribe \
  --model large-v3-v20240930_turbo_632MB \
  --language "$lang" \
  --download-model-path "$models" \
  --download-tokenizer-path "$models/tokenizers" \
  --skip-special-tokens \
  --audio-path "$tmp" \
  --report --report-path "$outdir" \
  "${extra[@]}"

rm -f "$tmp"
print "Transcription écrite dans : $outdir (fichiers ${base}*)"
