#!/usr/bin/env python3
"""
Quick diagnostic for websearch.py completion endpoints.
Run this on your machine: python3 test_completions.py [query]
"""

import json
import sys
import time
import urllib.parse
import urllib.request

TIMEOUT = 5  # generous for testing
query = sys.argv[1] if len(sys.argv) > 1 else "python"

ENDPOINTS = {
    "DuckDuckGo": f"https://duckduckgo.com/ac/?q={urllib.parse.quote_plus(query)}&type=list",
    "Google": f"https://suggestqueries.google.com/complete/search?client=firefox&q={urllib.parse.quote_plus(query)}",
}

print(f"Testing completions for: {query!r}\n")

for name, url in ENDPOINTS.items():
    print(f"── {name}")
    print(f"   URL: {url}")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        t = time.time()
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            elapsed = time.time() - t
            raw = resp.read().decode()
            data = json.loads(raw)
            suggestions = data[1] if isinstance(data, list) and len(data) > 1 else []
            print(f"   OK  ({elapsed:.2f}s)")
            print(f"   Suggestions: {suggestions[:6]}")
    except TimeoutError:
        print(f"   FAIL: timed out after {TIMEOUT}s")
    except Exception as e:  # pylint: disable=broad-exception-caught
        print(f"   FAIL: {e}")
    print()
