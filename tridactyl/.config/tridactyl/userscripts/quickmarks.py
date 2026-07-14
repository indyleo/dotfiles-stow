#!/usr/bin/env python3
import argparse
import os
import subprocess
import sys

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


def menu_select(items, prompt=" Quickmarks:"):
    if IS_WAYLAND:
        cmd = ["rofi", "-dmenu", "-i", "-p", prompt]
    else:
        cmd = ["dmenu", "-p", prompt]
    result = subprocess.run(
        cmd, input="\n".join(items), capture_output=True, text=True
    )
    return result.stdout.strip() if result.returncode == 0 else None


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
