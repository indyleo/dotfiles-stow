/* ---- MATRIX RAIN ---- */
let matrixRainVisibility;
(function () {
  const canvas = document.getElementById("matrix-canvas");
  const ctx = canvas.getContext("2d");

  const colors = ["#b8bb26", "#8ec07c", "#fe8019", "#fabd2f", "#83a598"];
  const fontSize = 14;
  const INTERVAL_MS = 45;
  const STORAGE_KEY = "matrix_state";

  let cols, drops;

  function resize() {
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
    cols = Math.floor(canvas.width / fontSize);
  }

  function initDrops() {
    try {
      const saved = JSON.parse(localStorage.getItem(STORAGE_KEY));
      if (saved && Array.isArray(saved.drops) && saved.ts) {
        const elapsed = Date.now() - saved.ts;
        const ticksElapsed = Math.floor(elapsed / INTERVAL_MS);
        const maxRow = Math.ceil(canvas.height / fontSize);

        drops = Array.from({ length: cols }, (_, i) => {
          const savedDrop = saved.drops[i];
          if (savedDrop !== undefined) {
            let d = savedDrop + ticksElapsed;
            if (d * fontSize > canvas.height) {
              const overTicks = Math.floor(
                (d * fontSize - canvas.height) / fontSize,
              );
              if (
                overTicks > 40 ||
                Math.random() > 0.975 ** Math.min(overTicks, 40)
              ) {
                d = Math.floor(Math.random() * maxRow);
              }
            }
            return d;
          }
          return (Math.random() * -50) | 0;
        });
        return;
      }
    } catch (_) {}

    drops = Array.from({ length: cols }, () => (Math.random() * -50) | 0);
  }

  function saveState() {
    try {
      localStorage.setItem(
        STORAGE_KEY,
        JSON.stringify({ drops, ts: Date.now() }),
      );
    } catch (_) {}
  }

  function draw() {
    ctx.fillStyle = "rgba(29, 32, 33, 0.055)";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.font = fontSize + "px 'JetBrains Mono', monospace";

    for (let i = 0; i < drops.length; i++) {
      const char =
        Math.random() > 0.5
          ? String.fromCharCode(0x30a0 + Math.floor(Math.random() * 96))
          : String.fromCharCode(33 + Math.floor(Math.random() * 93));

      ctx.fillStyle = colors[i % colors.length];
      ctx.fillText(char, i * fontSize, drops[i] * fontSize);

      if (drops[i] * fontSize > canvas.height && Math.random() > 0.975) {
        drops[i] = 0;
      }
      drops[i]++;
    }
  }

  resize();
  initDrops();

  (function prewarm() {
    ctx.font = fontSize + "px 'JetBrains Mono', monospace";
    for (let i = 0; i < drops.length; i++) {
      const char = String.fromCharCode(0x30a0 + Math.floor(Math.random() * 96));
      ctx.fillStyle = colors[i % colors.length];
      ctx.fillText(char, i * fontSize, drops[i] * fontSize);
    }
  })();

  window.addEventListener("resize", () => {
    resize();
    initDrops();
  });
  window.addEventListener("pagehide", saveState);
  window.addEventListener("beforeunload", saveState);

  let drawTimer = setInterval(draw, INTERVAL_MS);
  matrixRainVisibility = {
    pause() {
      clearInterval(drawTimer);
      saveState();
    },
    resume() {
      drawTimer = setInterval(draw, INTERVAL_MS);
    },
  };
})();

/* ---- AUDIO ---- */
function playSunAudio() {
  const audio = document.getElementById("sun-audio");
  audio.volume = 0.4;
  const p = audio.play();
  if (p !== undefined) {
    p.catch(() => {
      const start = () => {
        audio.play();
        document.removeEventListener("click", start);
        document.removeEventListener("keydown", start);
      };
      document.addEventListener("click", start);
      document.addEventListener("keydown", start);
    });
  }
}

function stopSunAudio() {
  const audio = document.getElementById("sun-audio");
  audio.pause();
  audio.currentTime = 0;
}

/* ---- HOLIDAY DETECTION ---- */
function getEasterDate(year) {
  const a = year % 19;
  const b = Math.floor(year / 100);
  const c = year % 100;
  const d = Math.floor(b / 4);
  const e = b % 4;
  const f = Math.floor((b + 8) / 25);
  const g = Math.floor((b - f + 1) / 3);
  const h = (19 * a + b - d - g + 15) % 30;
  const i = Math.floor(c / 4);
  const k = c % 4;
  const l = (32 + 2 * e + 2 * i - h - k) % 7;
  const m = Math.floor((a + 11 * h + 22 * l) / 451);
  const month = Math.floor((h + l - 7 * m + 114) / 31);
  const day = ((h + l - 7 * m + 114) % 31) + 1;
  return { month, day };
}

function getHolidayMessage() {
  const now = new Date();
  const m = now.getMonth() + 1;
  const d = now.getDate();
  const y = now.getFullYear();

  if (m === 1 && d === 1) return "🎆 Happy New Year!";
  if (m === 2 && d === 14) return "💘 Happy Valentine's Day";
  if (m === 3 && d === 17) return "🍀 Happy St. Patrick's Day";
  if (m === 4 && d === 1) return "🃏 April Fools! Watch your back.";
  if (m === 7 && d === 1) return "🍁 Happy Canada Day, eh!";
  if (m === 10 && d === 31) return "🎃 Happy Halloween! Boo.";
  if (m === 12 && d === 25) return "🎄 Merry Christmas!";
  if (m === 12 && d === 31) return "🥂 New Year's Eve — almost there!";

  const easter = getEasterDate(y);
  if (m === easter.month && d === easter.day) return "🐣 Happy Easter!";

  return null;
}

/* ---- GREETING & CLOCK ---- */
const FALLBACK_QUOTES = [
  "ERR_ENOENT: quotes.txt not found",
  "Local wisdom cache corrupted — running on stub data",
  "Signal lost mid-transmission...",
  "// TODO: recover lost quote archive",
  "Failed to mount /wisdom — fallback engaged",
  "404: philosophy not found",
  "Quote daemon crashed. Nobody noticed.",
  "Reading from /dev/null instead",
];
const FALLBACK_PHRASES = [
  "System Fault",
  "Cache Miss",
  "Buffer Underrun",
  "Signal Lost",
  "Fallback Engaged",
  "Data Corrupted",
  "Read Error",
  "Segfault Averted",
  "Kernel Panic (Contained)",
  "Connection Timed Out",
];
function pickFallbackQuote() {
  return FALLBACK_QUOTES[Math.floor(Math.random() * FALLBACK_QUOTES.length)];
}
function pickFallbackPhrase() {
  return FALLBACK_PHRASES[Math.floor(Math.random() * FALLBACK_PHRASES.length)];
}

let currentQuote = pickFallbackQuote();
let currentRandomPhrase = pickFallbackPhrase();
let greetingTyped = false;
let loadedQuotes = [];
let loadedPhrases = [];

