# pylint: disable=C0111
c = c  # noqa: F821 pylint: disable=E0602,C0103
config = config  # noqa: F821 pylint: disable=E0602,C0103

# --- Color Palette ---
palette = {
    "bg0": "#282828",  # Background
    "bg1": "#3c3836",  # Pills
    "bg2": "#504945",  # Pill BG
    "bg3": "#665c54",  # Separators
    "fg0": "#ebdbb2",  # Main Text
    "fg1": "#a89984",  # Secondary text
    "teal": "#83a598",  # Aqua (Storage/Memory)
    "red": "#cc241d",  # Red
    "purple": "#b16286",  # Purple (System Core)
    "gold": "#d79921",  # Yellow (Power)
    "alert": "#fb4934",  # Bright Red
    "green": "#98971a",  # Green (Network)
    "orange": "#d65d0e",  # Orange (Audio)
    "blue": "#458588",  # Blue accent
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
c.editor.command = ["wezterm", "start", "nvim", "{file}"]

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
config.set("content.webgl", True, "*")
config.set("content.canvas_reading", True)
config.set("content.geolocation", False)
config.set("content.webrtc_ip_handling_policy", "default-public-interface-only")
config.set("content.cookies.accept", "all")
config.set("content.cookies.store", True)
config.set("content.javascript.clipboard", "access")

# --- Adblock lists ---
c.content.blocking.method = "both"
c.content.blocking.adblock.lists = [
    # Core
    "https://easylist.to/easylist/easylist.txt",
    "https://easylist.to/easylist/easyprivacy.txt",
    "https://easylist-downloads.adblockplus.org/easylistdutch.txt",
    "https://easylist-downloads.adblockplus.org/abp-filters-anti-cv.txt",
    "https://www.i-dont-care-about-cookies.eu/abp/",
    "https://secure.fanboy.co.nz/fanboy-cookiemonster.txt",
    # Annoyances (popups, overlays, newsletter prompts, chat widgets)
    "https://secure.fanboy.co.nz/fanboy-annoyance.txt",
    "https://easylist.to/easylist/fanboy-social.txt",
    "https://easylist-downloads.adblockplus.org/fanboy-notifications.txt",
    # Malware & Scam Protection
    "https://malware-filter.gitlab.io/malware-filter/urlhaus-filter-online.txt",
    "https://phishing.army/download/phishing_army_blocklist_extended.txt",
    "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareAdGuard.txt",
    # Additional Tracker & Privacy
    "https://raw.githubusercontent.com/disconnectme/disconnect-tracking-protection/master/services.json",
    "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt",
    # uBlock Origin filter lists (widely trusted)
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/privacy.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/badware.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/annoyances.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/resource-abuse.txt",
]

# User Agent
c.content.headers.user_agent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"

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
