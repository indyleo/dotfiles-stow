#!/usr/bin/env python3
import argparse
import os
import subprocess
import sys

# Path to your bookmarks file
QUICKMARKS_FILE = os.path.expanduser("~/.local/share/bookmarks/quickmarks.txt")


def load_quickmarks(filepath):
    """Parses the text file into a dictionary."""
    marks = {}
    if not os.path.exists(filepath):
        # Create an empty file if it doesn't exist so the script doesn't crash
        os.makedirs(os.path.dirname(filepath), exist_ok=True)
        open(filepath, "a").close()
        return marks

    with open(filepath, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue

            # Split by whitespace: [keyword, url]
            parts = line.split(maxsplit=1)
            if len(parts) == 2:
                marks[parts[0]] = parts[1]
    return marks


def rofi_select(items, prompt=" Quickmarks:"):
    result = subprocess.run(
        ["rofi", "-dmenu", "-i", "-p", prompt],
        input="\n".join(items),
        capture_output=True,
        text=True,
    )
    return result.stdout.strip() if result.returncode == 0 else None


def open_url(url, browser):
    subprocess.Popen(
        [browser, url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )


def main():
    parser = argparse.ArgumentParser(description="Rofi quickmarks launcher.")
    parser.add_argument(
        "--browser", default="xdg-open", help="Browser command (default: xdg-open)"
    )
    parser.add_argument(
        "--file", default=QUICKMARKS_FILE, help="Path to bookmarks text file"
    )
    args = parser.parse_args()

    quickmarks = load_quickmarks(args.file)

    if not quickmarks:
        print(f"No bookmarks found in {args.file}")
        sys.exit(1)

    # UI Formatting: Aligning the URLs
    width = max(len(k) for k in quickmarks)
    entries = [f"{k:<{width}}  {v}" for k, v in quickmarks.items()]

    choice = rofi_select(entries)
    if choice:
        keyword = choice.split()[0]
        url = quickmarks.get(keyword)
        if url:
            open_url(url, args.browser)


if __name__ == "__main__":
    main()
