#!/usr/bin/env python3
"""Export or import the VoiceInk settings and dictionary kept in this repo.

    voiceink-settings.py export   # live app -> config/voiceink/settings.json + private/dictionary.json
    voiceink-settings.py import   # the same files -> live app

The dictionary is personal (names, jargon) and lives in private/, which git
ignores. When private/dictionary.json is absent, import falls back to
config/voiceink/dictionary.example.json.

Quit VoiceInk first: it rewrites its preferences and its Core Data store on
exit and would undo an import. The import merges: dictionary entries already
present (same word, same original text) are kept as they are, so running it
twice changes nothing.

Environment overrides, used for testing against a scratch copy:
    VOICEINK_PREFS_DOMAIN   defaults domain or absolute .plist path
    VOICEINK_DICT_STORE     path to dictionary.store
"""
import json
import os
import plistlib
import sqlite3
import subprocess
import sys
import uuid
from pathlib import Path

REPO = Path(__file__).resolve().parent
CONFIG = REPO / "config" / "voiceink"
SETTINGS_JSON = CONFIG / "settings.json"
DICTIONARY_JSON = REPO / "private" / "dictionary.json"
DICTIONARY_EXAMPLE = CONFIG / "dictionary.example.json"

DOMAIN = os.environ.get("VOICEINK_PREFS_DOMAIN", "com.prakashjoshipax.VoiceInk")
STORE = Path(os.environ.get(
    "VOICEINK_DICT_STORE",
    Path.home() / "Library/Application Support/com.prakashjoshipax.VoiceInk/dictionary.store"))

# Keys whose value is JSON encoded as Data by the app: stored decoded here so
# the repo copy stays readable and diffable.
JSON_DATA_KEYS = ["modeConfigurationsV2", "Shortcut_primaryRecording", "Shortcut_secondaryRecording"]
PLAIN_KEYS = ["IsMenuBarOnly", "RecorderType", "IsAudioCleanupEnabled", "AudioRetentionPeriod"]
# Updates must stay off: the in-app updater installs the licensed official build.
FORCED = {"VoiceInkChecksForUpdatesOnLaunch": False,
          "SUEnableAutomaticChecks": False,
          "SUAutomaticallyUpdate": False}


def read_prefs():
    r = subprocess.run(["defaults", "export", DOMAIN, "-"], capture_output=True)
    return plistlib.loads(r.stdout) if r.returncode == 0 and r.stdout else {}


def write_prefs(prefs):
    subprocess.run(["defaults", "import", DOMAIN, "-"],
                   input=plistlib.dumps(prefs, fmt=plistlib.FMT_BINARY), check=True)


def export_settings():
    prefs = read_prefs()
    out = {}
    for k in JSON_DATA_KEYS:
        if k in prefs:
            out[k] = json.loads(prefs[k])
    for k in PLAIN_KEYS:
        if k in prefs:
            out[k] = prefs[k]
    out.update(FORCED)
    return out


def import_settings(settings):
    prefs = read_prefs()
    for k, v in settings.items():
        if k in JSON_DATA_KEYS:
            prefs[k] = json.dumps(v, separators=(",", ":"), ensure_ascii=False).encode()
        else:
            prefs[k] = v
    prefs.update(FORCED)
    write_prefs(prefs)


def export_dictionary():
    db = sqlite3.connect(f"file:{STORE}?mode=ro", uri=True)
    words = [{"word": w, "dateAdded": d} for w, d in
             db.execute("select ZWORD, ZDATEADDED from ZVOCABULARYWORD order by Z_PK")]
    repl = [{"original": o, "replacement": r, "enabled": bool(e), "dateAdded": d,
             "id": str(uuid.UUID(bytes=i)) if i else None}
            for o, r, e, d, i in db.execute(
                "select ZORIGINALTEXT, ZREPLACEMENTTEXT, ZISENABLED, ZDATEADDED, ZID "
                "from ZWORDREPLACEMENT order by Z_PK")]
    return {"vocabulary": words, "replacements": repl}


def insert(db, entity, table, columns, values):
    """Insert one Core Data row, keeping Z_PRIMARYKEY.Z_MAX in step."""
    ent, zmax = db.execute("select Z_ENT, Z_MAX from Z_PRIMARYKEY where Z_NAME=?", (entity,)).fetchone()
    pk = max(zmax, db.execute(f"select coalesce(max(Z_PK),0) from {table}").fetchone()[0]) + 1
    cols = ", ".join(["Z_PK", "Z_ENT", "Z_OPT", *columns])
    marks = ", ".join("?" * (3 + len(values)))
    db.execute(f"insert into {table} ({cols}) values ({marks})", (pk, ent, 1, *values))
    db.execute("update Z_PRIMARYKEY set Z_MAX=? where Z_NAME=?", (pk, entity))


def import_dictionary(data):
    if not STORE.exists():
        sys.exit(f"{STORE} missing: launch VoiceInk once so it creates its store")
    db = sqlite3.connect(STORE)
    names = {n for (n,) in db.execute("select Z_NAME from Z_PRIMARYKEY")}
    if not {"VocabularyWord", "WordReplacement"} <= names:
        sys.exit(f"{STORE} has no dictionary entities: launch VoiceInk once, then retry")
    have_words = {w for (w,) in db.execute("select ZWORD from ZVOCABULARYWORD")}
    have_repl = {o for (o,) in db.execute("select ZORIGINALTEXT from ZWORDREPLACEMENT")}
    added = 0
    with db:
        for w in data["vocabulary"]:
            if w["word"] not in have_words:
                insert(db, "VocabularyWord", "ZVOCABULARYWORD",
                       ["ZDATEADDED", "ZWORD"], [w["dateAdded"], w["word"]])
                added += 1
        for r in data["replacements"]:
            if r["original"] not in have_repl:
                rid = uuid.UUID(r["id"]) if r.get("id") else uuid.uuid4()
                insert(db, "WordReplacement", "ZWORDREPLACEMENT",
                       ["ZISENABLED", "ZDATEADDED", "ZORIGINALTEXT", "ZREPLACEMENTTEXT", "ZID"],
                       [int(r["enabled"]), r["dateAdded"], r["original"], r["replacement"], rid.bytes])
                added += 1
    db.close()
    return added


def app_running():
    return subprocess.run(["pgrep", "-qf", "VoiceInk.app/Contents/MacOS/VoiceInk"]).returncode == 0


def dump(path, obj):
    path.write_text(json.dumps(obj, indent=2, ensure_ascii=False, sort_keys=True) + "\n")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "export":
        CONFIG.mkdir(parents=True, exist_ok=True)
        DICTIONARY_JSON.parent.mkdir(parents=True, exist_ok=True)
        dump(SETTINGS_JSON, export_settings())
        dump(DICTIONARY_JSON, export_dictionary())
        print(f"exported to {CONFIG}")
    elif cmd == "import":
        if app_running() and "VOICEINK_DICT_STORE" not in os.environ:
            sys.exit("quit VoiceInk first: osascript -e 'quit app \"VoiceInk\"'")
        import_settings(json.loads(SETTINGS_JSON.read_text()))
        source = DICTIONARY_JSON if DICTIONARY_JSON.exists() else DICTIONARY_EXAMPLE
        n = import_dictionary(json.loads(source.read_text()))
        print(f"settings imported, {n} dictionary entries added from {source.relative_to(REPO)}")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
