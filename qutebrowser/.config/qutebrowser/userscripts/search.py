#!/usr/bin/env python3
"""
search.py — Web search / URL launcher via rofi with "press-to-fetch" completions.

Because standard Rofi does not support making live API calls to the web on every
single keystroke, this script uses a customized workaround to get you web
suggestions without leaving the search bar.

How to use it:
  1. Type your query: Rofi will instantly filter your local history. To prevent
     fuzzy-matching from getting in the way (e.g., highlighting  "steam client"
     when you just want "steam"), your exact typed text is ALWAYS forced to
     the very top of the list.
  2. Press [Enter]: Immediately searches the exact text you typed (or opens
     whichever history/suggestion item you have highlighted).
  3. Press [Shift+Enter]*: Fetches live web suggestions from the internet
     (DuckDuckGo/Brave) and instantly refreshes the Rofi menu to show them.

     *Note: Shift+Enter is Rofi's default for submitting custom text (retv=2).
     Depending on your config, this might be Ctrl+Enter instead.

Modes:
  search   — main search bar with history and fetchable live completions
  history  — browse or delete specific history entries
  confirm  — yes/no confirmation prompt for clearing all history
"""

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime

# ── Config ────────────────────────────────────────────────────────────────────
DEFAULT_HISTORY_FILE = os.path.expanduser("~/.local/share/rofi-websearch/history.txt")
STATE_FILE = "/tmp/search-mode.txt"
MAX_HISTORY = 200
COMPLETION_TIMEOUT = 1.5  # seconds to wait for suggestion API
MAX_COMPLETIONS = 6
LOG_FILE = "/tmp/search-debug.log"  # set to "" to disable

SEARCH_ENGINES = {
    "duckduckgo": "https://duckduckgo.com/?q={}",
    "brave": "https://search.brave.com/search?q={}",
}
DEFAULT_ENGINE = "brave"

# Rofi script-mode protocol
ROFI_PROMPT = "\0prompt\x1f"
ROFI_MESSAGE = "\0message\x1f"
ROFI_URGENT = "\0urgent\x1f"
ROFI_ACTIVE = "\0active\x1f"
ROFI_DELIM = "\0delim\x1f"
ROFI_NO_CUSTOM = "\0no-custom\x1ftrue\n"
ROFI_MARKUP = "\0markup-rows\x1ftrue\n"

# Sentinel entries
HISTORY_ENTRY = "  :history"
CLEAR_ALL = "  :clear-all"
CONFIRM_YES = "  Yes — delete everything"
CONFIRM_NO = "  No — cancel"

# ── URL detection ─────────────────────────────────────────────────────────────
_URL_RE = re.compile(
    r"^(https?://|ftp://)|^([\w-]+\.)+[\w]{2,}(/|$)|^localhost(:\d+)?(/|$)",
    re.IGNORECASE,
)


def looks_like_url(text: str) -> bool:
    """Check if the input string looks like a URL."""
    return bool(_URL_RE.match(text.strip()))


def normalise_url(text: str) -> str:
    """Prepend https:// if the URL is missing a scheme."""
    text = text.strip()
    if not re.match(r"^[a-zA-Z][a-zA-Z0-9+\-.]*://", text):
        text = "https://" + text
    return text


# ── State Management ──────────────────────────────────────────────────────────
def get_mode() -> str:
    """Retrieve the current UI mode from the temporary state file."""
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, "r", encoding="utf-8") as f:
            return f.read().strip()
    return "search"


def set_mode(mode: str) -> None:
    """Persist the current UI mode to the temporary state file."""
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        f.write(mode)


# ── History ───────────────────────────────────────────────────────────────────
def load_history(path: str) -> list[tuple[str, str]]:
    """Load search history from the flat file into a list of tuples."""
    if not os.path.isfile(path):
        return []
    entries = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if "\t" in line:
                ts, entry = line.split("\t", 1)
            else:
                ts, entry = "", line
            if entry:
                entries.append((entry, ts))
    return list(reversed(entries))


def save_history(
    path: str, entry: str, existing: list[tuple[str, str]]
) -> list[tuple[str, str]]:
    """Save a new entry to history and maintain the MAX_HISTORY limit."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    seen: set[str] = set()
    new_entries: list[tuple[str, str]] = []
    for e, ts in [(entry, datetime.now().strftime("%Y-%m-%d %H:%M"))] + existing:
        if e not in seen:
            seen.add(e)
            new_entries.append((e, ts))
        if len(new_entries) >= MAX_HISTORY:
            break
    _write_history(path, new_entries)
    return new_entries


def delete_entry(
    path: str, entry: str, existing: list[tuple[str, str]]
) -> list[tuple[str, str]]:
    """Remove a specific entry from the history file."""
    new_entries = [(e, ts) for e, ts in existing if e != entry]
    _write_history(path, new_entries)
    return new_entries


def clear_all_history(path: str) -> None:
    """Truncate the history file to zero length."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8"):
        pass


