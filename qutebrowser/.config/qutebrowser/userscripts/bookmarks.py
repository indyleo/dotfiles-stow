#!/usr/bin/env python3
"""
Bookmarks — Browse HTML bookmark files via rofi.

Usage:
    python3 bookmarks.py [--browser BROWSER]

The bookmark file is read from DEFAULT_PATHS.
BROWSER defaults to xdg-open if not specified.
"""

import argparse
import glob
import os
import subprocess
import sys
from html.parser import HTMLParser

# ── Config ────────────────────────────────────────────────────────────────────
# Default search paths (edit to taste)
DEFAULT_PATHS = [
    os.path.expanduser("~/.local/share/bookmarks/bookmarks.html"),
]


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


# ── Rofi helpers ──────────────────────────────────────────────────────────────
def rofi_select(items, prompt="Bookmarks"):
    """Show items in rofi, return selected string or None."""
    result = subprocess.run(
        ["rofi", "-dmenu", "-i", "-p", prompt],
        input="\n".join(items),
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return None
    return result.stdout.strip()


def open_url(url, browser):
    subprocess.Popen(
        [browser, url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )


# ── Navigation ────────────────────────────────────────────────────────────────
BACK = "← Back"


def browse(folder, browser, breadcrumb=None):
    """Recursively browse folders, open links."""
    breadcrumb = breadcrumb or []
    path_str = " / ".join(["ROOT"] + breadcrumb) if breadcrumb else "ROOT"

    while True:
        children = folder.get("children", [])

        entries = []
        if breadcrumb:
            entries.append(BACK)

        for child in children:
            if child["type"] == "folder":
                entries.append(f"  {child['title']}")
            else:
                entries.append(f"  {child['title']}")

        choice = rofi_select(entries, prompt=path_str)
        if choice is None:
            return  # ESC / closed

        if choice == BACK:
            return  # go up a level

        # strip icon prefix (3 chars: icon + 2 spaces)
        label = choice[3:].strip()

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
    parser = argparse.ArgumentParser(description="Browse HTML bookmarks via rofi.")
    parser.add_argument(
        "--browser",
        default="xdg-open",
        help="Browser command to open URLs (default: xdg-open)",
    )
    args = parser.parse_args()

    path = find_bookmark_file()
    if not path:
        subprocess.run(
            ["rofi", "-e", "No bookmark file found. Check DEFAULT_PATHS in the script."]
        )
        sys.exit(1)

    if not os.path.isfile(path):
        subprocess.run(["rofi", "-e", f"File not found: {path}"])
        sys.exit(1)

    with open(path, "r", encoding="utf-8", errors="replace") as f:
        html = f.read()

    bp = BookmarkParser()
    bp.feed(html)

    root = bp.root
    # flatten single-child roots for convenience
    while (
        len(root.get("children", [])) == 1 and root["children"][0]["type"] == "folder"
    ):
        root = root["children"][0]

    browse(root, args.browser)


if __name__ == "__main__":
    main()
