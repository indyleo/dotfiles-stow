#!/usr/bin/env python3
"""
Bookmarks — Browse HTML bookmark files.

Menu backend:
  Wayland + Quickshell running -> talks directly to the Quickshell
  Dmenu picker over `qs ipc call` (no qsdmenu wrapper needed).
  Anything else                -> dmenu.
"""

import argparse
import glob
import os
import shutil
import subprocess
import sys
import tempfile
from html.parser import HTMLParser

# ── Config ────────────────────────────────────────────────────────────────────
DEFAULT_PATHS = [
    os.path.expanduser("~/.local/share/bookmarks/bookmarks.html"),
]

# ── Display server detection ──────────────────────────────────────────────────
IS_WAYLAND = bool(os.environ.get("WAYLAND_DISPLAY"))


# ── Menu backends ────────────────────────────────────────────────────────────
def _quickshell_menu(items, prompt="run"):
    """Talk directly to the Quickshell Dmenu picker over IPC.
    Same protocol as the qsdmenu wrapper script:
        qs ipc call pick dmenu <inputFile> <outputFifo> <prompt>
    Returns the first selected line, or None if cancelled / nothing chosen.
    """
    tmpdir = tempfile.mkdtemp(prefix="bookmarks-qs-")
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

        # Blocks until the picker writes a result (or is dismissed, which
        # writes an empty string).
        with open(outfifo, "r", encoding="utf-8") as f:
            result = f.read()
        result = result.strip()
        return result if result else None
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def _dmenu_menu(items, prompt="run"):
    result = subprocess.run(
        ["dmenu", "-p", prompt],
        input="\n".join(items),
        capture_output=True,
        text=True,
    )
    return result.stdout.strip() if result.returncode == 0 else None


def menu(items, prompt="Bookmarks"):
    """Show a menu via Quickshell (Wayland) or dmenu (X11). Returns selection or None."""
    if IS_WAYLAND:
        return _quickshell_menu(items, prompt)
    return _dmenu_menu(items, prompt)


def error(msg):
    """Show an error message. notify-send works fine on both, and the
    Quickshell Dmenu picker has no built-in message/error surface."""
    subprocess.run(["notify-send", "Bookmarks", msg], check=False)


# ── Parser ────────────────────────────────────────────────────────────────────
class BookmarkParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.root = {"title": "ROOT", "children": [], "type": "folder"}
        self._stack = [self.root]
        self._next_title = None
        self._in_a = False
        self._current_href = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "dl":
            if self._stack[-1].get("_pending_folder"):
                folder = self._stack[-1]["_pending_folder"]
                self._stack[-1]["children"].append(folder)
                self._stack.append(folder)
                del self._stack[-2]["_pending_folder"]
        elif tag == "h3":
            self._next_title = ""
        elif tag == "a":
            self._in_a = True
            self._current_href = attrs.get("href", "")
            self._next_title = ""

    def handle_endtag(self, tag):
        if tag == "h3":
            folder = {
                "title": self._next_title or "Folder",
                "children": [],
                "type": "folder",
            }
            self._stack[-1]["_pending_folder"] = folder
            self._next_title = None
        elif tag == "a":
            if self._in_a:
                item = {
                    "title": self._next_title or self._current_href,
                    "url": self._current_href,
                    "type": "link",
                }
                self._stack[-1]["children"].append(item)
            self._in_a = False
            self._current_href = None
            self._next_title = None
        elif tag == "dl":
            if len(self._stack) > 1:
                self._stack.pop()

    def handle_data(self, data):
        if self._next_title is not None:
            self._next_title += data


# ── Navigation ────────────────────────────────────────────────────────────────
BACK = "<- Back"
ICON_FOLDER = "\uf07b"  # nf-fa-folder
ICON_LINK = "\uf0c1"  # nf-fa-link


def open_url(url, browser):
    subprocess.Popen(
        [browser, url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )


def browse(folder, browser, breadcrumb=None):
    breadcrumb = breadcrumb or []
    path_str = " / ".join(["ROOT"] + breadcrumb) if breadcrumb else "ROOT"

    while True:
        children = folder.get("children", [])
        entries = []
        if breadcrumb:
            entries.append(BACK)
        for child in children:
            if child["type"] == "folder":
                entries.append(f"{ICON_FOLDER} {child['title']}")
            else:
                entries.append(f"{ICON_LINK} {child['title']}")

        choice = menu(entries, prompt=path_str)
        if choice is None:
            return
        if choice == BACK:
            return

        # Strip icon prefix (either icon, one space)
        label = choice[len(ICON_FOLDER) :].strip() if choice.startswith(ICON_FOLDER) else choice[len(ICON_LINK) :].strip()

        matched = None
        for child in children:
            if child["title"] == label:
                matched = child
                break

        if matched is None:
            return

        if matched["type"] == "folder":
            browse(matched, browser, breadcrumb + [matched["title"]])
        else:
            open_url(matched["url"], browser)


# ── Entry point ───────────────────────────────────────────────────────────────
def find_bookmark_file():
    for pattern in DEFAULT_PATHS:
        matches = glob.glob(pattern)
        if matches:
            return matches[0]
    return None


def main():
    parser = argparse.ArgumentParser(description="Browse HTML bookmarks.")
    parser.add_argument("--browser", default="xdg-open")
    args = parser.parse_args()

    path = find_bookmark_file()
    if not path:
        error("No bookmark file found. Check DEFAULT_PATHS in the script.")
        sys.exit(1)

    if not os.path.isfile(path):
        error(f"File not found: {path}")
        sys.exit(1)

    with open(path, "r", encoding="utf-8", errors="replace") as f:
        html = f.read()

    bp = BookmarkParser()
    bp.feed(html)

    root = bp.root
    while (
        len(root.get("children", [])) == 1 and root["children"][0]["type"] == "folder"
    ):
        root = root["children"][0]

    browse(root, args.browser)


if __name__ == "__main__":
    main()