let typeAnimationGen = 0;
function typeText(el, text, speed, onDone) {
  const myGen = ++typeAnimationGen;
  el.textContent = "";
  const cursor = document.createElement("span");
  cursor.className = "typing-cursor";
  el.parentNode.insertBefore(cursor, el.nextSibling);

  let i = 0;
  function tick() {
    if (myGen !== typeAnimationGen) {
      cursor.remove();
      return;
    }
    if (i <= text.length) {
      el.textContent = text.slice(0, i);
      i++;
      setTimeout(tick, speed);
    } else {
      cursor.remove();
      if (onDone) onDone();
    }
  }
  tick();
}

async function loadTextFiles() {
  const [quoteOutcome, phraseOutcome] = await Promise.allSettled([
    fetch("quotes.txt"),
    fetch("randomphrases.txt"),
  ]);

  if (quoteOutcome.status === "fulfilled" && quoteOutcome.value.ok) {
    try {
      const quotes = (await quoteOutcome.value.text())
        .split("\n")
        .filter((l) => l.trim());
      if (quotes.length) {
        loadedQuotes = quotes;
        currentQuote = quotes[Math.floor(Math.random() * quotes.length)].trim();
        if (
          currentQuote.toLowerCase().includes("here comes the sun do do dodo")
        ) {
          playSunAudio();
        }
      } else {
        currentQuote = "quotes.txt is empty — " + pickFallbackQuote();
      }
    } catch (_) {
      currentQuote = pickFallbackQuote();
    }
  } else {
    currentQuote = pickFallbackQuote();
  }

  if (phraseOutcome.status === "fulfilled" && phraseOutcome.value.ok) {
    try {
      const phrases = (await phraseOutcome.value.text())
        .split("\n")
        .filter((l) => l.trim());
      if (phrases.length) {
        loadedPhrases = phrases;
        currentRandomPhrase =
          phrases[Math.floor(Math.random() * phrases.length)];
      } else {
        currentRandomPhrase = pickFallbackPhrase();
      }
    } catch (_) {
      currentRandomPhrase = pickFallbackPhrase();
    }
  } else {
    currentRandomPhrase = pickFallbackPhrase();
  }

  updateClock();
}

function rerollGreeting() {
  currentQuote = loadedQuotes.length
    ? loadedQuotes[Math.floor(Math.random() * loadedQuotes.length)].trim()
    : pickFallbackQuote();
  if (currentQuote.toLowerCase().includes("here comes the sun do do dodo")) {
    playSunAudio();
  } else {
    stopSunAudio();
  }
  currentRandomPhrase = loadedPhrases.length
    ? loadedPhrases[Math.floor(Math.random() * loadedPhrases.length)]
    : pickFallbackPhrase();

  greetingTyped = false;
  updateClock();
}

function updateClock() {
  const now = new Date();
  const days = [
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
  ];
  const months = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];
  const h = now.getHours();

  const timeStr = `${days[now.getDay()]}, ${months[now.getMonth()]} ${now.getDate()} \u2022 ${h % 12 || 12}:${String(now.getMinutes()).padStart(2, "0")} ${h >= 12 ? "PM" : "AM"}`;
  let timerHtml = "";
  if (alarmState.active && alarmState.mode === "in") {
    const remaining = Math.max(0, alarmState.targetEpoch - Date.now());
    const formatted = formatDuration(remaining);
    timerHtml = ` <span id="timer-status" style="color: var(--accent); margin-left: 8px;">⏳ ${formatted}</span>`;
  }
  document.getElementById("datetime").innerHTML = timeStr + timerHtml;

  const greet =
    h < 12 ? "Good Morning" : h < 17 ? "Good Afternoon" : "Good Evening";
  const holiday = getHolidayMessage();
  const greetLine = holiday
    ? `${greet} \u2014 ${currentRandomPhrase} \u00b7 ${holiday}`
    : `${greet} \u2014 ${currentRandomPhrase}`;

  const greetEl = document.getElementById("greet-line");
  const quoteEl = document.getElementById("quote-line");

  if (!greetingTyped) {
    greetingTyped = true;
    quoteEl.style.opacity = "0";
    typeText(greetEl, greetLine, 28, () => {
      quoteEl.textContent = `"${currentQuote}"`;
      quoteEl.style.opacity = "1";
    });
  } else {
    greetEl.textContent = greetLine;
    quoteEl.textContent = `"${currentQuote}"`;
    quoteEl.style.opacity = "1";
  }

  if (activePopover === "clock") {
    updateWorldClockRows();
    const statusEl = document.getElementById("alarm-status");
    if (statusEl) updateAlarmUI();
  }
}

const WORLD_CLOCK_ZONES = [
  { label: "Local", zone: undefined },
  { label: "UTC", zone: "UTC" },
  { label: "New York", zone: "America/New_York" },
  { label: "London", zone: "Europe/London" },
  { label: "Tokyo", zone: "Asia/Tokyo" },
];

/* ---- CALENDAR & UNIFIED ALARM ---- */
let calendarViewYear = new Date().getFullYear();
let calendarViewMonth = new Date().getMonth();

const ALARM_STORAGE_KEY = "unified_alarm";
let alarmState = loadUnifiedAlarm();
let alarmTimer = null;
let alarmAudioContext = null;
let alarmRinging = false;

function loadUnifiedAlarm() {
  try {
    const saved = JSON.parse(localStorage.getItem(ALARM_STORAGE_KEY));
    if (saved && saved.mode && (saved.mode === "at" || saved.mode === "in")) {
      return {
        mode: saved.mode,
        at: saved.at || { hh: "07", mm: "00", period: "AM" },
        in: saved.in || { hh: "00", mm: "01", ss: "00" },
        repeat: !!saved.repeat,
        active: !!saved.active,
        targetEpoch: saved.targetEpoch || null,
        durationMs: saved.durationMs || null,
      };
    }
  } catch (_) {}
  return {
    mode: "at",
    at: { hh: "07", mm: "00", period: "AM" },
    in: { hh: "00", mm: "01", ss: "00" },
    repeat: false,
    active: false,
    targetEpoch: null,
    durationMs: null,
  };
}

function saveUnifiedAlarm() {
  try {
    localStorage.setItem(ALARM_STORAGE_KEY, JSON.stringify(alarmState));
  } catch (_) {}
}

function getNextAtTimestamp() {
  const { hh, mm, period } = alarmState.at;
  let h = parseInt(hh, 10);
  const m = parseInt(mm, 10);
  if (period === "AM" && h === 12) h = 0;
  else if (period === "PM" && h !== 12) h += 12;
  const now = new Date();
  const target = new Date(
    now.getFullYear(),
    now.getMonth(),
    now.getDate(),
    h,
    m,
    0,
    0,
  );
  if (target <= now) target.setDate(target.getDate() + 1);
  return target.getTime();
}

