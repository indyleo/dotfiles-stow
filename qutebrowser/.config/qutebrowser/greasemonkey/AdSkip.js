// ==UserScript==
// @name         YouTube Mute and Skip Ads
// @namespace    https://github.com/ion1/userscripts
// @version      0.0.28
// @author       ion
// @description  Mutes, blurs and skips ads on YouTube. Speeds up ad playback. Clicks "yes" on "are you there?" on YouTube Music.
// @license      MIT
// @icon         https://www.google.com/s2/favicons?sz=64&domain=youtube.com
// @homepage     https://github.com/ion1/userscripts/tree/master/packages/youtube-mute-skip-ads
// @homepageURL  https://github.com/ion1/userscripts/tree/master/packages/youtube-mute-skip-ads
// @match        *://www.youtube.com/*
// @match        *://music.youtube.com/*
// @grant        GM_addStyle
// @run-at       document-body
// @downloadURL https://update.greasyfork.org/scripts/461341/YouTube%20Mute%20and%20Skip%20Ads.user.js
// @updateURL https://update.greasyfork.org/scripts/461341/YouTube%20Mute%20and%20Skip%20Ads.meta.js
// ==/UserScript==

((n) => {
  if (typeof GM_addStyle == "function") {
    GM_addStyle(n);
    return;
  }
  const e = document.createElement("style");
  (e.textContent = n), document.head.append(e);
})(` /* Keep these in sync with the watchers. */
#movie_player
  :is(.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-skip-ad-button) {
  anchor-name: --youtube-mute-skip-ads-unclickable-button;
}

body:has(
    #movie_player
      :is(
        .ytp-ad-skip-button,
        .ytp-ad-skip-button-modern,
        .ytp-skip-ad-button
      ):not([style*="display: none"], [aria-hidden="true"])
  )::after {
  content: "\u{1D606}\u{1D5FC}\u{1D602}\u{1D601}\u{1D602}\u{1D5EF}\u{1D5F2}-\u{1D5FA}\u{1D602}\u{1D601}\u{1D5F2}-\u{1D600}\u{1D5F8}\u{1D5F6}\u{1D5FD}-\u{1D5EE}\u{1D5F1}\u{1D600}\\A\\A"
    "Unfortunately, YouTube has started to block automated clicks based on isTrusted being false.\\A\\A"
    "Please click on the skip button manually.";
  white-space: pre-line;
  pointer-events: none;
  z-index: 9999;
  position: fixed;
  position-anchor: --youtube-mute-skip-ads-unclickable-button;
  padding: 1.5em;
  border-radius: 1.5em;
  margin-bottom: 1em;
  bottom: anchor(--youtube-mute-skip-ads-unclickable-button top);
  right: anchor(--youtube-mute-skip-ads-unclickable-button right);
  max-width: 25em;
  font-size: 1.4rem;
  line-height: 2rem;
  font-weight: 400;
  color: rgb(240 240 240);
  background-color: rgb(0 0 0 / 0.7);
  backdrop-filter: blur(10px);
  animation: fade-in 3s linear;
}

@keyframes fade-in {
  0% {
    opacity: 0;
  }
  67% {
    opacity: 0;
  }
  100% {
    opacity: 1;
  }
}

#movie_player.ad-showing video {
  filter: blur(100px) opacity(0.25) grayscale(0.5);
}

#movie_player.ad-showing .ytp-title,
#movie_player.ad-showing .ytp-title-channel,
.ytp-visit-advertiser-link,
.ytp-ad-visit-advertiser-button,
ytmusic-app:has(#movie_player.ad-showing)
  ytmusic-player-bar
  :is(.title, .subtitle) {
  filter: blur(4px) opacity(0.5) grayscale(0.5);
  transition: 0.05s filter linear;
}

:is(#movie_player.ad-showing .ytp-title,#movie_player.ad-showing .ytp-title-channel,.ytp-visit-advertiser-link,.ytp-ad-visit-advertiser-button,ytmusic-app:has(#movie_player.ad-showing) ytmusic-player-bar :is(.title,.subtitle)):is(:hover,:focus-within) {
    filter: none;
  }

/* These popups are showing up on top of the video with a hidden dismiss button
 * since 2024-09-25.
 */
.ytp-suggested-action-badge {
  visibility: hidden !important;
}

#movie_player.ad-showing .caption-window,
.ytp-ad-player-overlay-flyout-cta,
.ytp-ad-player-overlay-layout__player-card-container, /* Seen since 2024-04-06. */
.ytp-ad-action-interstitial-slot, /* Added on 2024-08-25. */
ytd-action-companion-ad-renderer,
ytd-display-ad-renderer,
ytd-ad-slot-renderer,
ytd-promoted-sparkles-web-renderer,
ytd-player-legacy-desktop-watch-ads-renderer,
ytd-engagement-panel-section-list-renderer[target-id="engagement-panel-ads"],
ytd-merch-shelf-renderer {
  filter: blur(10px) opacity(0.25) grayscale(0.5);
  transition: 0.05s filter linear;
}

:is(#movie_player.ad-showing .caption-window,.ytp-ad-player-overlay-flyout-cta,.ytp-ad-player-overlay-layout__player-card-container,.ytp-ad-action-interstitial-slot,ytd-action-companion-ad-renderer,ytd-display-ad-renderer,ytd-ad-slot-renderer,ytd-promoted-sparkles-web-renderer,ytd-player-legacy-desktop-watch-ads-renderer,ytd-engagement-panel-section-list-renderer[target-id="engagement-panel-ads"],ytd-merch-shelf-renderer):is(:hover,:focus-within) {
    filter: none;
  }

.ytp-ad-action-interstitial-background-container /* Added on 2024-08-25. */ {
  /* An image ad in place of the video. */
  filter: blur(10px) opacity(0.25) grayscale(0.5);
} `);

