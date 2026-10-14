# voiceink-local-setup

**Fully local voice dictation on an Apple silicon Mac, built on
[VoiceInk](https://github.com/Beingpax/VoiceInk).** This repository is a
personal setup — install scripts, configuration and documentation. It contains
no VoiceInk code: the install script downloads VoiceInk's source from its
official repository and compiles it locally, the way its own
[BUILDING.md](https://github.com/Beingpax/VoiceInk/blob/main/BUILDING.md)
describes. Documentation is in French.

> VoiceInk is developed by [Prakash Joshi Pax](https://github.com/Beingpax). If
> it is useful to you, consider supporting the project by
> [buying a license](https://tryvoiceink.com).

---

Dictée vocale 100 % locale : rien ne sort de la machine, aucune clé API, aucun
appel réseau en usage normal.

```
Micro → Parakeet v3 (Neural Engine) → règles de remplacement → curseur
```

Parakeet v3 ponctue, met les majuscules et retire les hésitations seul ; les
noms propres qu'il écorche sont corrigés par des règles de remplacement.
Empreinte au repos : ~145 Mo.

## Utilisation

| Je veux… | Geste |
|---|---|
| Dicter | **Ctrl-Tab** ou **Maj-§** |
| Ouvrir les réglages de VoiceInk | lancer VoiceInk (Spotlight) |
| Transcrire un fichier audio | `transcrire fichier.m4a fr` |

Tout le reste — dictionnaire, transcription de fichiers et de réunions,
maintenance, diagnostic, désinstallation — est dans le [manuel](MANUEL.md).

## Installation

Prérequis : Mac Apple silicon, [Homebrew](https://brew.sh), Xcode (App Store),
puis :

```bash
sudo xcodebuild -license accept
```

```bash
sudo xcodebuild -runFirstLaunch
```

```bash
xcodebuild -downloadComponent MetalToolchain
```

Ensuite, depuis le dossier où ce dépôt est cloné :

```bash
./install.sh
```

Le script installe `whisperkit-cli`, crée `~/Models`, compile VoiceInk depuis
ses sources, importe les réglages (`config/voiceink/`) et le dictionnaire, et
active le lancement à l'ouverture de session. Il est rejouable sans risque ;
`./install.sh --dry-run` montre ce qu'il ferait. Restent à faire à la main :

1. Réglages Système → Confidentialité et sécurité → **Microphone** et
   **Accessibilité** : ajouter `/Applications/VoiceInk.app`.
2. Dans VoiceInk → AI Models : télécharger **Parakeet V3** s'il ne l'est pas.

Tout ce que la compilation produit reste dans le dépôt (`VoiceInk/`, `build/`),
rien n'est laissé dans le home.

**Ne jamais accepter la mise à jour proposée par VoiceInk** : elle remplace la
compilation locale par la version officielle sous licence. Pour mettre à jour :
`./build-voiceink.sh`.

## Contenu

| Fichier | Rôle |
|---|---|
| [MANUEL.md](MANUEL.md) | mode d'emploi complet |
| [install.sh](install.sh) | installation complète, rejouable |
| [build-voiceink.sh](build-voiceink.sh) | compile et installe VoiceInk sans rien laisser hors du dépôt |
| [voiceink-settings.py](voiceink-settings.py) | export / import des réglages et du dictionnaire de VoiceInk |
| [transcrire.sh](transcrire.sh) | transcription de fichiers audio avec WhisperKit |
| [config/](config/) | réglages VoiceInk, dictionnaire d'exemple, modèle du LaunchAgent, rangement `~/Models` |

Ignorés par git : `VoiceInk/` (sources téléchargées), `build/`, `logs/`, et
`private/` — ton dictionnaire personnel et tes notes.

## Credits

This setup only glues together the work of others:

| Project | Role here | License |
|---|---|---|
| [VoiceInk](https://github.com/Beingpax/VoiceInk) by Prakash Joshi Pax | dictation app, compiled from source | GPL-3.0 |
| [FluidAudio](https://github.com/FluidInference/FluidAudio) by FluidInference | on-device speech engine used by VoiceInk | Apache-2.0 |
| [Parakeet TDT 0.6B v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) by NVIDIA, [CoreML conversion](https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml) by FluidInference | speech recognition model | CC-BY-4.0 |
| [WhisperKit](https://github.com/argmaxinc/argmax-oss-swift) by Argmax | file transcription (`whisperkit-cli`) | MIT |
| [whisper.cpp](https://github.com/ggml-org/whisper.cpp) by ggml-org | build dependency of VoiceInk | MIT |

None of these projects is distributed in this repository; each is downloaded
from its official source at install time and remains under its own license.

## License

The scripts and documentation in this repository are released under the
[MIT License](LICENSE). This license does not cover VoiceInk or the other
projects listed above.