function scheduleUnifiedAlarm() {
  if (alarmTimer) {
    clearTimeout(alarmTimer);
    alarmTimer = null;
  }
  if (!alarmState.active || !alarmState.targetEpoch) return;

  const delay = Math.max(0, alarmState.targetEpoch - Date.now());
  alarmTimer = setTimeout(() => {
    triggerUnifiedAlarm();
    if (alarmState.active && alarmState.repeat) {
      if (alarmState.mode === "at") {
        alarmState.targetEpoch = getNextAtTimestamp();
      } else {
        alarmState.targetEpoch = Date.now() + alarmState.durationMs;
      }
      saveUnifiedAlarm();
      scheduleUnifiedAlarm();
    } else {
      alarmState.active = false;
      saveUnifiedAlarm();
      updateAlarmUI();
    }
  }, delay);
}

function ensureAlarmAudio() {
  if (!alarmAudioContext) {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (!AudioContext) return null;
    alarmAudioContext = new AudioContext();
  }
  if (alarmAudioContext.state === "suspended") {
    alarmAudioContext.resume().catch(() => {});
  }
  return alarmAudioContext;
}

function beepAlarm() {
  const ctx = ensureAlarmAudio();
  if (!ctx) return;
  const start = ctx.currentTime;
  [0, 0.22, 0.44, 0.66, 0.88].forEach((offset, i) => {
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sine";
    osc.frequency.value = i % 2 ? 880 : 660;
    gain.gain.setValueAtTime(0.0001, start + offset);
    gain.gain.exponentialRampToValueAtTime(0.18, start + offset + 0.015);
    gain.gain.exponentialRampToValueAtTime(0.0001, start + offset + 0.18);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(start + offset);
    osc.stop(start + offset + 0.2);
  });
}

function stopAlarmRinging() {
  alarmRinging = false;
  document.getElementById("datetime")?.classList.remove("alarm-ringing");
}

function triggerUnifiedAlarm() {
  if (!alarmState.active || alarmRinging) return;
  alarmRinging = true;
  beepAlarm();
  document.getElementById("datetime")?.classList.add("alarm-ringing");
  setTimeout(stopAlarmRinging, 10000);

  if (
    typeof Notification !== "undefined" &&
    Notification.permission === "granted"
  ) {
    const label =
      alarmState.mode === "at"
        ? `Alarm: ${alarmState.at.hh}:${alarmState.at.mm} ${alarmState.at.period}`
        : `Timer finished`;
    new Notification("Alarm", { body: label });
  }
}

function setUnifiedAlarm() {
  const mode = alarmState.mode;
  if (mode === "at") {
    const hh = document.getElementById("alarm-hh")?.value;
    const mm = document.getElementById("alarm-mm")?.value;
    const period = alarmState.at.period;
    if (!hh || !mm) return false;
    const hNum = parseInt(hh, 10);
    const mNum = parseInt(mm, 10);
    if (
      isNaN(hNum) ||
      hNum < 1 ||
      hNum > 12 ||
      isNaN(mNum) ||
      mNum < 0 ||
      mNum > 59
    )
      return false;
    alarmState.at.hh = hh.padStart(2, "0");
    alarmState.at.mm = mm.padStart(2, "0");
    alarmState.at.period = period;
    alarmState.targetEpoch = getNextAtTimestamp();
    alarmState.durationMs = null;
  } else {
    const hh = document.getElementById("alarm-hh")?.value;
    const mm = document.getElementById("alarm-mm")?.value;
    const ss = document.getElementById("alarm-ss")?.value;
    if (!hh || !mm || !ss) return false;
    const hNum = parseInt(hh, 10);
    const mNum = parseInt(mm, 10);
    const sNum = parseInt(ss, 10);
    if (
      isNaN(hNum) ||
      hNum < 0 ||
      hNum > 99 ||
      isNaN(mNum) ||
      mNum < 0 ||
      mNum > 59 ||
      isNaN(sNum) ||
      sNum < 0 ||
      sNum > 59
    )
      return false;
    const durationMs = (hNum * 3600 + mNum * 60 + sNum) * 1000;
    if (durationMs <= 0) return false;
    alarmState.in.hh = hh.padStart(2, "0");
    alarmState.in.mm = mm.padStart(2, "0");
    alarmState.in.ss = ss.padStart(2, "0");
    alarmState.targetEpoch = Date.now() + durationMs;
    alarmState.durationMs = durationMs;
  }
  alarmState.active = true;
  saveUnifiedAlarm();
  scheduleUnifiedAlarm();
  updateAlarmUI();
  if (
    typeof Notification !== "undefined" &&
    Notification.permission === "default"
  ) {
    Notification.requestPermission().catch(() => {});
  }
  // Update button text
  const actionBtn = document.querySelector(".alarm-action-btn");
  if (actionBtn) actionBtn.textContent = "Cancel";
  return true;
}

function cancelUnifiedAlarm() {
  alarmState.active = false;
  alarmState.targetEpoch = null;
  saveUnifiedAlarm();
  if (alarmTimer) {
    clearTimeout(alarmTimer);
    alarmTimer = null;
  }
  stopAlarmRinging();
  updateAlarmUI();
  // Update button text
  const actionBtn = document.querySelector(".alarm-action-btn");
  if (actionBtn) actionBtn.textContent = "Set";
}

function formatDuration(ms) {
  if (ms < 0) ms = 0;
  const totalSec = Math.floor(ms / 1000);
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = totalSec % 60;
  return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
}

function updateAlarmUI() {
  const statusEl = document.getElementById("alarm-status");
  if (!statusEl) return;
  if (!alarmState.active) {
    statusEl.textContent = "No alarm set";
    statusEl.classList.remove("active");
    return;
  }
  statusEl.classList.add("active");
  if (alarmState.mode === "in") {
    const remain = alarmState.targetEpoch - Date.now();
    statusEl.textContent = `Alarm in ${formatDuration(remain)}${alarmState.repeat ? " (repeating)" : ""}`;
  } else {
    const repeatLabel = alarmState.repeat
      ? " (daily)"
      : " (once, " +
        new Date(alarmState.targetEpoch).toLocaleDateString(undefined, {
          month: "short",
          day: "numeric",
        }) +
        ")";
    statusEl.textContent = `Alarm set for ${alarmState.at.hh}:${alarmState.at.mm} ${alarmState.at.period}${repeatLabel}`;
  }
}

function buildCalendarCells(year, month) {
  const cells = [];
  const firstDay = new Date(year, month, 1);
  const startDow = firstDay.getDay();
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const daysInPrevMonth = new Date(year, month, 0).getDate();
  const today = new Date();

  for (let i = 0; i < startDow; i++) {
    cells.push({
      day: daysInPrevMonth - startDow + 1 + i,
      inMonth: false,
      isToday: false,
    });
  }
  for (let d = 1; d <= daysInMonth; d++) {
    const isToday =
      year === today.getFullYear() &&
      month === today.getMonth() &&
      d === today.getDate();
    cells.push({ day: d, inMonth: true, isToday });
  }
  let remaining = 42 - cells.length;
  for (let t = 1; t <= remaining; t++) {
    cells.push({ day: t, inMonth: false, isToday: false });
  }
  return cells;
}

