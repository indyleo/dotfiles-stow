# pylint: disable=C0111
c = c  # noqa: F821 pylint: disable=E0602,C0103
config = config  # noqa: F821 pylint: disable=E0602,C0103
# pylint settings included to disable linting errors

# load settings from config.py
config.load_autoconfig(True)

# Aliases for commands.
c.aliases = {"q": "quit", "w": "session-save", "wq": "quit --save"}

# Setting dark mode
config.set("colors.webpage.darkmode.enabled", True)
c.colors.webpage.darkmode.algorithm = "lightness-cielab"
c.colors.webpage.darkmode.policy.images = "never"
config.set("colors.webpage.darkmode.enabled", False, "file://*")
config.set("colors.webpage.darkmode.enabled", True, "https://*.suckless.org/*")

# Default editor to use
c.editor.command = ["neovide", "{file}"]

# User agent to send.  The following placeholders are defined:  *
# `{os_info}`: Something like "X11; Linux x86_64". * `{webkit_version}`:
# The underlying WebKit version (set to a fixed value   with
# QtWebEngine). * `{qt_key}`: "Qt" for QtWebKit, "QtWebEngine" for
# QtWebEngine. * `{qt_version}`: The underlying Qt version. *
# `{upstream_browser_key}`: "Version" for QtWebKit, "Chrome" for
# QtWebEngine. * `{upstream_browser_version}`: The corresponding
# Safari/Chrome version. * `{qutebrowser_version}`: The currently
# running qutebrowser version.  The default value is equal to the
# unchanged user agent of QtWebKit/QtWebEngine.  Note that the value
# read from JavaScript is always the global value. With QtWebEngine
# between 5.12 and 5.14 (inclusive), changing the value exposed to
# JavaScript requires a restart.
# Type: FormatString
config.set(
    "content.headers.user_agent",
    "Mozilla/5.0 ({os_info}) AppleWebKit/{webkit_version} (KHTML, like Gecko) {upstream_browser_key}/{upstream_browser_version} Safari/{webkit_version}",
    "https://web.whatsapp.com/",
)

# User agent to send.  The following placeholders are defined:  *
# `{os_info}`: Something like "X11; Linux x86_64". * `{webkit_version}`:
# The underlying WebKit version (set to a fixed value   with
# QtWebEngine). * `{qt_key}`: "Qt" for QtWebKit, "QtWebEngine" for
# QtWebEngine. * `{qt_version}`: The underlying Qt version. *
# `{upstream_browser_key}`: "Version" for QtWebKit, "Chrome" for
# QtWebEngine. * `{upstream_browser_version}`: The corresponding
# Safari/Chrome version. * `{qutebrowser_version}`: The currently
# running qutebrowser version.  The default value is equal to the
# unchanged user agent of QtWebKit/QtWebEngine.  Note that the value
# read from JavaScript is always the global value. With QtWebEngine
# between 5.12 and 5.14 (inclusive), changing the value exposed to
# JavaScript requires a restart.
# Type: FormatString
config.set(
    "content.headers.user_agent",
    "Mozilla/5.0 ({os_info}; rv:71.0) Gecko/20100101 Firefox/71.0",
    "https://accounts.google.com/*",
)

# User agent to send.  The following placeholders are defined:  *
# `{os_info}`: Something like "X11; Linux x86_64". * `{webkit_version}`:
# The underlying WebKit version (set to a fixed value   with
# QtWebEngine). * `{qt_key}`: "Qt" for QtWebKit, "QtWebEngine" for
# QtWebEngine. * `{qt_version}`: The underlying Qt version. *
# `{upstream_browser_key}`: "Version" for QtWebKit, "Chrome" for
# QtWebEngine. * `{upstream_browser_version}`: The corresponding
# Safari/Chrome version. * `{qutebrowser_version}`: The currently
# running qutebrowser version.  The default value is equal to the
# unchanged user agent of QtWebKit/QtWebEngine.  Note that the value
# read from JavaScript is always the global value. With QtWebEngine
# between 5.12 and 5.14 (inclusive), changing the value exposed to
# JavaScript requires a restart.
# Type: FormatString
config.set(
    "content.headers.user_agent",
    "Mozilla/5.0 ({os_info}) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99 Safari/537.36",
    "https://*.slack.com/*",
)

