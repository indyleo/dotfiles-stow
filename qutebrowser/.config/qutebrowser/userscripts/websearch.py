#!/usr/bin/env python3
"""
websearch.py — Web search / URL launcher via rofi with live completions.

Rofi script-mode: rofi calls this script with the current input on every keystroke.
Modes:
  search   — main search bar with live completions + history
  history  — browse/delete history entries
  confirm  — yes/no confirmation prompt
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
STATE_FILE = "/tmp/rofi-websearch-mode.txt"
MAX_HISTORY = 200
COMPLETION_TIMEOUT = 1.5  # seconds to wait for suggestion API
MAX_COMPLETIONS = 6
LOG_FILE = ""  # set to "/tmp/websearch-debug.log" to enable

SEARCH_ENGINES = {
    "duckduckgo": "https://duckduckgo.com/?q={}",
    "brave": "https://search.brave.com/search?q={}",
    "google": "https://www.google.com/search?q={}",
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


def fetch_completions(query: str, engine: str) -> list[str]:
    """Fetch search suggestions from the chosen search engine's API."""
    if not query or len(query) < 3:
        return []
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
            return [s for s in suggestions if s != query][:MAX_COMPLETIONS]
    except (urllib.error.URLError, json.JSONDecodeError, OSError) as e:
        _log(f"Completion error: {e}")
        return []


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
    set_prompt(f"Search / URL ({engine})")
    completions = fetch_completions(query, engine) if query else []
    for c in completions:
        print_option(c)
    for e, ts in history:
        print_option(e, meta=ts)
    print_option(HISTORY_ENTRY)


def mode_history(history: list[tuple[str, str]]) -> None:
    """Display the history management menu."""
    set_prompt("History — select to DELETE")
    set_message("Type to filter • select entry to remove it")
    print_option(CLEAR_ALL)
    for e, ts in history:
        print_option(f"{e}  <span size='small' color='gray'>[{ts}]</span>", meta=e)


def mode_confirm() -> None:
    """Display the confirmation prompt for clearing all history."""
    set_prompt("Clear ALL history?")
    sys.stdout.write(ROFI_NO_CUSTOM)
    print_option(CONFIRM_YES)
    print_option(CONFIRM_NO)


# ── Entry point ───────────────────────────────────────────────────────────────
def launch_rofi(args: argparse.Namespace) -> None:
    """Initialise and launch Rofi in script-mode."""
    set_mode("search")
    env = os.environ.copy()
    env.update(
        {
            "WEBSEARCH_ENGINE": str(args.engine),
            "WEBSEARCH_BROWSER": str(args.browser),
            "WEBSEARCH_HISTORY": str(args.history_file),
            "WEBSEARCH_ACTIVE": "1",
        }
    )
    subprocess.run(
        [
            "rofi",
            "-show",
            "websearch",
            "-modi",
            f"websearch:{sys.argv[0]}",
            "-no-fixed-num-lines",
            "-markup-rows",
            "-sync",  # re-invoke on every keystroke for live completions
        ],
        env=env,
        check=False,
    )


def script_mode(args: argparse.Namespace) -> None:
    """Handle keystrokes and selections passed from Rofi."""
    query = sys.argv[1] if len(sys.argv) > 1 else ""
    # Ensure types for pyright by providing explicit fallbacks
    engine = str(os.environ.get("WEBSEARCH_ENGINE") or args.engine)
    browser = str(os.environ.get("WEBSEARCH_BROWSER") or args.browser)
    hfile = str(os.environ.get("WEBSEARCH_HISTORY") or args.history_file)

    mode = get_mode()
    history = load_history(hfile)

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

    if query:
        history = save_history(hfile, query, history)
        if looks_like_url(query):
            url = normalise_url(query)
        else:
            url = SEARCH_ENGINES[engine].format(urllib.parse.quote_plus(query))
        open_url(url, browser)
        set_mode("search")
        mode_search("", history, engine)  # re-render so rofi stays open
        return

    mode_search(query, history, engine)


def main() -> None:
    """Parse CLI arguments and decide between launching Rofi or running logic."""
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
