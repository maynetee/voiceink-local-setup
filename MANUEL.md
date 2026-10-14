# Dictée vocale locale — manuel

Mac Apple silicon (développé sur un MacBook Air M4, 16 Go). Tout tourne sur la
machine : aucun audio ni aucun texte ne sort du Mac, aucune clé API. Le réseau ne
sert qu'à télécharger les outils et les modèles.

Dans ce manuel, `<dépôt>` désigne le dossier où ce dépôt est cloné.
Installation : voir le [README](README.md).

---

## Aide-mémoire

| Je veux… | Geste ou commande |
|---|---|
| Dicter | **Ctrl-Tab** ou **Maj-§** |
| Ouvrir les réglages de VoiceInk | lancer VoiceInk (Spotlight ou `open -a VoiceInk`) |
| Transcrire un fichier audio | `transcrire reunion.m4a fr` |
| … avec séparation des locuteurs | `transcrire reunion.m4a fr --diarize` |
| Vérifier le rangement des modèles | `models-audit` |

À ne pas faire :

1. **Utiliser `--model large-v3_turbo` sans le suffixe `632MB`** : 3 Go non
   quantifiés, le système tue le process faute de mémoire.
2. **Accepter la mise à jour proposée par VoiceInk** : elle remplace la
   compilation locale par la version officielle sous licence (section 6).
3. **Dicter « point d'interrogation »** : c'est écrit en toutes lettres. La
   ponctuation vient de l'intonation.

---

## 1. Architecture

```
  Micro ──► Parakeet v3 ──► règles de remplacement ──► curseur
            Neural Engine    noms propres, jargon
            ~0,2 s           instantané
```

| Composant | Rôle | Emplacement |
|---|---|---|
| VoiceInk 2.22 | capture, raccourcis, insertion au curseur | `/Applications/VoiceInk.app`, compilé depuis les sources (`<dépôt>/VoiceInk`) |
| Parakeet v3 | transcription, ponctuation, retrait des hésitations | `~/Models/parakeet` (476 Mo) |
| WhisperKit + modèle turbo 632 Mo | transcription de fichiers | `~/Models/whisperkit` |

Un seul service, lancé à l'ouverture de session : le LaunchAgent
`local.voiceink-setup.launch`, qui ouvre VoiceInk puis se termine.

```bash
launchctl print gui/$(id -u)/local.voiceink-setup.launch >/dev/null && echo chargé || echo ABSENT
```

### Mémoire

VoiceInk occupe **~145 Mo** au repos, Parakeet compris. Mesurer l'empreinte
réelle, pas le RSS (qui compte les bibliothèques partagées) :

```bash
vmmap -summary $(pgrep -f MacOS/VoiceInk) | grep "Physical footprint:"
```

---

## 2. Dicter

### Les raccourcis

**Ctrl-Tab** (raccourci principal) ou **Maj-§** (raccourci secondaire) : les
deux font la même chose, avec le mode `Dictation` — Parakeet v3, langue `auto`,
collage au curseur. La langue bascule seule entre français et anglais, y compris
au milieu d'une phrase.

Le panneau d'enregistrement s'affiche **en haut de l'écran**, près de l'encoche
(`RecorderType = notch`), là où le Dock ne peut pas le recouvrir.

### Ce que fait Parakeet

Parakeet v3 ponctue, met les majuscules et les accents, et **retire lui-même
les hésitations** (« euh », « hum »). Un nettoyage par LLM local (Ollama) a été essayé puis
retiré : sur 104 dictées, il n'a modifié aucun mot dans la moitié des cas,
4,3 % des mots au total, pour 8,8 s d'attente à chaque fois.

Pas de commande vocale de ponctuation : « point d'interrogation » s'écrit en
toutes lettres. Marquer les pauses et monter en fin de question suffit.

### Le dictionnaire

`Dictionary` dans VoiceInk. Deux mécanismes :

| Mécanisme | Usage |
|---|---|
| **Vocabulaire** | apprend l'orthographe d'un terme à Parakeet |
| **Remplacements** | règle « entendu → écrit », appliquée à chaque dictée, instantanée |

Exemples typiques — un nom propre que Parakeet découpe en mots courants :

| Entendu | Écrit |
|---|---|
| `git hub`, `git hubs` | GitHub |
| `cloud code` | Claude Code |

Ton dictionnaire est personnel : il est exporté dans `<dépôt>/private/dictionary.json`
(ignoré par git) par `voiceink-settings.py export`. Sans lui, l'installation
importe `config/voiceink/dictionary.example.json`.