(function () {
  "use strict";

  const logPrefix = "youtube-mute-skip-ads:";
  class Watcher {
    name;
    element;
    #onCreatedCallbacks;
    #onRemovedCallbacks;
    #nodeObserver;
    #nodeWatchers;
    #textObserver;
    #onTextChangedCallbacks;
    #onAttrChangedCallbacks;
    visibilityAncestor;
    #visibilityObserver;
    #isVisible;
    #visibilityWatchers;
    constructor(name, elem) {
      this.name = name;
      this.element = null;
      this.#onCreatedCallbacks = [];
      this.#onRemovedCallbacks = [];
      this.#nodeObserver = null;
      this.#nodeWatchers = [];
      this.#textObserver = null;
      this.#onTextChangedCallbacks = [];
      this.#onAttrChangedCallbacks = [];
      this.visibilityAncestor = null;
      this.#visibilityObserver = null;
      this.#isVisible = null;
      this.#visibilityWatchers = [];
      if (elem != null) {
        this.#connect(elem);
      }
    }
    #assertElement() {
      if (this.element == null) {
        throw new Error(`Watcher not connected to an element`);
      }
      return this.element;
    }
    #assertVisibilityAncestor() {
      if (this.visibilityAncestor == null) {
        throw new Error(`Watcher is missing a visibilityAncestor`);
      }
      return this.visibilityAncestor;
    }
    #connect(element, visibilityAncestor) {
      if (this.element != null) {
        if (this.element !== element) {
          console.error(
            logPrefix,
            `Watcher already connected to`,
            this.element,
            `while trying to connect to`,
            element,
          );
        }
        return;
      }
      this.element = element;
      this.visibilityAncestor = visibilityAncestor ?? null;
      for (const onCreatedCb of this.#onCreatedCallbacks) {
        const onRemovedCb = onCreatedCb(this.element);
        if (onRemovedCb) {
          this.#onRemovedCallbacks.push(onRemovedCb);
        }
      }
      for (const { selector, name, watcher: watcher2 } of this.#nodeWatchers) {
        for (const descElem of getDescendantsBy(this.element, selector, name)) {
          watcher2.#connect(descElem, this.element);
        }
      }
      for (const callback of this.#onTextChangedCallbacks) {
        callback(this.element, this.element.textContent);
      }
      for (const { name, callback } of this.#onAttrChangedCallbacks) {
        callback(this.element, this.element.getAttribute(name));
      }
      this.#registerNodeObserver();
      this.#registerTextObserver();
      this.#registerAttrObservers();
      this.#registerVisibilityObserver();
    }
    #disconnect() {
      if (this.element == null) {
        return;
      }
      for (const child of this.#nodeWatchers) {
        child.watcher.#disconnect();
      }
      for (const callback of this.#onTextChangedCallbacks) {
        callback(this.element, void 0);
      }
      for (const { callback } of this.#onAttrChangedCallbacks) {
        callback(this.element, void 0);
      }
      for (const child of this.#visibilityWatchers) {
        child.#disconnect();
      }
      this.#deregisterNodeObserver();
      this.#deregisterTextObserver();
      this.#deregisterAttrObservers();
      this.#deregisterVisibilityObserver();
      while (this.#onRemovedCallbacks.length > 0) {
        const onRemovedCb = this.#onRemovedCallbacks.shift();
        onRemovedCb();
      }
      this.element = null;
    }
    #registerNodeObserver() {
      if (this.#nodeObserver != null) {
        return;
      }
      if (this.#nodeWatchers.length === 0) {
        return;
      }
      const elem = this.#assertElement();
      this.#nodeObserver = new MutationObserver((mutations) => {
        for (const mut of mutations) {
          for (const node of mut.addedNodes) {
            for (const { selector, name, watcher: watcher2 } of this
              .#nodeWatchers) {
              for (const descElem of getSelfOrDescendantsBy(
                node,
                selector,
                name,
              )) {
                watcher2.#connect(descElem, elem);
              }
            }
          }
          for (const node of mut.removedNodes) {
            for (const { selector, name, watcher: watcher2 } of this
              .#nodeWatchers) {
              for (const _descElem of getSelfOrDescendantsBy(
                node,
                selector,
                name,
              )) {
                watcher2.#disconnect();
              }
            }
          }
        }
      });
      this.#nodeObserver.observe(elem, {
        subtree: true,
        childList: true,
      });
    }
    #registerTextObserver() {
      if (this.#textObserver != null) {
        return;
      }
      if (this.#onTextChangedCallbacks.length === 0) {
        return;
      }
      const elem = this.#assertElement();
      this.#textObserver = new MutationObserver((_mutations) => {
        for (const callback of this.#onTextChangedCallbacks) {
          callback(elem, elem.textContent);
        }
      });
      this.#textObserver.observe(elem, {
        subtree: true,
        // This is needed when elements are replaced to update their text.
        childList: true,
        characterData: true,
      });
    }
    #registerAttrObservers() {
      const elem = this.#assertElement();
      for (const handler of this.#onAttrChangedCallbacks) {
        if (handler.observer != null) {
          continue;
        }
        const { name, callback } = handler;
        handler.observer = new MutationObserver((_mutations) => {
          callback(elem, elem.getAttribute(name));
        });
        handler.observer.observe(elem, {
          attributes: true,
          attributeFilter: [name],
        });
      }
    }
    #registerVisibilityObserver() {
      if (this.#visibilityObserver != null) {
        return;
      }
      if (this.#visibilityWatchers.length === 0) {
        return;
      }
      this.#isVisible = false;
      const elem = this.#assertElement();
      const visibilityAncestor = this.#assertVisibilityAncestor();
      this.#visibilityObserver = new IntersectionObserver(
        (entries) => {
          const oldVisible = this.#isVisible;
          for (const entry of entries) {
            this.#isVisible = entry.isIntersecting;
          }
          if (this.#isVisible !== oldVisible) {
            if (this.#isVisible) {
              for (const watcher2 of this.#visibilityWatchers) {
                watcher2.#connect(elem, visibilityAncestor);
              }
            } else {
              for (const watcher2 of this.#visibilityWatchers) {
                watcher2.#disconnect();
              }
            }
          }
        },
        {
          root: visibilityAncestor,
        },
      );
      this.#visibilityObserver.observe(elem);
    }
    #deregisterNodeObserver() {
      if (this.#nodeObserver == null) {
        return;
      }
      this.#nodeObserver.disconnect();
      this.#nodeObserver = null;
    }
    #deregisterTextObserver() {
      if (this.#textObserver == null) {
        return;
      }
      this.#textObserver.disconnect();
      this.#textObserver = null;
    }
    #deregisterAttrObservers() {
      for (const handler of this.#onAttrChangedCallbacks) {
        if (handler.observer == null) {
          continue;
        }
        handler.observer.disconnect();
        handler.observer = null;
      }
    }
    #deregisterVisibilityObserver() {
      if (this.#visibilityObserver == null) {
        return;
      }
      this.#visibilityObserver.disconnect();
      this.#visibilityObserver = null;
      this.#isVisible = null;
    }
    onCreated(onCreatedCb) {
      this.#onCreatedCallbacks.push(onCreatedCb);
      if (this.element != null) {
        const onRemovedCb = onCreatedCb(this.element);
        if (onRemovedCb) {
          this.#onRemovedCallbacks.push(onRemovedCb);
        }
      }
      return this;
    }
    descendant(selector, name) {
      const watcher2 = new Watcher(`${this.name} → ${name}`);
      this.#nodeWatchers.push({ selector, name, watcher: watcher2 });
      if (this.element != null) {
        for (const descElem of getDescendantsBy(this.element, selector, name)) {
          watcher2.#connect(descElem, this.element);
        }
        this.#registerNodeObserver();
      }
      return watcher2;
    }
    id(idName) {
      return this.descendant("id", idName);
    }
    klass(className) {
      return this.descendant("class", className);
    }
    tag(tagName) {
      return this.descendant("tag", tagName);
    }
    visible() {
      const watcher2 = new Watcher(`${this.name} (visible)`);
      this.#visibilityWatchers.push(watcher2);
      if (this.element != null) {
        const visibilityAncestor = this.#assertVisibilityAncestor();
        if (this.#isVisible) {
          watcher2.#connect(this.element, visibilityAncestor);
        }
        this.#registerVisibilityObserver();
      }
      return watcher2;
    }
    /// `null` implies null textContent. `undefined` implies that the watcher is
    /// being disconnected.
    text(callback) {
      this.#onTextChangedCallbacks.push(callback);
      if (this.element != null) {
        callback(this.element, this.element.textContent);
        this.#registerTextObserver();
      }
      return this;
    }
    /// `null` implies no such attribute. `undefined` implies that the watcher is
    /// being disconnected.
    attr(name, callback) {
      this.#onAttrChangedCallbacks.push({ name, callback, observer: null });
      if (this.element != null) {
        callback(this.element, this.element.getAttribute(name));
        this.#registerAttrObservers();
      }
      return this;
    }
  }
  function getSelfOrDescendantsBy(node, selector, name) {
    if (!(node instanceof HTMLElement)) {
      return [];
    }
    if (selector === "id" || selector === "class" || selector === "tag") {
      if (
        (selector === "id" && node.id === name) ||
        (selector === "class" && node.classList.contains(name)) ||
        (selector === "tag" &&
          node.tagName.toLowerCase() === name.toLowerCase())
      ) {
        return [node];
      } else {
        return getDescendantsBy(node, selector, name);
      }
    } else {
      const impossible = selector;
      throw new Error(
        `Impossible selector type: ${JSON.stringify(impossible)}`,
      );
    }
  }
  function getDescendantsBy(node, selector, name) {
    if (!(node instanceof HTMLElement)) {
      return [];
    }
    let cssSelector = "";
    if (selector === "id") {
      cssSelector += "#";
    } else if (selector === "class") {
      cssSelector += ".";
    } else if (selector === "tag");
    else {
      const impossible = selector;
      throw new Error(
        `Impossible selector type: ${JSON.stringify(impossible)}`,
      );
    }
    cssSelector += CSS.escape(name);
    return Array.from(node.querySelectorAll(cssSelector));
  }
  const videoSelector = "#movie_player video";
  function getVideoElement() {
    const videoElem = document.querySelector(videoSelector);
    if (!(videoElem instanceof HTMLVideoElement)) {
      console.error(
        logPrefix,
        "Expected",
        JSON.stringify(videoSelector),
        "to be a video element, got:",
        videoElem?.cloneNode(true),
      );
      return null;
    }
    return videoElem;
  }
  function callMoviePlayerMethod(name, onSuccess, args) {
    try {
      const movieElem = document.getElementById("movie_player");
      if (movieElem == null) {
        console.warn(logPrefix, "movie_player element not found");
        return;
      }
      const method = Object.getOwnPropertyDescriptor(movieElem, name)?.value;
      if (method == null) {
        console.warn(
          logPrefix,
          `movie_player element has no ${JSON.stringify(name)} property`,
        );
        return;
      }
      if (!(typeof method === "function")) {
        console.warn(
          logPrefix,
          `movie_player element property ${JSON.stringify(name)} is not a function`,
        );
        return;
      }
      const result = method.apply(movieElem, args);
      if (onSuccess != null) {
        onSuccess(result);
      }
      return result;
    } catch (e) {
      console.warn(
        logPrefix,
        `movie_player method ${JSON.stringify(name)} failed:`,
        e,
      );
      return;
    }
  }
  function disableVisibilityChecks() {
    for (const eventName of ["visibilitychange", "blur", "focus"]) {
      document.addEventListener(
        eventName,
        (ev) => {
          ev.stopImmediatePropagation();
        },
        { capture: true },
      );
    }
    document.hasFocus = () => true;
    Object.defineProperties(document, {
      visibilityState: { value: "visible" },
      hidden: { value: false },
    });
  }
  function adIsPlaying(_elem) {
    console.info(logPrefix, "An ad is playing, muting and speeding up");
    const video = getVideoElement();
    if (video == null) {
      return;
    }
    const onRemovedCallbacks = [
      mute(video),
      speedup(video),
      cancelPlayback(video),
    ];
    return function onRemoved() {
      for (const callback of onRemovedCallbacks) {
        callback();
      }
    };
  }
  function mute(video) {
    console.debug(logPrefix, "Muting");
    video.muted = true;
    return unmute;
  }
  function unmute() {
    {
      return;
    }
  }
  function speedup(video) {
    for (let rate = 16; rate >= 2; rate /= 2) {
      try {
        video.playbackRate = rate;
        break;
      } catch (e) {
        console.debug(
          logPrefix,
          `Setting playback rate to`,
          rate,
          `failed:`,
          e,
        );
      }
    }
    return function onRemoved() {
      const originalRate = callMoviePlayerMethod("getPlaybackRate");
      if (
        originalRate == null ||
        typeof originalRate !== "number" ||
        isNaN(originalRate)
      ) {
        console.warn(
          logPrefix,
          `Restoring playback rate failed:`,
          `unable to query the current playback rate, got: ${JSON.stringify(originalRate)}.`,
          `Falling back to 1.`,
        );
        restorePlaybackRate(video, 1);
        return;
      }
      restorePlaybackRate(video, originalRate);
    };
  }
  function restorePlaybackRate(video, originalRate) {
    try {
      video.playbackRate = originalRate;
    } catch (e) {
      console.debug(
        logPrefix,
        `Restoring playback rate to`,
        originalRate,
        `failed:`,
        e,
      );
    }
  }
  function cancelPlayback(video) {
    let shouldResume = false;
    function doCancelPlayback() {
      console.info(logPrefix, "Attempting to cancel playback");
      callMoviePlayerMethod("cancelPlayback", () => {
        shouldResume = true;
      });
    }
    if (video.paused) {
      console.debug(
        logPrefix,
        "Ad paused, waiting for it to play before canceling playback",
      );
      video.addEventListener("play", doCancelPlayback);
    } else {
      doCancelPlayback();
    }
    return function onRemoved() {
      video.removeEventListener("play", doCancelPlayback);
      if (shouldResume) {
        resumePlaybackIfNotAtEnd();
      }
    };
  }
  function resumePlaybackIfNotAtEnd() {
    const currentTime = callMoviePlayerMethod("getCurrentTime");
    const duration = callMoviePlayerMethod("getDuration");
    const isAtLiveHead = callMoviePlayerMethod("isAtLiveHead");
    if (
      currentTime == null ||
      duration == null ||
      typeof currentTime !== "number" ||
      typeof duration !== "number" ||
      isNaN(currentTime) ||
      isNaN(duration)
    ) {
      console.warn(
        logPrefix,
        `movie_player methods getCurrentTime/getDuration failed, got time: ${JSON.stringify(currentTime)}, duration: ${JSON.stringify(duration)}`,
      );
      return;
    }
    if (isAtLiveHead == null || typeof isAtLiveHead !== "boolean") {
      console.warn(
        logPrefix,
        `movie_player method isAtLiveHead failed, got: ${JSON.stringify(isAtLiveHead)}`,
      );
      return;
    }
    const atEnd = duration - currentTime < 1;
    if (atEnd && !isAtLiveHead) {
      console.info(
        logPrefix,
        `Video is at the end (${currentTime}/${duration}), not attempting to resume playback`,
      );
      return;
    }
    console.info(logPrefix, "Attempting to resume playback");
    callMoviePlayerMethod("playVideo");
  }
  function click(description) {
    return (elem) => {
      if (elem.getAttribute("aria-hidden")) {
        console.info(logPrefix, "Not clicking (aria-hidden):", description);
      } else {
        console.info(logPrefix, "Clicking:", description);
        elem.click();
      }
    };
  }
  disableVisibilityChecks();
  const watcher = new Watcher("body", document.body);
  const adPlayerOverlayClasses = [
    "ytp-ad-player-overlay",
    "ytp-ad-player-overlay-layout",
    // Seen since 2024-04-06.
  ];
  for (const adPlayerOverlayClass of adPlayerOverlayClasses) {
    watcher.klass(adPlayerOverlayClass).onCreated(adIsPlaying);
  }
  const adSkipButtonClasses = [
    "ytp-ad-skip-button",
    "ytp-ad-skip-button-modern",
    // Seen since 2023-11-10.
    "ytp-skip-ad-button",
    // Seen since 2024-04-06.
  ];
  for (const adSkipButtonClass of adSkipButtonClasses) {
    watcher
      .id("movie_player")
      .klass(adSkipButtonClass)
      .visible()
      .attr("aria-hidden", (elem, value) => {
        if (value === null) {
          click(`skip (${adSkipButtonClass})`)(elem);
        }
      });
  }
  watcher
    .klass("ytp-ad-overlay-close-button")
    .visible()
    .onCreated(click("overlay close"));
  watcher
    .tag("ytmusic-you-there-renderer")
    .tag("button")
    .visible()
    .onCreated(click("are-you-there"));
})();