# User agent to send.  The following placeholders are defined:  *
# `{os_info}`: Something like "X11; Linux x86_64". * `{webkit_version}`:
# The underlying WebKit version (set to a fixed value   with
# QtWebEngine). * `{qt_key}`: "Qt" for QtWebKit, "QtWebEngine" for
# QtWebEngine. * `{qt_version}`: The underlying Qt version. *
# `{upstream_browser_key}`: "Version" for QtWebKit, "Chrome" for
# QtWebEngine. * `{upstream_browser_version}`: The corresponding
# Safari/Chrome version. * `{qutebrowser_version}`: The currently
# running qutebrowser version.  The default value is equal to the
# unchanged user agent of QtWebKit/QtWebEngine.  Note that the value
# read from JavaScript is always the global value. With QtWebEngine
# between 5.12 and 5.14 (inclusive), changing the value exposed to
# JavaScript requires a restart.
# Type: FormatString
config.set(
    "content.headers.user_agent",
    "Mozilla/5.0 ({os_info}; rv:71.0) Gecko/20100101 Firefox/71.0",
    "https://docs.google.com/*",
)

# User agent to send.  The following placeholders are defined:  *
# `{os_info}`: Something like "X11; Linux x86_64". * `{webkit_version}`:
# The underlying WebKit version (set to a fixed value   with
# QtWebEngine). * `{qt_key}`: "Qt" for QtWebKit, "QtWebEngine" for
# QtWebEngine. * `{qt_version}`: The underlying Qt version. *
# `{upstream_browser_key}`: "Version" for QtWebKit, "Chrome" for
# QtWebEngine. * `{upstream_browser_version}`: The corresponding
# Safari/Chrome version. * `{qutebrowser_version}`: The currently
# running qutebrowser version.  The default value is equal to the
# unchanged user agent of QtWebKit/QtWebEngine.  Note that the value
# read from JavaScript is always the global value. With QtWebEngine
# between 5.12 and 5.14 (inclusive), changing the value exposed to
# JavaScript requires a restart.
# Type: FormatString
config.set(
    "content.headers.user_agent",
    "Mozilla/5.0 ({os_info}; rv:71.0) Gecko/20100101 Firefox/71.0",
    "https://drive.google.com/*",
)

# Web security/privacy settings.
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

# Adblocking
c.content.blocking.method = "both"
c.content.blocking.adblock.lists = [
    "https://easylist.to/easylist/easylist.txt",
    "https://easylist.to/easylist/easyprivacy.txt",
    "https://easylist-downloads.adblockplus.org/easylistdutch.txt",
    "https://easylist-downloads.adblockplus.org/abp-filters-anti-cv.txt",
    "https://www.i-dont-care-about-cookies.eu/abp/",
    "https://secure.fanboy.co.nz/fanboy-cookiemonster.txt",
]

# Directory to save downloads to.
c.downloads.location.directory = "~/Downloads"

# When to show the tab bar.
# Type: String
# Valid values:
#   - always: Always show the tab bar.
#   - never: Always hide the tab bar.
#   - multiple: Hide the tab bar if only one tab is open.
#   - switching: Show the tab bar when switching tabs.
c.tabs.position = "left"
c.tabs.show = "always"

# When to show the statusbar.
# Type: String
# Valid values:
#   - always: Always show the statusbar.
#   - never: Always hide the statusbar.
#   - in-mode: Show the statusbar when in modes other than normal mode.
c.statusbar.show = "in-mode"

# Setting default page for when opening new tabs or new windows with
# commands like :open -t and :open -w .
c.url.default_page = "file:///home/indy/Github/portfilio/startpage/index.html"
c.url.start_pages = "file:///home/indy/Github/portfilio/startpage/index.html"

# Title of new tabs
# Type: FormatString
c.tabs.title.format = "{audio}{current_title}"

# Search engines which can be used via the address bar.  Maps a search
# engine name (such as `DEFAULT`, or `ddg`) to a URL with a `{}`
# placeholder. The placeholder will be replaced by the search term, use
# `{{` and `}}` for literal `{`/`}` braces.  The following further
# placeholds are defined to configure how special characters in the
# search terms are replaced by safe characters (called 'quoting'):  *
# `{}` and `{semiquoted}` quote everything except slashes; this is the
# most   sensible choice for almost all search engines (for the search
# term   `slash/and&amp` this placeholder expands to `slash/and%26amp`).
# * `{quoted}` quotes all characters (for `slash/and&amp` this
# placeholder   expands to `slash%2Fand%26amp`). * `{unquoted}` quotes
# nothing (for `slash/and&amp` this placeholder   expands to
# `slash/and&amp`).  The search engine named `DEFAULT` is used when
# `url.auto_search` is turned on and something else than a URL was
# entered to be opened. Other search engines can be used by prepending
# the search engine name to the search term, e.g. `:open google
# qutebrowser`.
# Type: Dict
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

# Completion Categories
c.completion.open_categories = [
    "searchengines",
    "quickmarks",
    "bookmarks",
    "history",
    "filesystem",
]