Les variantes se séparent par des virgules ; la correspondance ignore la casse et
respecte les limites de mot. Ajouter une règle au premier ratage **répété**, pas
par anticipation : une règle inutile finit par se déclencher sur autre chose.

Retrouver les erreurs récurrentes dans l'historique :

```bash
sqlite3 ~/Library/Application\ Support/com.prakashjoshipax.VoiceInk/default.store \
  "select ZTEXT from ZTRANSCRIPTION order by ZTIMESTAMP desc limit 200;" | grep -io "git hub"
```

### VoiceInk est invisible

Pas d'icône dans le Dock (`IsMenuBarOnly`), ni dans la barre de menus (décochée
dans Réglages Système → Barre des menus). L'app tourne quand même.

- **Ouvrir ses réglages** : la lancer comme n'importe quelle app (Spotlight,
  Launchpad, `open -a VoiceInk`) ; sa fenêtre s'affiche. La fermer ne l'arrête pas.
- **L'arrêter** : `osascript -e 'quit app "VoiceInk"'`. Elle se rouvre à la
  prochaine session.

### Enregistrements audio

VoiceInk conserve l'audio de chaque dictée. La purge automatique est activée :
les fichiers de plus de **7 jours** sont supprimés (`IsAudioCleanupEnabled`,
`AudioRetentionPeriod`). Le texte de l'historique est conservé.

---

## 3. Transcrire un fichier

```bash
transcrire reunion.m4a fr            # français
transcrire interview.mp3 en          # anglais
transcrire reunion.mov fr --diarize  # avec séparation des locuteurs
```

Tout format lisible par `afconvert` : m4a, mp3, mp4, mov, wav, aiff, caf.
Le script convertit en WAV 16 kHz mono, transcrit sur le Neural Engine, puis
supprime le fichier temporaire.

Sortie, dans le dossier du fichier source :

| Fichier | Contenu |
|---|---|
| `<nom>.json` | texte, langue détectée, segments horodatés |
| `<nom>.srt` | sous-titres |

Pas de `.txt` ; pour en obtenir un :

```bash
python3 -c "import json;print(json.load(open('reunion.json'))['text'])" > reunion.txt
```

Vitesse : ~12 s de chargement, puis ~3 s par minute d'audio. Une heure d'audio
≈ 3 min 15.

Modèle : `openai_whisper-large-v3-v20240930_turbo_632MB` (626 Mo). Script :
`<dépôt>/transcrire.sh`, lié en `/opt/homebrew/bin/transcrire`.

---

## 4. Réunions

Pas d'application dédiée. En deux temps :

1. **Enregistrer** micro et son système : `Maj-Cmd-5` → Options → choisir le
   micro. Le `.mov` contient les deux pistes.
2. **Transcrire** : `transcrire ~/Desktop/reunion.mov fr --diarize`.

Si le son système manque à l'enregistrement : BlackHole (périphérique audio
virtuel gratuit) combiné à un périphérique agrégé dans Configuration audio et
MIDI. Non installé.

---

## 5. Rangement des modèles : `~/Models`

Tous les modèles d'IA de la machine sont sous `~/Models`, un sous-dossier par
outil. `~/Models/env.sh`, chargé par `~/.zshenv`, exporte les variables qui y
pointent (`HF_HOME`, `TORCH_HOME`, `WHISPERKIT_MODELS`…). Détails :
`~/Models/README.md`.

| Dossier | Contenu |
|---|---|
| `huggingface/` | modèles Hugging Face d'autres outils (vide pour la dictée) |
| `parakeet/` | Parakeet v3, atteint par VoiceInk via le lien `~/Library/Application Support/FluidAudio` |
| `whisperkit/` | modèle de transcription de fichiers |
| `torch/`, `gguf/` | vides, prêts pour de futurs téléchargements |

sentence-transformers écrit à la racine de `huggingface/` (et non dans `hub/`)
parce que `SENTENCE_TRANSFORMERS_HOME` pointe sur `HF_HOME`.

`models-audit` signale toute dérive : variable absente, lien historique
redevenu un vrai dossier, modèle de plus de 50 Mo hors de `~/Models`. Il ne
supprime rien. Certains outils n'ont aucun réglage d'emplacement (par exemple
ChromaDB et `~/.cache/chroma/`) : ils apparaissent comme égarés, c'est normal.

---

## 6. Maintenance

### Mettre à jour VoiceInk

**Ne jamais accepter la mise à jour proposée par l'app.** Elle installe la
version officielle, signée et soumise à licence : essai gratuit, puis
fonctions bloquées, et macOS retire les permissions — les raccourcis cessent de
marcher. Les vérifications sont coupées
(`VoiceInkChecksForUpdatesOnLaunch = false`) ; si l'app en propose une quand
même, refuser.

