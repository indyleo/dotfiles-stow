# pylint: disable=C0111
c = c  # noqa: F821 pylint: disable=E0602,C0103
config = config  # noqa: F821 pylint: disable=E0602,C0103

import os

# Load settings from config.py
config.load_autoconfig(True)

# -------------------------------
# Theme selection from cache
# -------------------------------
cache_home = os.getenv("XDG_CACHE_HOME") or os.path.expanduser("~/.cache")
theme_file = os.path.join(cache_home, "theme")


def read_theme(path):
    try:
        with open(path, "r") as f:
            return f.readline().strip()
    except FileNotFoundError:
        return None


theme_current = read_theme(theme_file) or "gruvbox"

# -------------------------------
# Theme definitions
# -------------------------------
themes = {
    "gruvbox": {
        "colors": {
            "dark0": "#1d2021",
            "dark1": "#282828",
            "dark2": "#3c3836",
            "dark3": "#504945",
            "light0": "#fbf1c7",
            "light1": "#ebdbb2",
            "bright_red": "#fb4934",
            "bright_green": "#b8bb26",
            "bright_yellow": "#fabd2f",
            "bright_blue": "#83a598",
            "bright_purple": "#d3869b",
            "bright_aqua": "#8ec07c",
            "bright_orange": "#fe8019",
        },
        "tabs": {
            "dark1": "#28282826",
            "dark2": "#3c383626",
            "dark3": "#50494526",
        },
    },
    "nord": {
        "colors": {
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
        },
        "tabs": {
            "polar_night1": "#3b425226",
            "polar_night2": "#434c5e26",
            "polar_night3": "#4c566a26",
        },
    },
}

# Pick the theme
theme = themes.get(theme_current, themes["gruvbox"])
colors = theme["colors"]
tabs_colors = theme["tabs"]

# -------------------------------
# Apply theme to qutebrowser
# -------------------------------

# Tabs
c.tabs.padding = {"top": 5, "bottom": 5, "left": 9, "right": 9}
c.tabs.indicator.width = 0
c.tabs.width = "4%"
c.window.transparent = True
c.colors.tabs.bar.bg = tabs_colors.get("dark1", tabs_colors.get("polar_night1"))
c.colors.tabs.odd.bg = tabs_colors.get("dark2", tabs_colors.get("polar_night2"))
c.colors.tabs.even.bg = tabs_colors.get("dark3", tabs_colors.get("polar_night3"))
c.colors.tabs.selected.odd.bg = colors.get("bright_blue", colors.get("frost3"))
c.colors.tabs.selected.even.bg = colors.get("bright_blue", colors.get("frost3"))
c.colors.tabs.selected.odd.fg = colors.get("light0", colors.get("snow_storm2"))
c.colors.tabs.selected.even.fg = colors.get("light0", colors.get("snow_storm2"))
c.colors.tabs.odd.fg = colors.get("light1", colors.get("snow_storm0"))
c.colors.tabs.even.fg = colors.get("light1", colors.get("snow_storm0"))

# Statusbar
c.colors.statusbar.normal.bg = colors.get("dark2", colors.get("polar_night2"))
c.colors.statusbar.insert.bg = colors.get("bright_green", colors.get("green"))
c.colors.statusbar.passthrough.bg = colors.get("bright_yellow", colors.get("yellow"))
c.colors.statusbar.private.bg = colors.get("bright_purple", colors.get("purple"))
c.colors.statusbar.command.bg = colors.get("dark1", colors.get("polar_night1"))
c.colors.statusbar.url.success.http.fg = colors.get("light1", colors.get("snow_storm0"))
c.colors.statusbar.url.success.https.fg = colors.get(
    "bright_green", colors.get("green")
)
c.colors.statusbar.url.error.fg = colors.get("bright_red", colors.get("red"))
c.colors.statusbar.url.warn.fg = colors.get("bright_yellow", colors.get("yellow"))
c.colors.statusbar.url.hover.fg = colors.get("bright_blue", colors.get("frost1"))

# Completion
c.colors.completion.category.bg = colors.get("dark2", colors.get("polar_night1"))
c.colors.completion.category.fg = colors.get("light1", colors.get("snow_storm1"))
c.colors.completion.even.bg = colors.get("dark0", colors.get("polar_night0"))
c.colors.completion.odd.bg = colors.get("dark1", colors.get("polar_night1"))
c.colors.completion.item.selected.bg = colors.get("bright_blue", colors.get("frost3"))
c.colors.completion.item.selected.fg = colors.get("light0", colors.get("snow_storm2"))
c.colors.completion.item.selected.border.top = colors.get(
    "bright_blue", colors.get("frost3")
)
c.colors.completion.item.selected.border.bottom = colors.get(
    "bright_blue", colors.get("frost3")
)
c.colors.completion.match.fg = colors.get("bright_orange", colors.get("orange"))

# Hints
c.colors.hints.bg = colors.get("bright_yellow", colors.get("yellow"))
c.colors.hints.fg = colors.get("dark0", colors.get("polar_night0"))
c.colors.hints.match.fg = colors.get("bright_red", colors.get("red"))

# Messages
c.colors.messages.error.bg = colors.get("bright_red", colors.get("red"))
c.colors.messages.warning.bg = colors.get("bright_orange", colors.get("orange"))
c.colors.messages.info.bg = colors.get("bright_blue", colors.get("frost2"))

# Downloads
c.colors.downloads.bar.bg = colors.get("dark2", colors.get("polar_night2"))
c.colors.downloads.start.bg = colors.get("bright_blue", colors.get("frost2"))
c.colors.downloads.stop.bg = colors.get("bright_green", colors.get("green"))
c.colors.downloads.error.bg = colors.get("bright_red", colors.get("red"))

# Prompts
c.colors.prompts.bg = colors.get("dark1", colors.get("polar_night1"))
c.colors.prompts.fg = colors.get("light1", colors.get("snow_storm0"))
c.colors.prompts.border = f"1px solid {colors.get('bright_blue', colors.get('frost2'))}"