def _write_history(path: str, entries: list[tuple[str, str]]) -> None:
    """Internal helper to write the list of history tuples to disk."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        for e, ts in reversed(entries):
            f.write(f"{ts}\t{e}\n")


# ── Completions ───────────────────────────────────────────────────────────────
def _log(msg: str) -> None:
    """Log debug messages to a file if LOG_FILE is configured."""
    if not LOG_FILE:
        return
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(f"{datetime.now().isoformat()} - {msg}\n")


# ── Completion cache ──────────────────────────────────────────────────────────
CACHE_FILE = "/tmp/search-completions.json"


def _cache_key(query: str, engine: str) -> str:
    """Stable cache key for a query+engine pair."""
    return f"{engine}:{query.lower().strip()}"


def _read_cache() -> dict:
    """Load the completion cache, returning empty dict on any error."""
    try:
        with open(CACHE_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return {}


def _write_cache(cache: dict) -> None:
    """Persist the completion cache atomically, tolerating concurrent writers."""
    tmp = f"{CACHE_FILE}.{os.getpid()}.tmp"
    try:
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(cache, f)
        os.replace(tmp, CACHE_FILE)
    except OSError as e:
        _log(f"_write_cache: error {e}")
        try:
            os.unlink(tmp)
        except OSError:
            pass


def _bg_fetch(query: str, engine: str) -> None:
    """Fetch completions and store in cache."""
    _log(f"bg_fetch: started query={query!r} engine={engine!r}")
    try:
        q = urllib.parse.quote_plus(query)
        if engine == "google":
            url = f"https://suggestqueries.google.com/complete/search?client=firefox&q={q}"
        else:
            url = f"https://duckduckgo.com/ac/?q={q}&type=list"
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=COMPLETION_TIMEOUT) as resp:
            data = json.loads(resp.read().decode())
            suggestions = data[1] if isinstance(data, list) and len(data) > 1 else []
            results = [s for s in suggestions if s != query][:MAX_COMPLETIONS]
        cache = _read_cache()
        cache[_cache_key(query, engine)] = results
        if len(cache) > 50:
            keys = list(cache.keys())
            for k in keys[:-50]:
                del cache[k]
        _write_cache(cache)
        _log(f"completions: cached {results} for {query!r}")
    except (urllib.error.URLError, json.JSONDecodeError, OSError) as e:
        _log(f"completions: bg fetch error {type(e).__name__}: {e}")


def fetch_completions(query: str, engine: str) -> list[str]:
    """Return cached completions instantly, and kick off a background refresh."""
    if not query or len(query) < 3:
        return []

    key = _cache_key(query, engine)
    cache = _read_cache()
    cached = cache.get(key, [])
    _log(f"completions: cache {'hit' if cached else 'miss'} for {query!r} -> {cached}")

    _log(f"completions: spawning bg fetch for {query!r} engine={engine!r}")
    subprocess.Popen(  # pylint: disable=consider-using-with
        [sys.executable, sys.argv[0], "--_bg-fetch", query, engine],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    return cached


# ── Open URL ──────────────────────────────────────────────────────────────────
def open_url(url: str, browser: str) -> None:
    """Spawn the browser process detached from the current script."""
    # pylint: disable=consider-using-with
    subprocess.Popen(
        [browser, url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )


# ── Rofi Helpers ──────────────────────────────────────────────────────────────
def print_option(text: str, meta: str = "") -> None:
    """Format and print a single line for Rofi's menu."""
    if meta:
        print(f"{text}\0meta\x1f{meta}")
    else:
        print(text)


def set_prompt(prompt: str) -> None:
    """Send the script-mode command to change the Rofi prompt."""
    sys.stdout.write(f"{ROFI_PROMPT}{prompt}\n")


def set_message(msg: str) -> None:
    """Send the script-mode command to change the Rofi message bar."""
    sys.stdout.write(f"{ROFI_MESSAGE}{msg}\n")


# ── Modes ─────────────────────────────────────────────────────────────────────
def mode_search(query: str, history: list[tuple[str, str]], engine: str) -> None:
    """Display completions and history for the main search interface."""
    set_prompt(f" Search / URL ({engine}):")

    # NEW: Always force exactly what you are typing to the top of the list
    if query:
        print_option(query)

    completions = fetch_completions(query, engine) if query else []
    for c in completions:
        if c != query:  # Prevent it from showing up twice
            print_option(c)
    for e, ts in history:
        if e != query:  # Prevent it from showing up twice
            print_option(e, meta=ts)
    print_option(HISTORY_ENTRY)


def mode_history(history: list[tuple[str, str]]) -> None:
    """Display the history management menu."""
    set_prompt("  History — select to DELETE")
    set_message("Type to filter • select entry to remove it")
    print_option(CLEAR_ALL)
    for e, ts in history:
        print_option(f"{e}  <span size='small' color='gray'>[{ts}]</span>", meta=e)