Pour mettre à jour, recompiler la dernière version publiée :

```bash
<dépôt>/build-voiceink.sh
```

Le script prend le dernier tag publié (ou celui passé en argument), compile,
installe dans `/Applications`, recoupe les mises à jour intégrées et relance
l'app. **Tout reste dans le dépôt** : les dépendances de compilation vont dans
`build/deps` (~1,5 Go, ignoré par git, supprimable), rien n'est laissé dans le
home ni dans `~/Downloads`. Le projet Xcode de VoiceInk exige ces dépendances
sous `~/VoiceInk-Dependencies` : le script y pose un lien vers `build/deps` le
temps de la compilation, puis le retire, y compris en cas d'échec.

Ne pas lancer `make local` directement : il recrée `~/VoiceInk-Dependencies` et
dépose l'app dans `~/Downloads`.

La signature est ad-hoc (pas de certificat Apple Developer) : après chaque
rebuild, macOS redemande les permissions **Microphone** et **Accessibilité**
(Réglages Système → Confidentialité et sécurité). La compilation locale
(`LOCAL_BUILD`) débloque toutes les fonctions, aucune licence n'est requise.

Si le build échoue après une mise à jour d'Xcode :

```bash
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
xcodebuild -downloadComponent MetalToolchain
```

### Mettre à jour la transcription de fichiers

```bash
brew upgrade whisperkit-cli
```

### Modifier une préférence de VoiceInk en ligne de commande

Toujours **VoiceInk quitté**, sinon il écrase la modification en se fermant. Les
noms de clés sont sensibles à la casse (`RecorderType`, `IsMenuBarOnly`) :
vérifier le nom exact dans le code source avant d'écrire.

Les fichiers en service hors du dépôt viennent de [`config/`](config/) :
`install.sh` les y recopie. Après un changement de réglage ou de dictionnaire
dans VoiceInk : `<dépôt>/voiceink-settings.py export`.

---

## 7. Diagnostic

### La dictée est lente ou mal transcrite

```bash
sqlite3 -header -column ~/Library/Application\ Support/com.prakashjoshipax.VoiceInk/default.store "
select datetime(ZTIMESTAMP+978307200,'unixepoch','localtime') quand,
       round(ZDURATION,1) audio_s, round(ZTRANSCRIPTIONDURATION,2) parakeet_s,
       substr(ZTEXT,1,60) texte
from ZTRANSCRIPTION order by ZTIMESTAMP desc limit 10;"
```

`parakeet_s` vaut normalement 0,1 à 0,3 s. Au-delà d'une seconde, la machine est
saturée :

```bash
memory_pressure | tail -1       # mémoire libre, normal > 25 %
sysctl vm.swapusage             # au-delà de 3 Go : redémarrer
ps -Ao rss,comm -r | head -8 | awk 'NR>1{printf "%6.0f MB %s\n",$1/1024,$2}'
```

### Rien ne s'écrit / l'app parle d'essai gratuit

- L'app a-t-elle été remplacée par la version officielle ?
  `codesign -dv /Applications/VoiceInk.app 2>&1 | grep TeamIdentifier` doit
  afficher `not set`. Sinon : recompiler (section 6) et redonner les permissions.
- VoiceInk tourne-t-il ? `pgrep -fl MacOS/VoiceInk` — sinon `open -a VoiceInk`.
- Après une recompilation : permissions Microphone et Accessibilité à redonner.

---

## 8. Désinstallation

```bash
# Application
osascript -e 'quit app "VoiceInk"'
rm -rf /Applications/VoiceInk.app
rm -rf ~/Library/Application\ Support/com.prakashjoshipax.VoiceInk
rm -rf ~/Library/Caches/com.prakashjoshipax.VoiceInk
rm -rf ~/Library/HTTPStorages/com.prakashjoshipax.VoiceInk
rm -f  ~/Library/Preferences/com.prakashjoshipax.VoiceInk.plist

# Lancement automatique
launchctl bootout gui/$(id -u)/local.voiceink-setup.launch
rm -f ~/Library/LaunchAgents/local.voiceink-setup.launch.plist

# Transcription de fichiers
brew uninstall whisperkit-cli
rm -f /opt/homebrew/bin/transcrire

# Modèles de la dictée
rm -rf ~/Models/whisperkit ~/Models/parakeet
rm -f  ~/Library/Application\ Support/FluidAudio

# Sources et ce dépôt (en dernier)
rm -rf <dépôt>
```

Pour défaire aussi
l'organisation `~/Models`, retirer de `~/.zshenv` la ligne qui charge
`~/Models/env.sh` et supprimer `~/.local/bin/models-audit`.
