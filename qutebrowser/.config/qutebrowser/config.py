# pylint: disable=C0111
c = c  # noqa: F821 pylint: disable=E0602,C0103
config = config  # noqa: F821 pylint: disable=E0602,C0103

# --- Color Palette ---
palette = {
    "bg0": "#0f0f0f",  # Background
    "bg1": "#1a1a1a",  # Pills
    "bg2": "#2d2d2d",  # Pill BG
    "bg3": "#4c1111",  # Separators
    "fg0": "#f9e5c7",  # Main Text
    "fg1": "#e0e0e0",  # Silver
    "teal": "#3ec1d3",  # Teal (Storage/Memory)
    "red": "#ff4646",  # Red
    "purple": "#b45ef7",  # Purple (System Core)
    "gold": "#df9d1b",  # Gold (Power)
    "alert": "#ff003c",  # Alert Red
    "green": "#73f973",  # Green (Network)
    "orange": "#ffa500",  # Orange (Audio)
    "blue": "#3ec1d3",  # reuse teal as accent
}

# --- Apply Theme ---
c.tabs.width = "4%"

c.colors.tabs.bar.bg = "transparent"
c.colors.tabs.odd.bg = palette["bg1"] + "26"
c.colors.tabs.even.bg = palette["bg2"] + "26"

accent = palette["teal"]
c.colors.tabs.selected.odd.bg = accent + "99"
c.colors.tabs.selected.even.bg = accent + "99"
c.colors.tabs.selected.odd.fg = palette["fg0"]
c.colors.tabs.selected.even.fg = palette["fg0"]
c.colors.tabs.odd.fg = palette["fg1"]
c.colors.tabs.even.fg = palette["fg1"]

# --- Completion ---
c.colors.completion.category.bg = palette["bg2"]
c.colors.completion.category.fg = palette["fg0"]
c.colors.completion.even.bg = palette["bg0"]
c.colors.completion.odd.bg = palette["bg1"]
c.colors.completion.item.selected.bg = palette["teal"]
c.colors.completion.item.selected.fg = palette["fg0"]
c.colors.completion.item.selected.border.top = palette["teal"]
c.colors.completion.item.selected.border.bottom = palette["teal"]
c.colors.completion.match.fg = palette["orange"]
c.colors.completion.scrollbar.bg = palette["bg1"]
c.colors.completion.scrollbar.fg = palette["bg3"]

# --- Statusbar ---
c.colors.statusbar.normal.bg = palette["bg2"]
c.colors.statusbar.insert.bg = palette["green"]
c.colors.statusbar.passthrough.bg = palette["gold"]
c.colors.statusbar.private.bg = palette["purple"]
c.colors.statusbar.command.bg = palette["bg1"]
c.colors.statusbar.url.success.http.fg = palette["fg1"]
c.colors.statusbar.url.success.https.fg = palette["green"]
c.colors.statusbar.url.error.fg = palette["alert"]
c.colors.statusbar.url.warn.fg = palette["gold"]
c.colors.statusbar.url.hover.fg = palette["teal"]

# --- Hints ---
c.colors.hints.bg = palette["gold"]
c.colors.hints.fg = palette["bg0"]
c.colors.hints.match.fg = palette["red"]

# --- Messages ---
c.colors.messages.error.bg = palette["alert"]
c.colors.messages.warning.bg = palette["orange"]
c.colors.messages.info.bg = palette["teal"]

# --- Downloads ---
c.colors.downloads.bar.bg = palette["bg2"]
c.colors.downloads.start.bg = palette["teal"]
c.colors.downloads.stop.bg = palette["green"]
c.colors.downloads.error.bg = palette["alert"]

# --- Prompts ---
c.colors.prompts.bg = palette["bg1"]
c.colors.prompts.fg = palette["fg0"]
c.colors.prompts.border = f"1px solid {palette['teal']}"

# --- Base config ---
config.load_autoconfig(True)

c.aliases = {"q": "quit", "w": "session-save", "wq": "quit --save"}
c.editor.command = ["neovide", "{file}"]

# --- Dark mode ---
config.set("colors.webpage.darkmode.enabled", True)
c.colors.webpage.darkmode.algorithm = "lightness-cielab"
c.colors.webpage.darkmode.policy.images = "never"
config.set("colors.webpage.darkmode.enabled", False, "file://*")
config.set("colors.webpage.darkmode.enabled", True, "https://*.suckless.org/*")

# --- Content & privacy ---
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

# --- Adblock lists ---
c.content.blocking.method = "both"
c.content.blocking.adblock.lists = [
    "https://easylist.to/easylist/easylist.txt",
    "https://easylist.to/easylist/easyprivacy.txt",
    "https://easylist-downloads.adblockplus.org/easylistdutch.txt",
    "https://easylist-downloads.adblockplus.org/abp-filters-anti-cv.txt",
    "https://www.i-dont-care-about-cookies.eu/abp/",
    "https://secure.fanboy.co.nz/fanboy-cookiemonster.txt",
]

# Startpage
startpage = "http://127.0.0.1:8080"

# --- UI ---
c.downloads.location.directory = "~/Downloads"
c.tabs.position = "left"
c.tabs.show = "always"
c.statusbar.show = "in-mode"
c.url.default_page = startpage
c.url.start_pages = [startpage]
c.tabs.title.format = "{audio}{current_title}"

# --- Search engines ---
c.url.searchengines = {
    "DEFAULT": "https://search.brave.com/search?q={}",
}

c.completion.open_categories = []

# --- Tabs ---
c.window.transparent = True
c.tabs.indicator.width = 0
c.tabs.padding = {"top": 5, "bottom": 5, "left": 7, "right": 7}

# --- Fonts ---
c.fonts.default_family = '"SauceCodePro NF"'
c.fonts.default_size = "11pt"
c.fonts.completion.entry = '11pt "SauceCodePro NF"'
c.fonts.debug_console = '11pt "SauceCodePro NF"'
c.fonts.prompts = "default_size sans-serif"
c.fonts.statusbar = '11pt "SauceCodePro NF"'

# --- Keybindings ---

# Unbinds
config.unbind("O")
config.unbind("Sq")
config.unbind("gb")
config.unbind("M")
config.unbind("m")

# Rebinds
config.bind("o", "spawn --userscript search.py --browser qutebrowser")
config.bind("b", "spawn --userscript bookmarks.py --browser qutebrowser")
config.bind("q", "spawn --userscript quickmarks.py --browser qutebrowser")

# New binds
config.bind("cs", "config-source ;; message-info 'Config reloaded!'")
config.bind("ct", "config-cycle colors.webpage.darkmode.enabled true false")

config.bind("Pp", "spawn --userscript private.sh")
config.bind("Pm", "spawn --userscript mediampv.sh")
config.bind("z", "spawn --userscript password.sh")

config.bind("pg", "open")
config.bind("tP", "open -- {primary}")
config.bind("tp", "open -- {clipboard}")
config.bind("tc", "open -t -- {clipboard}")
config.bind("T", "hint links")
config.bind("th", "history")

config.bind("<", "back")
config.bind(">", "forward")

config.bind("P?", "config-cycle tabs.width 16% 4%")
config.bind("Pf", "fullscreen")
