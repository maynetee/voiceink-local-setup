#!/bin/zsh
# models-audit — report AI model files and caches living outside ~/Models.
# Read-only: it never deletes anything, it tells you what drifted.
emulate -L zsh
setopt null_glob

ROOT="$HOME/Models"
red=$'\e[31m'; grn=$'\e[32m'; ylw=$'\e[33m'; dim=$'\e[2m'; rst=$'\e[0m'

print "${dim}== Modèles gérés (\$MODELS_ROOT = $ROOT) ==${rst}"
for d in "$ROOT"/*(/N); do
  n=$(find "$d" -type f ! -name '.DS_Store' 2>/dev/null | wc -l | tr -d ' ')
  printf "  %-14s %-7s %s fichiers\n" "${d:t}" "$(du -sh "$d" 2>/dev/null | cut -f1)" "$n"
done
printf "  %-14s %s\n" "TOTAL" "$(du -sh "$ROOT" 2>/dev/null | cut -f1)"

print "\n${dim}== Variables d'environnement ==${rst}"
for v in MODELS_ROOT HF_HOME HF_HUB_CACHE TORCH_HOME WHISPERKIT_MODELS GGUF_MODELS PARAKEET_MODELS; do
  val=${(P)v}
  if [[ -z $val ]]; then
    print "  ${red}MANQUANTE${rst}  $v  ${dim}(relance un shell ou: source ~/Models/env.sh)${rst}"
  elif [[ $val == $ROOT* ]]; then
    print "  ${grn}ok${rst}         $v=$val"
  else
    print "  ${ylw}HORS ROOT${rst}  $v=$val"
  fi
done

print "\n${dim}== Emplacements historiques (doivent être des liens vers \$MODELS_ROOT) ==${rst}"
for legacy in "$HOME/.cache/huggingface" "$HOME/.ollama/models" "$HOME/.cache/torch" \
              "$HOME/.cache/whisper" "$HOME/.cache/lm-studio" "$HOME/.lmstudio/models" \
              "$HOME/Library/Application Support/FluidAudio"; do
  if [[ -L $legacy ]]; then
    tgt=$(readlink "$legacy")
    [[ $tgt == $ROOT* ]] && print "  ${grn}lien ok${rst}   $legacy -> $tgt" \
                         || print "  ${ylw}lien hors root${rst} $legacy -> $tgt"
  elif [[ -e $legacy ]]; then
    print "  ${red}DÉRIVE${rst}     $legacy ($(du -sh "$legacy" 2>/dev/null | cut -f1)) — vrai dossier, pas un lien"
  fi
done

print "\n${dim}== Fichiers modèles égarés hors \$MODELS_ROOT (>50 Mo) ==${rst}"
found=0
while IFS= read -r f; do
  print "  ${ylw}$(du -h "$f" 2>/dev/null | cut -f1)${rst}\t$f"
  found=1
done < <(find "$HOME" -type f \( -name '*.gguf' -o -name '*.ggml' -o -name 'ggml-*.bin' \
           -o -name '*.safetensors' -o -name '*.mlmodelc' -o -name '*.pt' -o -name '*.pth' \
           -o -name '*.onnx' -o -name '*.mlpackage' \) -size +50M \
           -not -path "$ROOT/*" -not -path "$HOME/.Trash/*" \
           -not -path "$HOME/Library/Caches/*" -not -path "*/node_modules/*" 2>/dev/null)
(( found )) || print "  ${grn}aucun${rst}"

print "\n${dim}== Runtimes IA installés ==${rst}"
for c in ollama whisperkit-cli whisper-cli llama-cli lms mlx_lm.generate; do
  p=$(command -v $c 2>/dev/null) && printf "  %-18s %s\n" "$c" "$p"
done
print ""
