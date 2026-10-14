# ~/Models — single home for every local AI model on this Mac

Every model file lives here. Nothing downloads to `~/.cache`, `~/Documents`,
or an app-specific folder any more. One place to look, one place to back up,
one place to delete from when the disk fills up.

## Layout

| Folder | Holds | Pointed at by |
|---|---|---|
| `huggingface/` | Hugging Face hub cache: transformers, sentence-transformers, datasets, MLX | `HF_HOME`, `HF_HUB_CACHE`, `SENTENCE_TRANSFORMERS_HOME` |
| `whisperkit/` | WhisperKit CoreML models (file transcription) | `WHISPERKIT_MODELS`, used by the `transcrire` script |
| `torch/` | PyTorch / torch.hub checkpoints | `TORCH_HOME` |
| `gguf/` | GGUF and GGML files downloaded by hand (llama.cpp, whisper.cpp) | `GGUF_MODELS` |
| `parakeet/` | Parakeet v3 CoreML models used by VoiceInk for dictation | `PARAKEET_MODELS`, reached through a symlink (below) |

## How it stays organised

1. **`env.sh`** holds the variables. `~/.zshenv` sources it, so every shell,
   script and cron job inherits them — including non-interactive ones.
2. **Legacy paths are symlinks.** `~/.cache/huggingface` points here, so tools
   that hardcode the old path still land in the right place.
3. **GUI and launchd processes do not read `env.sh`.** A service that needs a
   variable must carry it in its own configuration (plist `EnvironmentVariables`).
   VoiceInk is the other case: it has no setting for its model path, so
   `~/Library/Application Support/FluidAudio` is a **symlink** to
   `~/Models/parakeet`. If a VoiceInk update ever replaces that symlink with a
   real folder, `models-audit` reports it and the fix is to move the contents
   back and recreate the link.
4. **`models-audit`** reports drift: missing variables, legacy folders that
   stopped being symlinks, and model files over 50 MB sitting outside this
   tree. It only reports — it never deletes.

## Adding a new runtime

Point it here before the first download, not after:

```bash
export SOME_TOOL_MODEL_DIR="$MODELS_ROOT/sometool"   # add to ~/Models/env.sh
```

Then run `models-audit` to confirm nothing landed elsewhere.

## Known exceptions

Some tools have no setting for their cache location; `models-audit` lists them
as strays. The usual one is ChromaDB's default embedding model in
`~/.cache/chroma/onnx_models/`. Leave such files where the tool expects them.

## Note on sentence-transformers

`SENTENCE_TRANSFORMERS_HOME` points at `HF_HOME`, so sentence-transformers
stores its models at the root of `huggingface/`, not under `hub/`. A model loaded
through both sentence-transformers and transformers can therefore exist twice;
check which copy is read before deleting one.
