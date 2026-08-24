#!/usr/bin/env python3
"""
Quickmarks launcher.

Menu backend:
  Wayland + Quickshell running -> talks directly to the Quickshell
  Dmenu picker over `qs ipc call` (no qsdmenu wrapper needed).
  Anything else                -> dmenu.
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile

# ── Display server detection ──────────────────────────────────────────────────
IS_WAYLAND = bool(os.environ.get("WAYLAND_DISPLAY"))

QUICKMARKS_FILE = os.path.expanduser("~/.local/share/bookmarks/quickmarks.txt")


def load_quickmarks(filepath):
    marks = {}
    if not os.path.exists(filepath):
        os.makedirs(os.path.dirname(filepath), exist_ok=True)
        open(filepath, "a").close()
        return marks
    with open(filepath, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split(maxsplit=1)
            if len(parts) == 2:
                marks[parts[0]] = parts[1]
    return marks


# ── Menu backends ────────────────────────────────────────────────────────────
def _quickshell_menu(items, prompt="run"):
    """Talk directly to the Quickshell Dmenu picker over IPC, same protocol
    as the qsdmenu wrapper script:
        qs ipc call pick dmenu <inputFile> <outputFifo> <prompt>
    """
    tmpdir = tempfile.mkdtemp(prefix="quickmarks-qs-")
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
        ["dmenu", "-p", prompt],
        input="\n".join(items),
        capture_output=True,
        text=True,
    )
    return result.stdout.strip() if result.returncode == 0 else None


def menu_select(items, prompt=" Quickmarks:"):
    if IS_WAYLAND:
        return _quickshell_menu(items, prompt)
    return _dmenu_menu(items, prompt)


def open_url(url, browser):
    subprocess.Popen(
        [browser, url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )


def main():
    parser = argparse.ArgumentParser(description="Quickmarks launcher.")
    parser.add_argument("--browser", default="xdg-open")
    parser.add_argument("--file", default=QUICKMARKS_FILE)
    args = parser.parse_args()

    quickmarks = load_quickmarks(args.file)

    if not quickmarks:
        print(f"No bookmarks found in {args.file}")
        sys.exit(1)

    width = max(len(k) for k in quickmarks)
    entries = [f"{k:<{width}}  {v}" for k, v in quickmarks.items()]

    choice = menu_select(entries)
    if choice:
        keyword = choice.split()[0]
        url = quickmarks.get(keyword)
        if url:
            open_url(url, args.browser)


if __name__ == "__main__":
    main()