# Nord Theme Colors
nord = {
    "polar_night0": "#2e3440",
    "polar_night1": "#3b4252",
    "polar_night2": "#434c5e",
    "polar_night3": "#4c566a",
    "snow_storm0": "#d8dee9",
    "snow_storm1": "#e5e9f0",
    "snow_storm2": "#eceff4",
    "frost0": "#8fbcbb",
    "frost1": "#88c0d0",
    "frost2": "#81a1c1",
    "frost3": "#5e81ac",
    "red": "#bf616a",
    "orange": "#d08770",
    "yellow": "#ebcb8b",
    "green": "#a3be8c",
    "purple": "#b48ead",
}

tabs = {
    "polar_night1": "#3b425226",
    "polar_night2": "#434c5e26",
    "polar_night3": "#4c566a26",
}

# styles, cosmetics
c.tabs.padding = {"top": 5, "bottom": 5, "left": 5, "right": 5}
c.tabs.indicator.width = 0  # no tab indicators
c.tabs.width = "5%"
c.window.transparent = True

# Base
c.colors.completion.category.bg = nord["polar_night1"]
c.colors.completion.category.fg = nord["snow_storm1"]
c.colors.completion.even.bg = nord["polar_night0"]
c.colors.completion.odd.bg = nord["polar_night1"]
c.colors.completion.item.selected.bg = nord["frost3"]
c.colors.completion.item.selected.fg = nord["snow_storm2"]
c.colors.completion.item.selected.border.top = nord["frost3"]
c.colors.completion.item.selected.border.bottom = nord["frost3"]
c.colors.completion.match.fg = nord["orange"]

# Statusbar
c.colors.statusbar.normal.bg = nord["polar_night2"]
c.colors.statusbar.insert.bg = nord["green"]
c.colors.statusbar.passthrough.bg = nord["yellow"]
c.colors.statusbar.private.bg = nord["purple"]
c.colors.statusbar.command.bg = nord["polar_night1"]
c.colors.statusbar.url.success.http.fg = nord["snow_storm0"]
c.colors.statusbar.url.success.https.fg = nord["green"]
c.colors.statusbar.url.error.fg = nord["red"]
c.colors.statusbar.url.warn.fg = nord["yellow"]
c.colors.statusbar.url.hover.fg = nord["frost1"]

# Tabs
c.colors.tabs.bar.bg = tabs["polar_night1"]
c.colors.tabs.odd.bg = tabs["polar_night2"]
c.colors.tabs.even.bg = tabs["polar_night3"]
c.colors.tabs.selected.odd.bg = nord["frost3"]
c.colors.tabs.selected.even.bg = nord["frost3"]
c.colors.tabs.selected.odd.fg = nord["snow_storm2"]
c.colors.tabs.selected.even.fg = nord["snow_storm2"]
c.colors.tabs.odd.fg = nord["snow_storm0"]
c.colors.tabs.even.fg = nord["snow_storm0"]

# Hints
c.colors.hints.bg = nord["yellow"]
c.colors.hints.fg = nord["polar_night0"]
c.colors.hints.match.fg = nord["red"]

# Messages (errors, warnings)
c.colors.messages.error.bg = nord["red"]
c.colors.messages.warning.bg = nord["orange"]
c.colors.messages.info.bg = nord["frost2"]

# Downloads
c.colors.downloads.bar.bg = nord["polar_night2"]
c.colors.downloads.start.bg = nord["frost2"]
c.colors.downloads.stop.bg = nord["green"]
c.colors.downloads.error.bg = nord["red"]

# Prompts
c.colors.prompts.bg = nord["polar_night1"]
c.colors.prompts.fg = nord["snow_storm0"]
c.colors.prompts.border = f"1px solid {nord['frost2']}"

# Completion scrollbar
c.colors.completion.scrollbar.bg = nord["polar_night1"]
c.colors.completion.scrollbar.fg = nord["polar_night3"]

# Default font families to use. Whenever "default_family" is used in a
# empty value, a system-specific monospace default is used.
# Type: List of Font, or Font
c.fonts.default_family = '"SauceCodePro NF"'

# Default font size to use. Whenever "default_size" is used in a font
# setting, it's replaced with the size listed here. Valid values are
# either a float value with a "pt" suffix, or an integer value with a
# "px" suffix.
# Type: String
c.fonts.default_size = "11pt"

# Font used in the completion widget.
# Type: Font
c.fonts.completion.entry = '11pt "SauceCodePro NF"'

# Font used for the debugging console.
# Type: Font
c.fonts.debug_console = '11pt "SauceCodePro NF"'

# Font used for prompts.
# Type: Font
c.fonts.prompts = "default_size sans-serif"

# Font used in the statusbar.
# Type: Font
c.fonts.statusbar = '11pt "SauceCodePro NF"'

# Bindings for normal mode
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
