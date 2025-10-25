# pylint: disable=C0111
c = c  # noqa: F821 pylint: disable=E0602,C0103
config = config  # noqa: F821 pylint: disable=E0602,C0103

import os

# load settings from config.py
config.load_autoconfig(True)

# --- Determine theme ---
theme_file = os.path.expanduser("~/.cache/theme")

try:
    with open(theme_file, "r") as f:
        theme_name = f.read().strip().lower()
except FileNotFoundError:
    theme_name = "gruvbox"

if theme_name not in ["gruvbox", "nord"]:
    theme_name = "gruvbox"

# --- Common settings ---
c.aliases = {"q": "quit", "w": "session-save", "wq": "quit --save"}

# Default editor
c.editor.command = ["neovide", "{file}"]

# Dark mode settings
config.set("colors.webpage.darkmode.enabled", True)
c.colors.webpage.darkmode.algorithm = "lightness-cielab"
c.colors.webpage.darkmode.policy.images = "never"
config.set("colors.webpage.darkmode.enabled", False, "file://*")
config.set("colors.webpage.darkmode.enabled", True, "https://*.suckless.org/*")

# User agents
config.set(
    "content.headers.user_agent",
    "Mozilla/5.0 ({os_info}) AppleWebKit/{webkit_version} (KHTML, like Gecko) "
    "{upstream_browser_key}/{upstream_browser_version} Safari/{webkit_version}",
    "https://web.whatsapp.com/",
)
config.set(
    "content.headers.user_agent",
    "Mozilla/5.0 ({os_info}; rv:71.0) Gecko/20100101 Firefox/71.0",
    "https://accounts.google.com/*",
)
config.set(
    "content.headers.user_agent",
    "Mozilla/5.0 ({os_info}) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99 Safari/537.36",
    "https://*.slack.com/*",
)
config.set(
    "content.headers.user_agent",
    "Mozilla/5.0 ({os_info}; rv:71.0) Gecko/20100101 Firefox/71.0",
    "https://docs.google.com/*",
)
config.set(
    "content.headers.user_agent",
    "Mozilla/5.0 ({os_info}; rv:71.0) Gecko/20100101 Firefox/71.0",
    "https://drive.google.com/*",
)

# Privacy / Web settings
config.set("content.images", True, "*")
config.set("content.javascript.enabled", True, "*")
config.set("content.notifications.enabled", False)
config.set("content.webgl", False, "*")
config.set("content.canvas_reading", True)
config.set("content.geolocation", False)
config.set("content.webrtc_ip_handling_policy", "default-public-interface-only")
config.set("content.cookies.accept", "all")
config.set("content.cookies.store", True)
config.set("content.javascript.clipboard", "access")

# Adblock settings
c.content.blocking.method = "both"
c.content.blocking.adblock.lists = [
    "https://easylist.to/easylist/easylist.txt",
    "https://easylist.to/easylist/easyprivacy.txt",
    "https://easylist-downloads.adblockplus.org/easylistdutch.txt",
    "https://easylist-downloads.adblockplus.org/abp-filters-anti-cv.txt",
    "https://www.i-dont-care-about-cookies.eu/abp/",
    "https://secure.fanboy.co.nz/fanboy-cookiemonster.txt",
]

# UI behavior
c.downloads.location.directory = "~/Downloads"
c.tabs.position = "left"
c.tabs.show = "always"
c.statusbar.show = "in-mode"
c.url.default_page = "file:///home/indy/Github/portfilio/startpage/index.html"
c.url.start_pages = "file:///home/indy/Github/portfilio/startpage/index.html"
c.tabs.title.format = "{audio}{current_title}"

# Search engines
c.url.searchengines = {
    "DEFAULT": "https://searxng.linuxlab.work/search?q={}",
    "!ar": "https://aur.archlinux.org/packages?O=0&K={}",
    "!ah": "https://archlinux.org/packages/?sort=&q={}",
    "!aw": "https://wiki.archlinux.org/?search={}",
    "!dp": "https://packages.debian.org/search?keywords={}&searchon=names&suite=testing&section=all",
    "!fh": "https://flathub.org/apps/search?q={}",
    "!np": "https://search.nixos.org/packages?channel=24.11&from=0&size=50&sort=relevance&type=packages&query={}",
    "!pd": "https://www.protondb.com/search?q={}",
    "!yt": "https://www.youtube.com/search?q={}",
}

# Completion categories
c.completion.open_categories = [
    "searchengines",
    "quickmarks",
    "bookmarks",
    "history",
    "filesystem",
]

# --- THEMES ---

if theme_name == "nord":
    palette = {
        "bg0": "#2e3440",
        "bg1": "#3b4252",
        "bg2": "#434c5e",
        "bg3": "#4c566a",
        "fg0": "#d8dee9",
        "fg1": "#e5e9f0",
        "fg2": "#eceff4",
        "blue": "#5e81ac",
        "cyan": "#88c0d0",
        "green": "#a3be8c",
        "yellow": "#ebcb8b",
        "orange": "#d08770",
        "red": "#bf616a",
        "purple": "#b48ead",
    }