function renderCalendar(container) {
  container.innerHTML = "";

  const header = document.createElement("div");
  header.className = "calendar-header";

  const prevBtn = document.createElement("button");
  prevBtn.className = "calendar-nav-btn";
  prevBtn.textContent = "‹";
  prevBtn.addEventListener("click", (e) => {
    e.stopPropagation();
    if (calendarViewMonth === 0) {
      calendarViewMonth = 11;
      calendarViewYear--;
    } else calendarViewMonth--;
    renderCalendar(container);
  });

  const monthLabel = document.createElement("span");
  monthLabel.className = "calendar-month-label";
  monthLabel.textContent = new Date(
    calendarViewYear,
    calendarViewMonth,
    1,
  ).toLocaleDateString(undefined, { month: "long", year: "numeric" });

  const nextBtn = document.createElement("button");
  nextBtn.className = "calendar-nav-btn";
  nextBtn.textContent = "›";
  nextBtn.addEventListener("click", (e) => {
    e.stopPropagation();
    if (calendarViewMonth === 11) {
      calendarViewMonth = 0;
      calendarViewYear++;
    } else calendarViewMonth++;
    renderCalendar(container);
  });

  header.append(prevBtn, monthLabel, nextBtn);
  container.appendChild(header);

  const weekdayContainer = document.createElement("div");
  weekdayContainer.className = "calendar-weekdays";
  ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"].forEach((day) => {
    const span = document.createElement("span");
    span.className = "calendar-weekday";
    span.textContent = day;
    weekdayContainer.appendChild(span);
  });
  container.appendChild(weekdayContainer);

  const grid = document.createElement("div");
  grid.className = "calendar-grid";
  const cells = buildCalendarCells(calendarViewYear, calendarViewMonth);
  cells.forEach((cell) => {
    const div = document.createElement("div");
    div.className = "calendar-cell";
    if (cell.inMonth) div.classList.add("in-month");
    else div.classList.add("out-month");
    if (cell.isToday) div.classList.add("today");
    div.textContent = cell.day;
    grid.appendChild(div);
  });
  container.appendChild(grid);

  const todayBtn = document.createElement("button");
  todayBtn.className = "calendar-today-btn";
  todayBtn.textContent = "Today";
  todayBtn.addEventListener("click", (e) => {
    e.stopPropagation();
    const now = new Date();
    calendarViewYear = now.getFullYear();
    calendarViewMonth = now.getMonth();
    renderCalendar(container);
  });
  container.appendChild(todayBtn);

  const divider = document.createElement("hr");
  divider.className = "calendar-divider";
  container.appendChild(divider);
}

function renderUnifiedAlarm(container) {
  container.innerHTML = "";

  const modeRow = document.createElement("div");
  modeRow.className = "alarm-mode-row";

  const modeToggle = document.createElement("div");
  modeToggle.className = "toggle-group";
  ["at", "in"].forEach((mode) => {
    const opt = document.createElement("span");
    opt.className = "toggle-option";
    opt.textContent = mode === "at" ? "At" : "In";
    if (alarmState.mode === mode) opt.classList.add("active");
    opt.addEventListener("click", (e) => {
      e.stopPropagation();
      alarmState.mode = mode;
      saveUnifiedAlarm();
      renderUnifiedAlarm(container);
    });
    modeToggle.appendChild(opt);
  });

  const repeatToggle = document.createElement("div");
  repeatToggle.className = "toggle-group";
  const repeatLabel = alarmState.mode === "at" ? "Daily" : "Repeat";
  const onceOpt = document.createElement("span");
  onceOpt.className = "toggle-option";
  onceOpt.textContent = "Once";
  if (!alarmState.repeat) onceOpt.classList.add("active");
  onceOpt.addEventListener("click", (e) => {
    e.stopPropagation();
    alarmState.repeat = false;
    saveUnifiedAlarm();
    renderUnifiedAlarm(container);
  });
  const repeatOpt = document.createElement("span");
  repeatOpt.className = "toggle-option";
  repeatOpt.textContent = repeatLabel;
  if (alarmState.repeat) repeatOpt.classList.add("active");
  repeatOpt.addEventListener("click", (e) => {
    e.stopPropagation();
    alarmState.repeat = true;
    saveUnifiedAlarm();
    renderUnifiedAlarm(container);
  });
  repeatToggle.append(onceOpt, repeatOpt);

  modeRow.append(modeToggle, repeatToggle);
  container.appendChild(modeRow);

  const timeRow = document.createElement("div");
  timeRow.className = "alarm-time-row";

  const hhField = document.createElement("input");
  hhField.className = "alarm-field";
  hhField.id = "alarm-hh";
  hhField.maxLength = 2;
  hhField.value =
    alarmState.mode === "at" ? alarmState.at.hh : alarmState.in.hh;
  hhField.addEventListener("input", (e) => {
    e.target.value = e.target.value.replace(/\D/g, "").slice(0, 2);
  });

  const colon1 = document.createElement("span");
  colon1.className = "alarm-colon";
  colon1.textContent = ":";

  const mmField = document.createElement("input");
  mmField.className = "alarm-field";
  mmField.id = "alarm-mm";
  mmField.maxLength = 2;
  mmField.value =
    alarmState.mode === "at" ? alarmState.at.mm : alarmState.in.mm;
  mmField.addEventListener("input", (e) => {
    e.target.value = e.target.value.replace(/\D/g, "").slice(0, 2);
  });

  timeRow.append(hhField, colon1, mmField);

  if (alarmState.mode === "at") {
    const ampmToggle = document.createElement("div");
    ampmToggle.className = "toggle-group";
    ["AM", "PM"].forEach((period) => {
      const opt = document.createElement("span");
      opt.className = "toggle-option";
      opt.textContent = period;
      if (alarmState.at.period === period) opt.classList.add("active");
      opt.addEventListener("click", (e) => {
        e.stopPropagation();
        alarmState.at.period = period;
        saveUnifiedAlarm();
        renderUnifiedAlarm(container);
      });
      ampmToggle.appendChild(opt);
    });
    timeRow.appendChild(ampmToggle);
  } else {
    const colon2 = document.createElement("span");
    colon2.className = "alarm-colon";
    colon2.textContent = ":";

    const ssField = document.createElement("input");
    ssField.className = "alarm-field";
    ssField.id = "alarm-ss";
    ssField.maxLength = 2;
    ssField.value = alarmState.in.ss;
    ssField.addEventListener("input", (e) => {
      e.target.value = e.target.value.replace(/\D/g, "").slice(0, 2);
    });

    timeRow.append(colon2, ssField);
  }

  const actionBtn = document.createElement("button");
  actionBtn.className = "alarm-action-btn";
  actionBtn.textContent = alarmState.active ? "Cancel" : "Set";
  actionBtn.addEventListener("click", (e) => {
    e.stopPropagation();
    if (alarmState.active) {
      cancelUnifiedAlarm();
    } else {
      setUnifiedAlarm();
    }
    // Update button text after action
    actionBtn.textContent = alarmState.active ? "Cancel" : "Set";
  });
  timeRow.appendChild(actionBtn);

  container.appendChild(timeRow);

  const status = document.createElement("div");
  status.className = "alarm-status";
  status.id = "alarm-status";
  container.appendChild(status);
  updateAlarmUI();
}

