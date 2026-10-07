// theme.js — theme switcher (ported from the portfolio). Loaded in <head>
// so the saved theme applies before first paint. Press `t` to cycle.
(function () {
  const THEMES = ["gruvbox", "nord", "catppuccin", "tokyonight"];
  const KEY = "theme";

  function saved() {
    try {
      const t = localStorage.getItem(KEY);
      return THEMES.includes(t) ? t : THEMES[0];
    } catch (_) {
      return THEMES[0];
    }
  }

  function setTheme(name) {
    if (!THEMES.includes(name)) return false;
    document.documentElement.setAttribute("data-theme", name);
    try {
      localStorage.setItem(KEY, name);
    } catch (_) {}
    window.dispatchEvent(new CustomEvent("themechange", { detail: name }));
    return true;
  }

  function cycle() {
    const cur = document.documentElement.getAttribute("data-theme");
    setTheme(THEMES[(THEMES.indexOf(cur) + 1) % THEMES.length]);
  }

  document.documentElement.setAttribute("data-theme", saved());
  window.THEMES = THEMES;
  window.setTheme = setTheme;
  window.cycleTheme = cycle;
})();