else:  # default Gruvbox
    palette = {
        "bg0": "#1d2021",
        "bg1": "#282828",
        "bg2": "#3c3836",
        "bg3": "#504945",
        "fg0": "#fbf1c7",
        "fg1": "#ebdbb2",
        "fg2": "#d5c4a1",
        "red": "#fb4934",
        "green": "#b8bb26",
        "yellow": "#fabd2f",
        "blue": "#83a598",
        "purple": "#d3869b",
        "aqua": "#8ec07c",
        "orange": "#fe8019",
    }

# --- UI COLORS ---
c.window.transparent = True
c.tabs.indicator.width = 0
c.tabs.padding = {"top": 5, "bottom": 5, "left": 7, "right": 7}
c.tabs.width = "4%" if theme_name == "gruvbox" else "5%"

# Completion
c.colors.completion.category.bg = palette["bg2"]
c.colors.completion.category.fg = palette["fg1"]
c.colors.completion.even.bg = palette["bg0"]
c.colors.completion.odd.bg = palette["bg1"]
c.colors.completion.item.selected.bg = palette["blue"]
c.colors.completion.item.selected.fg = palette["fg2"]
c.colors.completion.item.selected.border.top = palette["blue"]
c.colors.completion.item.selected.border.bottom = palette["blue"]
c.colors.completion.match.fg = palette.get("orange", palette["yellow"])

# Statusbar
c.colors.statusbar.normal.bg = palette["bg2"]
c.colors.statusbar.insert.bg = palette["green"]
c.colors.statusbar.passthrough.bg = palette["yellow"]
c.colors.statusbar.private.bg = palette["purple"]
c.colors.statusbar.command.bg = palette["bg1"]
c.colors.statusbar.url.success.http.fg = palette["fg1"]
c.colors.statusbar.url.success.https.fg = palette["green"]
c.colors.statusbar.url.error.fg = palette["red"]
c.colors.statusbar.url.warn.fg = palette["yellow"]
c.colors.statusbar.url.hover.fg = palette["blue"]

# Tabs
c.colors.tabs.bar.bg = palette["bg1"]
c.colors.tabs.odd.bg = palette["bg2"]
c.colors.tabs.even.bg = palette["bg3"]
c.colors.tabs.selected.odd.bg = palette["blue"]
c.colors.tabs.selected.even.bg = palette["blue"]
c.colors.tabs.selected.odd.fg = palette["fg0"]
c.colors.tabs.selected.even.fg = palette["fg0"]
c.colors.tabs.odd.fg = palette["fg1"]
c.colors.tabs.even.fg = palette["fg1"]

# Hints
c.colors.hints.bg = palette["yellow"]
c.colors.hints.fg = palette["bg0"]
c.colors.hints.match.fg = palette["red"]

# Messages
c.colors.messages.error.bg = palette["red"]
c.colors.messages.warning.bg = palette.get("orange", palette["yellow"])
c.colors.messages.info.bg = palette["blue"]

# Downloads
c.colors.downloads.bar.bg = palette["bg2"]
c.colors.downloads.start.bg = palette["blue"]
c.colors.downloads.stop.bg = palette["green"]
c.colors.downloads.error.bg = palette["red"]

# Prompts
c.colors.prompts.bg = palette["bg1"]
c.colors.prompts.fg = palette["fg1"]
c.colors.prompts.border = f"1px solid {palette['blue']}"

# Completion scrollbar
c.colors.completion.scrollbar.bg = palette["bg1"]
c.colors.completion.scrollbar.fg = palette["bg3"]

# Fonts
c.fonts.default_family = '"SauceCodePro NF"'
c.fonts.default_size = "11pt"
c.fonts.completion.entry = '11pt "SauceCodePro NF"'
c.fonts.debug_console = '11pt "SauceCodePro NF"'
c.fonts.prompts = "default_size sans-serif"
c.fonts.statusbar = '11pt "SauceCodePro NF"'

# --- Keybindings ---
config.bind("cs", "config-source")
config.bind("Px", "hint links spawn --detach mpv --fs {hint-url}")
config.bind("Pt", "hint links spawn --detach ytdl {hint-url} bth")
config.bind("Py", "hint links spawn --detach ytdl {hint-url} vid")
config.bind("Pa", "hint links spawn --detach ytdl {hint-url} aud")
config.bind("Pm", "mode-enter insert ;; spawn --detach dmenu_pass")
config.bind("Pb", "spawn --detach dmenu_bm qutebrowser")
config.bind("T", "hint links")
config.bind("tt", "cmd-set-text -s :open -t")
config.bind("tw", "cmd-set-text -s :open -w")
config.bind("tP", "open -- {primary}")
config.bind("tp", "open -- {clipboard}")
config.bind("tc", "open -t -- {clipboard}")
config.bind("th", "history")
config.bind("<", "back")
config.bind(">", "forward")
config.bind("P?", "config-cycle tabs.width 12% 4%")
config.bind("P/", "config-cycle colors.webpage.darkmode.enabled true false")
config.bind("Pf", "fullscreen")
config.bind("PP", "spawn --detach qutebrowser_private")