/* ---- WEATHER ---- */
const WEATHER_CACHE_KEY = "weather_cache";
const WEATHER_TTL_MS = 10 * 60 * 1000;

function getCachedWeather() {
  try {
    const cached = JSON.parse(localStorage.getItem(WEATHER_CACHE_KEY));
    if (cached && typeof cached.value === "string" && cached.ts) {
      return cached;
    }
  } catch (_) {}
  return null;
}

function setCachedWeather(value) {
  try {
    localStorage.setItem(
      WEATHER_CACHE_KEY,
      JSON.stringify({ value, ts: Date.now() }),
    );
  } catch (_) {}
}

async function initWeather() {
  const cached = getCachedWeather();
  const cacheIsFresh = cached && Date.now() - cached.ts < WEATHER_TTL_MS;

  if (cacheIsFresh) {
    document.getElementById("weather-val").textContent = cached.value;
    return;
  }

  try {
    const res = await fetch("https://wttr.in/?format=%C+%t", {
      cache: "no-store",
    });
    if (!res.ok) throw new Error();
    const text = (await res.text()).trim();

    let weather = text;
    if (text.startsWith("<!DOCTYPE") || text.startsWith("<")) {
      const doc = new DOMParser().parseFromString(text, "text/html");
      weather = doc.querySelector(".term-container")?.textContent?.trim() ?? "";
      if (!weather) throw new Error();
    }

    document.getElementById("weather-val").textContent = weather;
    setCachedWeather(weather);
  } catch (_) {
    if (cached) {
      document.getElementById("weather-val").textContent = cached.value;
    } else {
      document.getElementById("weather-container").classList.add("hidden");
    }
  }
}

/* ---- INFO POPOVER ---- */
let activePopover = null;
let activePopoverTrigger = null;

function positionPopover(triggerEl) {
  const popover = document.getElementById("info-popover");
  const rect = triggerEl.getBoundingClientRect();
  const gap = 10;
  const margin = 8;

  popover.style.top = "0px";
  popover.style.bottom = "";
  popover.style.left = "0px";
  const popRect = popover.getBoundingClientRect();

  const spaceBelow = window.innerHeight - rect.bottom;
  const placeBelow =
    rect.top < window.innerHeight / 2 || spaceBelow > popRect.height + gap;

  if (placeBelow) {
    popover.style.top = `${rect.bottom + gap}px`;
    popover.style.bottom = "";
  } else {
    popover.style.top = "";
    popover.style.bottom = `${window.innerHeight - rect.top + gap}px`;
  }

  let left = rect.left + rect.width / 2 - popRect.width / 2;
  left = Math.max(
    margin,
    Math.min(left, window.innerWidth - popRect.width - margin),
  );
  popover.style.left = `${left}px`;
}

async function openPopover(key, triggerEl) {
  const popover = document.getElementById("info-popover");
  if (activePopover === key) {
    closePopover();
    return;
  }
  activePopover = key;
  activePopoverTrigger = triggerEl;
  popover.classList.add("visible");
  await renderPopoverContent(key, popover);
  if (activePopover === key) positionPopover(triggerEl);
}

function closePopover() {
  document.getElementById("info-popover").classList.remove("visible");
  activePopover = null;
  activePopoverTrigger = null;
}

async function renderPopoverContent(key, popover) {
  popover.textContent = "";
  switch (key) {
    case "weather":
      await renderWeatherPopover(popover);
      break;
    case "ping":
      renderPingPopover(popover);
      break;
    case "battery":
      renderBatteryPopover(popover);
      break;
    case "browser":
      renderBrowserPopover(popover);
      break;
    case "clock":
      renderClockPopover(popover);
      break;
    case "uptime":
      renderUptimePopover(popover);
      break;
  }
}

function addPopoverTitle(popover, text) {
  const title = document.createElement("div");
  title.className = "popover-title";
  title.textContent = text;
  popover.appendChild(title);
}
function addKvRow(container, label, value) {
  const row = document.createElement("div");
  row.className = "kv-row";
  const l = document.createElement("span");
  l.className = "kv-label";
  l.textContent = label;
  const v = document.createElement("span");
  v.textContent = value;
  row.append(l, v);
  container.appendChild(row);
}

/* ---- WEATHER FORECAST POPOVER ---- */
const FORECAST_CACHE_KEY = "weather_forecast_cache";
const FORECAST_TTL_MS = 30 * 60 * 1000;

function getCachedForecast() {
  try {
    const cached = JSON.parse(localStorage.getItem(FORECAST_CACHE_KEY));
    if (cached && Array.isArray(cached.value) && cached.ts) {
      return cached;
    }
  } catch (_) {}
  return null;
}

function setCachedForecast(value) {
  try {
    localStorage.setItem(
      FORECAST_CACHE_KEY,
      JSON.stringify({ value, ts: Date.now() }),
    );
  } catch (_) {}
}

async function fetchForecast() {
  const res = await fetch("https://wttr.in/?format=j1", {
    cache: "no-store",
  });
  if (!res.ok) throw new Error();
  const data = await res.json();
  return data.weather.slice(0, 3).map((day) => {
    const mid = day.hourly?.[4] ?? day.hourly?.[0];
    return {
      date: day.date,
      max: day.maxtempC,
      min: day.mintempC,
      desc: mid?.weatherDesc?.[0]?.value ?? "",
    };
  });
}

function renderForecastDays(container, days) {
  const row = document.createElement("div");
  row.className = "popover-row";
  days.forEach((d) => {
    const dayEl = document.createElement("div");
    dayEl.className = "forecast-day";

    const dt = new Date(`${d.date}T00:00:00`);
    const label = document.createElement("div");
    label.className = "fc-day-label";
    label.textContent = isNaN(dt)
      ? d.date
      : dt.toLocaleDateString(undefined, { weekday: "short" });

    const desc = document.createElement("div");
    desc.className = "fc-desc";
    desc.textContent = d.desc;

    const temps = document.createElement("div");
    temps.className = "fc-temps";
    temps.textContent = `${d.max}\u00b0 / ${d.min}\u00b0C`;

    dayEl.append(label, desc, temps);
    row.appendChild(dayEl);
  });
  container.appendChild(row);
}

