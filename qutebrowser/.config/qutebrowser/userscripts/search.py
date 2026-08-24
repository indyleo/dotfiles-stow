#!/usr/bin/env python3
"""
search.py — Web search / URL launcher, dmenu-style multi-step menu.

Menu backend:
  Wayland + Quickshell running -> talks directly to the Quickshell Dmenu
  picker over `qs ipc call` (no qsdmenu wrapper needed).
  Anything else                -> dmenu.

Bang shortcuts (!):
  Prefix your query with a bang to search a specific site directly, e.g.:
    !yt linux tips        → YouTube search
    !aw pacman            → Arch Wiki search
    !gh rust async        → GitHub search
  Type just "!" at the top-level menu to pick "Show all bangs".

Flow (each step is its own menu — same shape as dmenu's original two-step
search: pick/type a query, then confirm/pick a suggestion):
  1. Top menu: history entries, plus "Show all bangs" / "History" / "Clear
     history" utility entries. Type a fresh query and hit Enter, or pick
     a past one.
  2. If what you picked/typed is a bang or a URL, it opens immediately.
  3. Otherwise, live suggestions are fetched and a second menu lets you
     confirm the exact text or pick a suggestion.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import urllib.error
import urllib.parse
import urllib.request

from datetime import datetime

# ── Display server detection ──────────────────────────────────────────────────
IS_WAYLAND = bool(os.environ.get("WAYLAND_DISPLAY"))

# ── Config ────────────────────────────────────────────────────────────────────
DEFAULT_HISTORY_FILE = os.path.expanduser("~/.local/share/rofi-websearch/history.txt")
MAX_HISTORY = 200

SEARCH_ENGINES = {
    "searxng": "https://searxng.linuxlab.work/search?q={}",
    "brave": "https://search.brave.com/search?q={}",
    "duckduckgo": "https://duckduckgo.com/?q={}",
}
DEFAULT_ENGINE = "searxng"

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


# ── Menu backends ────────────────────────────────────────────────────────────
def _quickshell_menu(items, prompt="run"):
    """Talk directly to the Quickshell Dmenu picker over IPC, same protocol
    as the qsdmenu wrapper script:
        qs ipc call pick dmenu <inputFile> <outputFifo> <prompt>
    """
    tmpdir = tempfile.mkdtemp(prefix="search-qs-")
    try:
        infile = os.path.join(tmpdir, "in")
        outfifo = os.path.join(tmpdir, "out")
        with open(infile, "w", encoding="utf-8") as f:
            f.write("\n".join(items))
        os.mkfifo(outfifo)

        subprocess.run(
            ["qs", "ipc", "call", "pick", "dmenu", infile, outfifo, prompt],
            check=False,
        )

        with open(outfifo, "r", encoding="utf-8") as f:
            result = f.read()
        result = result.strip()
        return result if result else None
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def _dmenu_menu(items, prompt="run"):
    result = subprocess.run(
        ["dmenu", "-l", "15", "-p", prompt],
        input="\n".join(items),
        capture_output=True,
        text=True,
    )
    return result.stdout.strip() if result.returncode == 0 else None


def MENU(items, prompt="run"):
    if IS_WAYLAND:
        return _quickshell_menu(items, prompt)
    return _dmenu_menu(items, prompt)


def notify(msg: str) -> None:
    subprocess.run(["notify-send", "Search", msg], check=False)


# ── Open URL ──────────────────────────────────────────────────────────────────
def open_url(url: str, browser: str) -> None:
    subprocess.Popen(
        [browser, url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )


def _menu_bang_url(bang: str, query: str) -> str:
    _, template = BANGS[bang]
    if query:
        return template.format(urllib.parse.quote_plus(query))
    return re.sub(r"(https?://[^/]+).*", r"\1", template)


# ── Sub-flows ─────────────────────────────────────────────────────────────────
def mode_bangs(history, engine, browser, hfile):
    bang_items = [f"{b}  —  {label}" for b, (label, _) in sorted(BANGS.items())]
    choice = MENU(bang_items, "Select bang:")
    if choice is None:
        return
    bang_token = choice.split()[0].lower()
    if bang_token not in BANGS:
        return
    label, _ = BANGS[bang_token]
    query = MENU([], f"{label} query:")
    if query is None:
        return
    full = f"{bang_token} {query}".strip()
    save_history(hfile, full, history)
    open_url(_menu_bang_url(bang_token, query), browser)


def mode_history(history, hfile):
    if not history:
        notify("History is empty.")
        return
    choice = MENU([e for e, _ in history], "Delete entry:")
    if choice is None:
        return
    delete_entry(hfile, choice, history)
    notify(f"Deleted: {choice}")


def mode_confirm_clear(history, hfile):
    choice = MENU(["No — cancel", "Yes — delete everything"], "Clear all history?")
    if choice and "Yes" in choice:
        clear_all_history(hfile)
        notify("History cleared.")


def fetch_and_pick(query: str, engine: str, browser: str, hfile: str, history) -> None:
    """Fetch completions for query, show a second menu to pick or confirm, then open."""
    suggestions = []
    done = threading.Event()

    def _fetch():
        try:
            q = urllib.parse.quote_plus(query)
            url = f"https://duckduckgo.com/ac/?q={q}&type=list"
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=3.0) as resp:
                import json

                data = json.loads(resp.read().decode())
                if isinstance(data, list) and len(data) > 1:
                    suggestions.extend(s for s in data[1] if s != query)
        except (urllib.error.URLError, OSError, ValueError):
            pass
        finally:
            done.set()

    t = threading.Thread(target=_fetch, daemon=True)
    t.start()
    done.wait(timeout=3.5)

    # Build second menu: query itself at top, then suggestions
    items = [query] + suggestions[:8]
    choice = MENU(items, f"Confirm / pick ({engine}):")
    if choice is None:
        return

    save_history(hfile, choice, history)

    bang, rest = parse_bang(choice)
    if bang:
        open_url(_menu_bang_url(bang, rest), browser)
        return
    if looks_like_url(choice):
        open_url(normalise_url(choice), browser)
        return

    url = SEARCH_ENGINES[engine].format(urllib.parse.quote_plus(choice))
    open_url(url, browser)


def launch(args: argparse.Namespace) -> None:
    history = load_history(args.history_file)
    hist_entries = [e for e, _ in history]
    items = ["!! (show all bangs)", ":history", ":clear"] + hist_entries

    choice = MENU(items, f"Search ({args.engine}):")
    if choice is None:
        return

    if choice == ":history":
        mode_history(history, args.history_file)
        return
    if choice == ":clear":
        mode_confirm_clear(history, args.history_file)
        return
    if choice == "!! (show all bangs)":
        mode_bangs(history, args.engine, args.browser, args.history_file)
        return

    bang, rest = parse_bang(choice)
    if bang:
        save_history(args.history_file, choice, history)
        open_url(_menu_bang_url(bang, rest), args.browser)
        return

    if looks_like_url(choice):
        save_history(args.history_file, choice, history)
        open_url(normalise_url(choice), args.browser)
        return

    # Not a bang or URL — fetch suggestions and show second menu
    fetch_and_pick(choice, args.engine, args.browser, args.history_file, history)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--browser", default="xdg-open")
    parser.add_argument(
        "--engine", default=DEFAULT_ENGINE, choices=list(SEARCH_ENGINES.keys())
    )
    parser.add_argument("--history-file", default=DEFAULT_HISTORY_FILE)
    args, _ = parser.parse_known_args()

    launch(args)


if __name__ == "__main__":
    main()
