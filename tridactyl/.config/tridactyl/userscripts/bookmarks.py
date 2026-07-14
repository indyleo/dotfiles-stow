#!/usr/bin/env python3
"""
Bookmarks — Browse HTML bookmark files via rofi (Wayland) or dmenu (X11).
"""

import argparse
import glob
import os
import subprocess
import sys
from html.parser import HTMLParser

# ── Config ────────────────────────────────────────────────────────────────────
DEFAULT_PATHS = [
    os.path.expanduser("~/.local/share/bookmarks/bookmarks.html"),
]

# ── Display server detection ──────────────────────────────────────────────────
IS_WAYLAND = bool(os.environ.get("WAYLAND_DISPLAY"))


def menu(items, prompt="Bookmarks"):
    """Show a menu via rofi (Wayland) or dmenu (X11). Returns selection or None."""
    if IS_WAYLAND:
        cmd = ["rofi", "-dmenu", "-i", "-p", prompt]
    else:
        cmd = ["dmenu", "-p", prompt]
    result = subprocess.run(cmd, input="\n".join(items), capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else None


def error(msg):
    """Show an error message via rofi -e (Wayland) or notify-send (X11)."""
    if IS_WAYLAND:
        subprocess.run(["rofi", "-e", msg], check=False)
    else:
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
                entries.append(f" {child['title']}")
            else:
                entries.append(f" {child['title']}")

        choice = menu(entries, prompt=path_str)
        if choice is None:
            return
        if choice == BACK:
            return

        # Strip prefix
        label = choice.lstrip("").strip()

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
