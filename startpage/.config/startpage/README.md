# Startpage

A minimalistic, keyboard-driven browser startpage with a Gruvbox theme, a
SearXNG search bar, quicklinks, live system/weather info, and a bit of
matrix-rain flavor. Single `index.html`, no build step, no dependencies.

## Features

- **Search bar** backed by a SearXNG instance, with `!bang` shortcuts to jump
  straight to a specific site (see below).
- **Vim-style link hints** — press `f` to overlay a letter on every quicklink
  and jump straight to it from the keyboard, Vimium-style.
- **Quicklinks** grouped into categories (Work / Media / Tools / Projects by
  default) with favicons.
- **Live system info bar**: OS, browser (including Brave detection), distro
  label, current weather, round-trip ping, session uptime, and battery level
  (where supported) — all in a fixed glass panel.
- **Click-to-expand 3-day weather forecast** — click the weather item in the
  system info bar for a short forecast popover.
- **Typed greeting** with a random rotating quote/phrase pulled from
  `quotes.txt` / `randomphrases.txt`, holiday-aware (including a
  dynamically-calculated Easter date), with a fallback pool if those files
  fail to load.
- **Matrix rain background**, paused automatically while the tab is hidden,
  and its animation state is persisted across reloads.
- **Keybind cheatsheet overlay** (`?`) listing shortcuts and the active bang
  list.

## Keybinds

| Key   | Action                                                   |
| ----- | -------------------------------------------------------- |
| `/`   | Focus the search bar                                     |
| `f`   | Jump to a link (hold `Shift` + key to open in a new tab) |
| `n`   | Reroll the greeting quote/phrase                         |
| `?`   | Toggle the keybind cheatsheet                            |
| `Esc` | Close overlay / forecast / clear search / exit hint mode |

While in hint mode (`f`), `Backspace` corrects a mistyped hint letter without
resetting the whole mode.

## Search bangs

Type `!bang query` in the search bar to skip SearXNG and go straight to that
site's search (or just `!bang` with no query for the homepage). Current bangs:
`!gh` GitHub, `!gl` GitLab, `!so` Stack Overflow, `!yt` YouTube, `!tw` Twitch,
`!rd` Reddit, `!g` Google, `!ddg` DuckDuckGo, `!w` Wikipedia, `!npm` npm,
`!pypi` PyPI, `!aw` Arch Wiki. The full list is also always visible in the
`?` overlay, generated from the same `BANG_MAP` in the script.

## Customizing

This is a single self-contained `index.html`, so everything is edited in
place — there's no build step.

- **Quicklinks**: edit the `.category` blocks inside `.quicklinks-box`. Icons
  are looked up at `favicons/<name>.ico` (or `.svg`); missing icons fail
  silently (`onerror` hides the broken `<img>`), so you don't need a full
  set to get started — a `favicons/` folder just isn't included in this repo.
- **Quotes / phrases**: edit `quotes.txt` and `randomphrases.txt`, one entry
  per line.
- **Search backend**: this defaults to a personal SearXNG instance
  (`searxng.linuxlab.work`). To point it at your own instance (or another
  search engine entirely), update all three of:
  1. the `<form action="...">` URL in the search bar,
  2. `form-action` in the `Content-Security-Policy` `<meta>` tag,
  3. any `connect-src` entries that reference it.
- **Bangs**: add entries to the `BANG_MAP` object in the script — each needs
  a `base` (homepage), `search` (search URL prefix), and `label`.
- **Theme**: colors are all CSS custom properties under `:root` in the
  `<style>` block (Gruvbox Dark Hard by default).
- **CSP**: if you add any new external requests (a different weather API,
  ping targets, etc.), remember to add the domain to `connect-src` in the
  `Content-Security-Policy` meta tag or the request will be blocked.

## Files

| File                     | Purpose                                      |
| ------------------------ | -------------------------------------------- |
| `index.html`             | Everything — markup, styles, and script      |
| `quotes.txt`             | Pool of quotes shown under the greeting      |
| `randomphrases.txt`      | Pool of short phrases used in the greeting   |
| `starticon.png`          | Favicon                                      |
| `here-comes-the-sun.mp3` | Easter-egg audio (plays on a specific quote) |