def mode_confirm() -> None:
    """Display the confirmation prompt for clearing all history."""
    set_prompt(" Clear ALL history?")
    sys.stdout.write(ROFI_NO_CUSTOM)
    print_option(CONFIRM_YES)
    print_option(CONFIRM_NO)


# ── Entry point ───────────────────────────────────────────────────────────────
def _rofi_cmd(script: str) -> list[str]:
    """Return the rofi command list used for all launches."""
    return [
        "rofi",
        "-show",
        "websearch",
        "-modi",
        f"websearch:{script}",
        "-no-fixed-num-lines",
        "-markup-rows",
        "-sync",  # re-invoke on every keystroke for live completions
    ]


def launch_rofi(args: argparse.Namespace) -> None:
    """Launch Rofi in script-mode, re-launching if Esc is pressed in a sub-mode."""
    env = os.environ.copy()
    env.update(
        {
            "WEBSEARCH_ENGINE": str(args.engine),
            "WEBSEARCH_BROWSER": str(args.browser),
            "WEBSEARCH_HISTORY": str(args.history_file),
            "WEBSEARCH_ACTIVE": "1",
        }
    )
    set_mode("search")

    while True:
        subprocess.run(_rofi_cmd(sys.argv[0]), env=env, check=False)

        # Rofi exited (Esc or window close). Check what mode we were in.
        mode = get_mode()
        if mode == "search":
            # Esc on the root search screen — genuinely quit.
            break
        if mode in ("history", "confirm"):
            # Esc inside a sub-menu — go back to search.
            set_mode("search")
            continue
        break


def script_mode(args: argparse.Namespace) -> None:
    """Handle keystrokes and selections passed from Rofi."""
    query = sys.argv[1] if len(sys.argv) > 1 else ""
    # Ensure types for pyright by providing explicit fallbacks
    engine = str(os.environ.get("WEBSEARCH_ENGINE") or args.engine)
    browser = str(os.environ.get("WEBSEARCH_BROWSER") or args.browser)
    hfile = str(os.environ.get("WEBSEARCH_HISTORY") or args.history_file)
    # ROFI_RETV: 0=init, 1=selected existing, 2=custom text entered
    retv = int(os.environ.get("ROFI_RETV", "0"))

    mode = get_mode()
    history = load_history(hfile)
    _log(
        f"script_mode: mode={mode!r} query={query!r} retv={retv} engine={engine!r} argv={sys.argv}"
    )

    if mode == "confirm":
        if query == CONFIRM_YES:
            clear_all_history(hfile)
            set_mode("history")
            mode_history([])
        else:
            set_mode("history")
            mode_history(history)
        return

    if mode == "history":
        if query == CLEAR_ALL:
            set_mode("confirm")
            mode_confirm()
            return
        if query and query != HISTORY_ENTRY:
            raw = re.sub(r"\s*<span[^>]*>.*?</span>", "", query).strip()
            raw = re.sub(r"\s+\[[\d\- :]+\]$", "", raw).strip()
            history = delete_entry(hfile, raw, history)
        set_mode("history")
        mode_history(history)
        return

    if query == HISTORY_ENTRY:
        set_mode("history")
        mode_history(history)
        return

    if query and retv == 1:
        # User confirmed a selection from the list (history or suggestion) — open it.
        history = save_history(hfile, query, history)
        if looks_like_url(query):
            url = normalise_url(query)
        else:
            url = SEARCH_ENGINES[engine].format(urllib.parse.quote_plus(query))
        open_url(url, browser)
        # Return without printing anything to close Rofi
        return

    if query and retv == 2:
        # User pressed Shift+Enter (or custom shortcut) on custom text.
        # Fetch suggestions synchronously so they appear immediately on screen.
        _bg_fetch(query, engine)
        set_mode("search")

        # Render the completions and history (with the query forced to the top)
        mode_search(query, history, engine)
        return

    # retv=0: rofi is rendering/updating — show completions + history.
    mode_search(query, history, engine)


def main() -> None:
    """Parse CLI arguments and decide between launching Rofi or running logic."""
    # Internal flag used by background completion fetcher — handle before argparse
    if len(sys.argv) == 4 and sys.argv[1] == "--_bg-fetch":
        _bg_fetch(query=sys.argv[2], engine=sys.argv[3])
        return

    parser = argparse.ArgumentParser()
    parser.add_argument("--browser", default="xdg-open")
    parser.add_argument(
        "--engine", default=DEFAULT_ENGINE, choices=list(SEARCH_ENGINES.keys())
    )
    parser.add_argument("--history-file", default=DEFAULT_HISTORY_FILE)
    args, _ = parser.parse_known_args()

    if "WEBSEARCH_ACTIVE" in os.environ:
        script_mode(args)
    else:
        launch_rofi(args)


if __name__ == "__main__":
    main()
