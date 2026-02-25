#!/usr/bin/env python3
"""Convert a Netscape HTML bookmark file to qutebrowser's urls format."""

import sys
from html.parser import HTMLParser


class BookmarkParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.bookmarks = []
        self._href = None
        self._title = ""
        self._in_a = False

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            self._in_a = True
            self._href = dict(attrs).get("href", "")
            self._title = ""

    def handle_endtag(self, tag):
        if tag == "a" and self._in_a:
            if self._href and self._href.startswith("http"):
                self.bookmarks.append((self._href, self._title.strip()))
            self._in_a = False

    def handle_data(self, data):
        if self._in_a:
            self._title += data


with open(sys.argv[1], "r", encoding="utf-8", errors="replace") as f:
    html = f.read()

p = BookmarkParser()
p.feed(html)

out = "~/.config/qutebrowser/bookmarks/urls"
import os

out = os.path.expanduser(out)
with open(out, "w", encoding="utf-8") as f:
    for url, title in p.bookmarks:
        f.write(f"{url} {title}\n")

print(f"Wrote {len(p.bookmarks)} bookmarks to {out}")