async function renderWeatherPopover(popover) {
  addPopoverTitle(popover, "3-Day Forecast");
  const body = document.createElement("div");
  popover.appendChild(body);

  const cached = getCachedForecast();
  const cacheIsFresh = cached && Date.now() - cached.ts < FORECAST_TTL_MS;
  if (cacheIsFresh) {
    renderForecastDays(body, cached.value);
    return;
  }

  body.textContent = "Loading forecast\u2026";
  try {
    const days = await fetchForecast();
    if (activePopover !== "weather") return;
    body.textContent = "";
    renderForecastDays(body, days);
    setCachedForecast(days);
  } catch (_) {
    if (activePopover !== "weather") return;
    body.textContent = "";
    if (cached) {
      renderForecastDays(body, cached.value);
    } else {
      body.textContent = "Forecast unavailable";
    }
  }
}

/* ---- PING ---- */
const PING_TARGETS = [
  { url: "https://www.google.com/generate_204", label: "Google" },
  {
    url: "https://www.cloudflare.com/cdn-cgi/trace",
    label: "Cloudflare",
  },
];
const PING_HISTORY_MAX = 20;
let lastPingResults = [];
let pingHistory = [];

async function measurePing() {
  const pingEl = document.getElementById("ping-val");
  const results = [];
  for (const target of PING_TARGETS) {
    try {
      const t0 = performance.now();
      await fetch(target.url, {
        method: "HEAD",
        mode: "no-cors",
        cache: "no-store",
      });
      results.push({
        label: target.label,
        ms: Math.round(performance.now() - t0),
      });
    } catch (_) {}
  }
  lastPingResults = results;

  if (results.length) {
    const avg = Math.round(
      results.reduce((a, b) => a + b.ms, 0) / results.length,
    );
    const color =
      avg < 50 ? "var(--green)" : avg < 120 ? "var(--yellow)" : "var(--red)";
    document.getElementById("ping-container").classList.remove("hidden");
    pingEl.innerHTML = `<span style="color:${color}">${avg} ms</span>`;

    pingHistory.push({ ts: Date.now(), avg });
    if (pingHistory.length > PING_HISTORY_MAX) pingHistory.shift();
  } else {
    document.getElementById("ping-container").classList.add("hidden");
  }

  if (activePopover === "ping") {
    renderPopoverContent("ping", document.getElementById("info-popover"));
    if (activePopoverTrigger) positionPopover(activePopoverTrigger);
  }
}

