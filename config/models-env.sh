# ~/Models/env.sh — single source of truth for local AI model storage.
# Sourced from ~/.zshenv so it applies to interactive shells, scripts and cron.
# GUI apps and launchd services do not read this file: duplicate a variable into
# the service's own configuration when one needs it.

export MODELS_ROOT="$HOME/Models"

# Hugging Face: transformers, sentence-transformers, datasets, diffusers, MLX.
export HF_HOME="$MODELS_ROOT/huggingface"
export HF_HUB_CACHE="$HF_HOME/hub"
export SENTENCE_TRANSFORMERS_HOME="$HF_HOME"

# PyTorch checkpoints (torch.hub, torchvision weights).
export TORCH_HOME="$MODELS_ROOT/torch"


# WhisperKit CoreML models (consumed by the transcrire script of this setup).
export WHISPERKIT_MODELS="$MODELS_ROOT/whisperkit"

# Raw GGUF / GGML files downloaded by hand (llama.cpp, whisper.cpp).
export GGUF_MODELS="$MODELS_ROOT/gguf"

# Parakeet v3 CoreML models used by VoiceInk (via FluidAudio). VoiceInk has no
# setting for this path, so ~/Library/Application Support/FluidAudio is a symlink
# to the directory below. Recreate the symlink if the app ever replaces it.
export PARAKEET_MODELS="$MODELS_ROOT/parakeet"
