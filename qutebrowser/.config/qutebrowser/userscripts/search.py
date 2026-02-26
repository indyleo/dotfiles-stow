#!/usr/bin/env python3
"""
search.py — Web search / URL launcher via rofi with "press-to-fetch" completions.

Bang shortcuts (!):
  Prefix your query with a bang to search a specific site directly, e.g.:
    !yt linux tips        → YouTube search
    !aw pacman            → Arch Wiki search
    !gh rust async        → GitHub search
  Type just "!" to see all available bangs listed in the menu.

How to use it:
  1. Type your query: Rofi will instantly filter your local history.
  2. Press [Enter]: Immediately searches the exact text you typed.
  3. Press [Shift+Enter]*: Fetches live web suggestions from the internet.

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
COMPLETION_TIMEOUT = 1.5
MAX_COMPLETIONS = 6
LOG_FILE = "/tmp/search-debug.log"  # set to "" to disable

SEARCH_ENGINES = {
    "duckduckgo": "https://duckduckgo.com/?q={}",
    "brave": "https://search.brave.com/search?q={}",
}
DEFAULT_ENGINE = "brave"

# ── Bang shortcuts ─────────────────────────────────────────────────────────────
# Format: "!bang": ("Display Label", "https://example.com/search?q={}")
# The {} placeholder is replaced with the URL-encoded query.
BANGS: dict[str, tuple[str, str]] = {
    # ── Dev / code ────────────────────────────────────────────────────────────
    "!gh": ("GitHub", "https://github.com/search?q={}"),
    "!so": ("Stack Overflow", "https://stackoverflow.com/search?q={}"),
    "!pypi": ("PyPI", "https://pypi.org/search/?q={}"),
    "!cra": ("crates.io", "https://crates.io/search?q={}"),
    "!npm": ("npm", "https://www.npmjs.com/search?q={}"),
    # ── Linux / distro ────────────────────────────────────────────────────────
    "!dp": ("Debian Packages", "https://packages.debian.org/search?keywords={}"),
    "!aw": ("Arch Wiki", "https://wiki.archlinux.org/?search={}"),
    "!ah": ("Arch Packages", "https://archlinux.org/packages/?sort=&q={}"),
    "!ar": ("AUR", "https://aur.archlinux.org/packages?O=0&K={}"),
    "!fh": ("Flathub", "https://flathub.org/apps/search?q={}"),
    "!gw": ("Gentoo Wiki", "https://wiki.gentoo.org/index.php?search={}"),
    "!nw": ("NixOS Wiki", "https://wiki.nixos.org/w/index.php?search={}"),
    # ── Reference ─────────────────────────────────────────────────────────────
    "!wiki": ("Wikipedia", "https://en.wikipedia.org/wiki/{}"),
    "!wikt": ("Wiktionary", "https://en.wiktionary.org/wiki/{}"),
    "!wb": ("Wolfram Alpha", "https://www.wolframalpha.com/input?i={}"),
    # ── Media / entertainment ─────────────────────────────────────────────────
    "!yt": ("YouTube", "https://www.youtube.com/search?q={}"),
    "!tv": ("Twitch", "https://www.twitch.tv/search?term={}"),
    "!pd": ("ProtonDB", "https://www.protondb.com/search?q={}"),
    "!rd": ("Reddit", "https://www.reddit.com/search/?q={}"),
}


# ── Bang helpers ───────────────────────────────────────────────────────────────


def parse_bang(text: str) -> tuple[str | None, str]:
    """
    Split a query into (bang, rest).

    Returns (None, text) when no recognised bang is present.
    A bare bang with no query (e.g. "!yt") returns (bang, "").
    """
    m = re.match(r"^(![\w]+)\s*(.*)", text.strip(), re.IGNORECASE)
    if m:
        bang = m.group(1).lower()
        rest = m.group(2).strip()
        if bang in BANGS:
            return bang, rest
    return None, text.strip()


def bang_url(bang: str, query: str) -> str:
    """Build the destination URL for a bang + query pair."""
    _, url_template = BANGS[bang]
    if query:
        return url_template.format(urllib.parse.quote_plus(query))
    # No query — navigate to the site root
    return re.sub(r"(https?://[^/]+).*", r"\1", url_template)


def bang_hint_entries() -> list[tuple[str, str]]:
    """One display line per bang, shown when the user types a lone '!'."""
    return [(f"{bang}  —  {label}", bang) for bang, (label, _) in sorted(BANGS.items())]


# ── Rofi script-mode protocol ─────────────────────────────────────────────────
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
    return bool(_URL_RE.match(text.strip()))


def normalise_url(text: str) -> str:
    text = text.strip()
    if not re.match(r"^[a-zA-Z][a-zA-Z0-9+\-.]*://", text):
        text = "https://" + text
    return text


# ── State management ──────────────────────────────────────────────────────────
def get_mode() -> str:
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, "r", encoding="utf-8") as f:
            return f.read().strip()
    return "search"


def set_mode(mode: str) -> None:
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        f.write(mode)


# ── History ───────────────────────────────────────────────────────────────────
def load_history(path: str) -> list[tuple[str, str]]:
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
    new_entries = [(e, ts) for e, ts in existing if e != entry]
    _write_history(path, new_entries)
    return new_entries


def clear_all_history(path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8"):
        pass


def _write_history(path: str, entries: list[tuple[str, str]]) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        for e, ts in reversed(entries):
            f.write(f"{ts}\t{e}\n")


# ── Completions ───────────────────────────────────────────────────────────────
def _log(msg: str) -> None:
    if not LOG_FILE:
        return
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(f"{datetime.now().isoformat()} - {msg}\n")


CACHE_FILE = "/tmp/search-completions.json"


def _cache_key(query: str, engine: str) -> str:
    return f"{engine}:{query.lower().strip()}"


def _read_cache() -> dict:
    try:
        with open(CACHE_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return {}


def _write_cache(cache: dict) -> None:
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
    subprocess.Popen(  # pylint: disable=consider-using-with
        [sys.executable, sys.argv[0], "--_bg-fetch", query, engine],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return cached


# ── Open URL ──────────────────────────────────────────────────────────────────
def open_url(url: str, browser: str) -> None:
    subprocess.Popen(  # pylint: disable=consider-using-with
        [browser, url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )


# ── Rofi helpers ──────────────────────────────────────────────────────────────
def print_option(text: str, meta: str = "") -> None:
    if meta:
        print(f"{text}\0meta\x1f{meta}")
    else:
        print(text)


def set_prompt(prompt: str) -> None:
    sys.stdout.write(f"{ROFI_PROMPT}{prompt}\n")


def set_message(msg: str) -> None:
    sys.stdout.write(f"{ROFI_MESSAGE}{msg}\n")


# ── Modes ─────────────────────────────────────────────────────────────────────
def mode_search(query: str, history: list[tuple[str, str]], engine: str) -> None:
    """Render the main search interface, with bang-aware prompt/completions."""
    bang, rest = parse_bang(query)

    # ── Bang mode: user has typed a valid "!bang [query]" ─────────────────────
    if bang:
        label, _ = BANGS[bang]
        set_prompt(f" {label}:")
        set_message(
            f"<b>{bang}</b> → {label}  "
            f"•  Enter to search  •  no query opens the site"
        )
        # Pin the full typed text to the top so Enter always does what you see
        print_option(query)
        # Sub-query completions (re-use the normal engine's suggestion API)
        if rest and len(rest) >= 3:
            for c in fetch_completions(rest, engine):
                full = f"{bang} {c}"
                if full != query:
                    print_option(full)
        return

    # ── Normal search / URL ───────────────────────────────────────────────────
    set_prompt(f" Search / URL ({engine}):")
    if query:
        print_option(query)
    completions = fetch_completions(query, engine) if query else []
    for c in completions:
        if c != query:
            print_option(c)
    for e, ts in history:
        if e != query:
            print_option(e, meta=ts)
    print_option(HISTORY_ENTRY)


def mode_history(history: list[tuple[str, str]]) -> None:
    set_prompt("  History — select to DELETE")
    set_message("Type to filter • select entry to remove it")
    print_option(CLEAR_ALL)
    for e, ts in history:
        print_option(f"{e}  <span size='small' color='gray'>[{ts}]</span>", meta=e)


def mode_confirm() -> None:
    set_prompt(" Clear ALL history?")
    sys.stdout.write(ROFI_NO_CUSTOM)
    print_option(CONFIRM_YES)
    print_option(CONFIRM_NO)


# ── Rofi launch ───────────────────────────────────────────────────────────────
def _rofi_cmd(script: str) -> list[str]:
    return [
        "rofi",
        "-show",
        "websearch",
        "-modi",
        f"websearch:{script}",
        "-no-fixed-num-lines",
        "-markup-rows",
        "-sync",
    ]


def launch_rofi(args: argparse.Namespace) -> None:
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
        mode = get_mode()
        if mode == "search":
            break
        if mode in ("history", "confirm"):
            set_mode("search")
            continue
        break


def script_mode(args: argparse.Namespace) -> None:
    """Handle keystrokes and selections passed from Rofi."""
    query = sys.argv[1] if len(sys.argv) > 1 else ""
    engine = str(os.environ.get("WEBSEARCH_ENGINE") or args.engine)
    browser = str(os.environ.get("WEBSEARCH_BROWSER") or args.browser)
    hfile = str(os.environ.get("WEBSEARCH_HISTORY") or args.history_file)
    retv = int(os.environ.get("ROFI_RETV", "0"))

    mode = get_mode()
    history = load_history(hfile)
    _log(f"script_mode: mode={mode!r} query={query!r} retv={retv} engine={engine!r}")

    # ── Confirm mode ──────────────────────────────────────────────────────────
    if mode == "confirm":
        if query == CONFIRM_YES:
            clear_all_history(hfile)
            set_mode("history")
            mode_history([])
        else:
            set_mode("history")
            mode_history(history)
        return

    # ── History mode ──────────────────────────────────────────────────────────
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

    # ── Switch to history view ────────────────────────────────────────────────
    if query == HISTORY_ENTRY:
        set_mode("history")
        mode_history(history)
        return

    # ── Shift+Enter (retv=2): open bang URL or fetch live suggestions ─────────
    if query and retv == 2:
        bang, rest = parse_bang(query)
        if bang:
            # Bang + Shift+Enter: open the bang URL (same as regular Enter)
            history = save_history(hfile, query, history)
            open_url(bang_url(bang, rest), browser)
            return
        # Normal Shift+Enter: fetch suggestions and re-render
        _bg_fetch(query, engine)
        set_mode("search")
        mode_search(query, history, engine)
        return

    # ── Enter (retv=1): open selected / typed item ────────────────────────────
    if query and retv == 1:
        # If the user selected a bang cheatsheet hint line ("!yt  —  YouTube"),
        # open the site root (no query given).
        hint_match = re.match(r"^(![\w]+)\s+—\s+", query)
        if hint_match:
            bang_token = hint_match.group(1).lower()
            if bang_token in BANGS:
                open_url(bang_url(bang_token, ""), browser)
            return

        # Resolve bang → URL
        bang, rest = parse_bang(query)
        if bang:
            history = save_history(hfile, query, history)
            open_url(bang_url(bang, rest), browser)
            return

        # Normal search / URL
        history = save_history(hfile, query, history)
        if looks_like_url(query):
            url = normalise_url(query)
        else:
            url = SEARCH_ENGINES[engine].format(urllib.parse.quote_plus(query))
        open_url(url, browser)
        return

    # ── retv=0: Rofi is rendering / updating the list ─────────────────────────
    mode_search(query, history, engine)


# ── Entry point ───────────────────────────────────────────────────────────────
def main() -> None:
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