function buildPingSparkline(history) {
  const w = 180;
  const h = 32;
  const pad = 2;
  const values = history.map((entry) => entry.avg);
  const max = Math.max(...values, 1);
  const min = Math.min(...values, 0);
  const range = Math.max(max - min, 1);

  const points = values
    .map((v, i) => {
      const x = pad + (i / (values.length - 1)) * (w - pad * 2);
      const y = h - pad - ((v - min) / range) * (h - pad * 2);
      return `${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(" ");

  const svgNS = "http://www.w3.org/2000/svg";
  const svg = document.createElementNS(svgNS, "svg");
  svg.setAttribute("viewBox", `0 0 ${w} ${h}`);
  svg.setAttribute("width", String(w));
  svg.setAttribute("height", String(h));

  const polyline = document.createElementNS(svgNS, "polyline");
  polyline.setAttribute("points", points);
  polyline.setAttribute("fill", "none");
  polyline.style.stroke = "var(--aqua)";
  polyline.style.strokeWidth = "1.5";
  svg.appendChild(polyline);

  return svg;
}

function renderPingPopover(popover) {
  addPopoverTitle(popover, "Ping Breakdown");

  if (!lastPingResults.length) {
    const empty = document.createElement("div");
    empty.className = "popover-empty";
    empty.textContent = "No data yet";
    popover.appendChild(empty);
    return;
  }

  const list = document.createElement("div");
  list.className = "ping-list";
  lastPingResults.forEach((r) => {
    const row = document.createElement("div");
    row.className = "ping-row";
    const label = document.createElement("span");
    label.className = "ping-label";
    label.textContent = r.label;
    const val = document.createElement("span");
    const color =
      r.ms < 50 ? "var(--green)" : r.ms < 120 ? "var(--yellow)" : "var(--red)";
    val.innerHTML = `<span style="color:${color}">${r.ms} ms</span>`;
    row.append(label, val);
    list.appendChild(row);
  });
  popover.appendChild(list);

  if (pingHistory.length > 1) {
    popover.appendChild(buildPingSparkline(pingHistory));
  }
}

/* ---- SYS INFO ---- */
async function initSysInfo() {
  const ua = navigator.userAgent;
  let os = "Linux";
  if (ua.indexOf("Win") !== -1) os = "Windows";
  else if (ua.indexOf("Mac") !== -1) os = "MacOS";
  document.getElementById("os-val").textContent = os;
  if (os === "Linux")
    document.getElementById("distro-val").textContent = "Arch";
  else document.getElementById("distro-container").classList.add("hidden");

  let browser;
  if (ua.includes("Firefox")) browser = "Firefox";
  else if (ua.includes("Edg/")) browser = "Edge";
  else if (ua.includes("Chrome")) browser = "Chrome";
  else browser = "Safari";
  document.getElementById("browser-val").textContent = browser;

  if (
    browser === "Chrome" &&
    navigator.brave &&
    typeof navigator.brave.isBrave === "function"
  ) {
    try {
      if (await navigator.brave.isBrave()) {
        document.getElementById("browser-val").textContent = "Brave";
      }
    } catch (_) {}
  }
}

function renderBrowserPopover(popover) {
  addPopoverTitle(popover, "Browser Details");
  const kv = document.createElement("div");
  kv.className = "popover-kv";
  addKvRow(kv, "Viewport", `${window.innerWidth} \u00d7 ${window.innerHeight}`);
  addKvRow(kv, "Language", navigator.language || "Unknown");
  popover.appendChild(kv);

  const uaLabel = document.createElement("div");
  uaLabel.className = "kv-label";
  uaLabel.style.marginTop = "8px";
  uaLabel.textContent = "User Agent";
  popover.appendChild(uaLabel);

  const ua = document.createElement("div");
  ua.className = "popover-ua";
  ua.textContent = navigator.userAgent;
  popover.appendChild(ua);
}

/* ---- UPTIME ---- */
const pageLoadTime = performance.timeOrigin ?? Date.now();

function updateUptime() {
  const el = document.getElementById("uptime-val");
  if (!el) return;
  const totalSec = Math.floor((Date.now() - pageLoadTime) / 1000);
  const days = Math.floor(totalSec / 86400);
  const hours = Math.floor((totalSec % 86400) / 3600);
  const mins = Math.floor((totalSec % 3600) / 60);
  const secs = totalSec % 60;

  let text;
  if (days > 0) text = `${days}d ${hours}h ${mins}m`;
  else if (hours > 0) text = `${hours}h ${mins}m`;
  else if (mins > 0) text = `${mins}m ${secs}s`;
  else text = `${secs}s`;

  el.textContent = text;

  if (activePopover === "uptime") {
    renderPopoverContent("uptime", document.getElementById("info-popover"));
    if (activePopoverTrigger) positionPopover(activePopoverTrigger);
  }
}

function renderUptimePopover(popover) {
  addPopoverTitle(popover, "Session Uptime");
  const kv = document.createElement("div");
  kv.className = "popover-kv";
  addKvRow(kv, "Page loaded", new Date(pageLoadTime).toLocaleString());
  addKvRow(
    kv,
    "Elapsed",
    document.getElementById("uptime-val")?.textContent ?? "\u2014",
  );
  popover.appendChild(kv);
}

/* ---- BATTERY ---- */
let currentBattery = null;

async function initBattery() {
  const container = document.getElementById("battery-container");
  if (!("getBattery" in navigator)) {
    container.classList.add("hidden");
    return;
  }
  try {
    const battery = await navigator.getBattery();
    currentBattery = battery;
    const valEl = document.getElementById("battery-val");

    function render() {
      const pct = Math.round(battery.level * 100);
      const color = battery.charging
        ? "var(--aqua)"
        : pct >= 50
          ? "var(--green)"
          : pct >= 20
            ? "var(--yellow)"
            : "var(--red)";
      const bolt = battery.charging ? " \u26a1" : "";
      valEl.innerHTML = `<span style="color:${color}">${pct}%${bolt}</span>`;
      if (activePopover === "battery") {
        renderPopoverContent(
          "battery",
          document.getElementById("info-popover"),
        );
        if (activePopoverTrigger) positionPopover(activePopoverTrigger);
      }
    }

    render();
    battery.addEventListener("levelchange", render);
    battery.addEventListener("chargingchange", render);
  } catch (_) {
    container.classList.add("hidden");
  }
}

function formatBatteryTime(seconds) {
  if (seconds == null || isNaN(seconds) || seconds === Infinity) {
    return "Calculating\u2026";
  }
  if (seconds <= 0) return "\u2014";
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return h > 0 ? `${h}h ${m}m` : `${m}m`;
}

function renderBatteryPopover(popover) {
  addPopoverTitle(popover, "Battery");
  if (!currentBattery) {
    const empty = document.createElement("div");
    empty.className = "popover-empty";
    empty.textContent = "Unavailable";
    popover.appendChild(empty);
    return;
  }
  const kv = document.createElement("div");
  kv.className = "popover-kv";
  addKvRow(kv, "Level", `${Math.round(currentBattery.level * 100)}%`);
  addKvRow(kv, "Status", currentBattery.charging ? "Charging" : "Discharging");
  addKvRow(
    kv,
    currentBattery.charging ? "Until full" : "Remaining",
    formatBatteryTime(
      currentBattery.charging
        ? currentBattery.chargingTime
        : currentBattery.dischargingTime,
    ),
  );
  popover.appendChild(kv);
}

/* ---- CLOCK POPOVER (Calendar & Alarm) ---- */
function renderClockPopover(popover) {
  addPopoverTitle(popover, "Calendar & Clock");
  const kv = document.createElement("div");
  kv.className = "popover-kv";
  kv.id = "world-clock-rows";
  popover.appendChild(kv);
  updateWorldClockRows();

  const calendarContainer = document.createElement("div");
  popover.appendChild(calendarContainer);
  renderCalendar(calendarContainer);

  const alarmContainer = document.createElement("div");
  popover.appendChild(alarmContainer);
  renderUnifiedAlarm(alarmContainer);
}

function updateWorldClockRows() {
  const kv = document.getElementById("world-clock-rows");
  if (!kv) return;
  kv.textContent = "";
  const now = new Date();
  WORLD_CLOCK_ZONES.forEach(({ label, zone }) => {
    let time;
    try {
      time = new Intl.DateTimeFormat(undefined, {
        hour: "2-digit",
        minute: "2-digit",
        timeZone: zone,
      }).format(now);
    } catch (_) {
      time = "\u2014";
    }
    addKvRow(kv, label, time);
  });
}

/* ---- LINK HINTS ---- */
const HINT_CHARS = "asdfghjklqwertyuiopzxcvbnm";
const hintOverlayEl = document.getElementById("hint-overlay");
let hintModeActive = false;
let hintTargets = [];
let hintBuffer = "";

function generateHintLabels(count) {
  const chars = HINT_CHARS.split("");
  if (count <= chars.length) return chars.slice(0, count);
  const labels = [];
  for (let i = 0; i < chars.length && labels.length < count; i++) {
    for (let j = 0; j < chars.length && labels.length < count; j++) {
      labels.push(chars[i] + chars[j]);
    }
  }
  return labels;
}

function activateHintMode() {
  const links = Array.from(document.querySelectorAll(".category a[href]"));
  if (!links.length) return;

  hintModeActive = true;
  hintBuffer = "";
  const labels = generateHintLabels(links.length);

  hintTargets = links.map((el, i) => {
    const rect = el.getBoundingClientRect();
    const badgeEl = document.createElement("span");
    badgeEl.className = "hint-badge";
    badgeEl.textContent = labels[i].toUpperCase();
    badgeEl.style.left = `${rect.left}px`;
    badgeEl.style.top = `${rect.top + rect.height / 2}px`;
    hintOverlayEl.appendChild(badgeEl);
    return { el, label: labels[i], badgeEl };
  });
}

function deactivateHintMode() {
  hintModeActive = false;
  hintBuffer = "";
  hintOverlayEl.innerHTML = "";
  hintTargets = [];
}

function refreshHintVisibility() {
  hintTargets.forEach(({ label, badgeEl }) => {
    badgeEl.style.display = label.startsWith(hintBuffer) ? "" : "none";
    badgeEl.classList.toggle(
      "hint-matched",
      hintBuffer.length > 0 && label.startsWith(hintBuffer),
    );
  });
}

function navigateToHint(target, forceNewTab) {
  const url = target.el.href;
  const newTab = forceNewTab || target.el.target === "_blank";
  deactivateHintMode();
  if (newTab) window.open(url, "_blank", "noopener,noreferrer");
  else window.location.href = url;
}

function handleHintKeydown(e) {
  if (e.key === "Escape") {
    e.preventDefault();
    deactivateHintMode();
    return;
  }
  if (e.key === "Backspace") {
    e.preventDefault();
    hintBuffer = hintBuffer.slice(0, -1);
    refreshHintVisibility();
    return;
  }
  if (e.ctrlKey || e.metaKey || e.altKey) return;
  if (e.key.length !== 1 || !/[a-zA-Z]/.test(e.key)) return;

  e.preventDefault();
  const openInNewTab = e.shiftKey;
  const nextBuffer = hintBuffer + e.key.toLowerCase();
  const matches = hintTargets.filter((t) => t.label.startsWith(nextBuffer));

  if (matches.length === 0) {
    hintBuffer = e.key.toLowerCase();
    const restarted = hintTargets.filter((t) => t.label.startsWith(hintBuffer));
    if (restarted.length === 0) {
      hintBuffer = "";
      refreshHintVisibility();
      return;
    }
    refreshHintVisibility();
    if (restarted.length === 1 && restarted[0].label === hintBuffer) {
      navigateToHint(restarted[0], openInNewTab);
    }
    return;
  }

  hintBuffer = nextBuffer;
  refreshHintVisibility();
  if (matches.length === 1 && matches[0].label === hintBuffer) {
    navigateToHint(matches[0], openInNewTab);
  }
}

window.addEventListener("resize", () => {
  if (hintModeActive) deactivateHintMode();
  if (activePopover && activePopoverTrigger) {
    positionPopover(activePopoverTrigger);
  }
});

/* ---- BANG SEARCH SHORTCUTS ---- */
const BANG_MAP = {
  gh: {
    base: "https://github.com",
    search: "https://github.com/search?q=",
    label: "GitHub",
  },
  gl: {
    base: "https://gitlab.com",
    search: "https://gitlab.com/search?search=",
    label: "GitLab",
  },
  so: {
    base: "https://stackoverflow.com",
    search: "https://stackoverflow.com/search?q=",
    label: "Stack Overflow",
  },
  yt: {
    base: "https://youtube.com",
    search: "https://www.youtube.com/results?search_query=",
    label: "YouTube",
  },
  tw: {
    base: "https://twitch.tv",
    search: "https://www.twitch.tv/search?term=",
    label: "Twitch",
  },
  rd: {
    base: "https://www.reddit.com",
    search: "https://www.reddit.com/search/?q=",
    label: "Reddit",
  },
  g: {
    base: "https://www.google.com",
    search: "https://www.google.com/search?q=",
    label: "Google",
  },
  ddg: {
    base: "https://duckduckgo.com",
    search: "https://duckduckgo.com/?q=",
    label: "DuckDuckGo",
  },
  w: {
    base: "https://en.wikipedia.org",
    search: "https://en.wikipedia.org/wiki/Special:Search?search=",
    label: "Wikipedia",
  },
  npm: {
    base: "https://www.npmjs.com",
    search: "https://www.npmjs.com/search?q=",
    label: "npm",
  },
  pypi: {
    base: "https://pypi.org",
    search: "https://pypi.org/search/?q=",
    label: "PyPI",
  },
  aw: {
    base: "https://wiki.archlinux.org",
    search: "https://wiki.archlinux.org/index.php?search=",
    label: "Arch Wiki",
  },
};

function populateBangList() {
  const container = document.getElementById("bang-list");
  container.innerHTML = Object.entries(BANG_MAP)
    .map(
      ([bang, { label }]) => `
        <div class="kb-row">
          <span class="kb-key">!${bang}</span>
          <span class="kb-desc">${label}</span>
        </div>`,
    )
    .join("");
}

function handleSearchSubmit(e) {
  const raw = searchInput.value.trim();
  if (!raw) return;

  const match = raw.match(/^!(\S+)(?:\s+(.*))?$/);
  if (!match) return;

  const bang = match[1].toLowerCase();
  const target = BANG_MAP[bang];

  if (!target) {
    e.preventDefault();
    return;
  }

  e.preventDefault();
  const query = (match[2] || "").trim();
  window.location.href = query
    ? target.search + encodeURIComponent(query)
    : target.base;
}

const searchInput = document.getElementById("searchInput");
searchInput.addEventListener("input", () => {
  const value = searchInput.value.trim();
  const bangMatch = value.match(/^!(\S*)/);
  if (bangMatch && bangMatch[1] && !BANG_MAP[bangMatch[1].toLowerCase()]) {
    searchInput.setCustomValidity(
      "Unknown shortcut. Use a supported !bang or remove the !.",
    );
  } else {
    searchInput.setCustomValidity("");
  }
});

/* ---- KEYBIND OVERLAY ---- */
const overlay = document.getElementById("keybind-overlay");
function toggleOverlay() {
  overlay.classList.toggle("visible");
}
overlay.addEventListener("click", (e) => {
  if (e.target === overlay) overlay.classList.remove("visible");
});

/* ---- INIT ---- */
loadTextFiles();
initSysInfo();
initWeather();
initBattery();
measurePing();
updateUptime();

// If alarm is active and target is in the future, schedule it
if (alarmState.active && alarmState.targetEpoch > Date.now()) {
  scheduleUnifiedAlarm();
} else if (alarmState.active && alarmState.targetEpoch <= Date.now()) {
  alarmState.active = false;
  saveUnifiedAlarm();
}

let pingTimer = setInterval(measurePing, 30000);
document.addEventListener("visibilitychange", () => {
  if (document.hidden) {
    clearInterval(pingTimer);
    matrixRainVisibility.pause();
  } else {
    measurePing();
    pingTimer = setInterval(measurePing, 30000);
    matrixRainVisibility.resume();
    scheduleUnifiedAlarm();
  }
});

setInterval(() => {
  updateClock();
  updateUptime();
  if (
    alarmState.active &&
    alarmState.targetEpoch &&
    Date.now() >= alarmState.targetEpoch
  ) {
    triggerUnifiedAlarm();
    scheduleUnifiedAlarm();
  }
  if (activePopover === "clock") {
    const statusEl = document.getElementById("alarm-status");
    if (statusEl) updateAlarmUI();
  }
}, 1000);

document
  .getElementById("searchForm")
  .addEventListener("submit", handleSearchSubmit);
populateBangList();
window.onload = () => searchInput.focus();

const popoverTriggers = [
  { key: "browser", el: document.getElementById("browser-container") },
  { key: "weather", el: document.getElementById("weather-container") },
  { key: "ping", el: document.getElementById("ping-container") },
  { key: "uptime", el: document.getElementById("uptime-container") },
  { key: "battery", el: document.getElementById("battery-container") },
  { key: "clock", el: document.getElementById("datetime") },
];
popoverTriggers.forEach(({ key, el }) => {
  el.addEventListener("click", () => openPopover(key, el));
});

document.addEventListener("click", (e) => {
  if (!activePopover) return;
  const popover = document.getElementById("info-popover");
  if (popover.contains(e.target)) return;
  if (popoverTriggers.some(({ el }) => el.contains(e.target))) return;
  closePopover();
});

document.addEventListener("keydown", (e) => {
  const active = document.activeElement;
  const inSearch = active === searchInput;

  if (hintModeActive) {
    handleHintKeydown(e);
    return;
  }

  if (e.key === "Escape") {
    stopAlarmRinging();
    if (overlay.classList.contains("visible")) {
      overlay.classList.remove("visible");
    }
    closePopover();
    if (inSearch) {
      searchInput.value = "";
      searchInput.blur();
    }
    return;
  }
  if (e.key === "?" && !inSearch) {
    e.preventDefault();
    toggleOverlay();
    return;
  }
  if (e.key === "/" && !inSearch) {
    e.preventDefault();
    searchInput.focus();
    return;
  }
  if (e.key === "f" && !inSearch && !overlay.classList.contains("visible")) {
    e.preventDefault();
    activateHintMode();
    return;
  }
  if (e.key === "n" && !inSearch && !overlay.classList.contains("visible")) {
    e.preventDefault();
    rerollGreeting();
  }
});
