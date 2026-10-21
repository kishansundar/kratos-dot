// ==UserScript==
// @name        YouTube: position and length for the desktop's media controls
// @namespace   nixdesk
// @version     1.2
// @description YouTube's player clears the media session's position after every seek it completes, its own small ones
//              included (setPositionState() with nothing); Zen (Firefox) then tells the desktop no length and no
//              position, and the bar's progress line and the Now Playing times stay empty. This mirrors the video's
//              state into the media session, reports its position when something changes (play, pause, seek, speed,
//              a new video) and answers each clear with it. Zen runs the position on by itself in between; every
//              report is a Seeked signal on the bus, so nothing is reported on a timer.
// @match       https://www.youtube.com/*
// @match       https://music.youtube.com/*
// @grant       none
// @run-at      document-start
// ==/UserScript==

(() => {
  const session = navigator.mediaSession;
  if (!session) return;

  const timed = v => v.duration > 0 && isFinite(v.duration);
  let video = null;                                   // the element the last media event came from

  const setPosition = session.setPositionState.bind(session);   // the browser's own, before the guard below
  const report = v => {
    if (!v || !timed(v)) return;
    try {
      setPosition({ duration: v.duration, playbackRate: v.playbackRate || 1,
                    position: Math.min(v.currentTime, v.duration) });
    } catch (e) { /* a position past the end while the next video loads: its own events report it again */ }
  };

  // The video's own state, then its position.
  const mirror = v => { session.playbackState = v.paused ? "paused" : "playing"; report(v); };

  // After a jump or a new video Zen re-reads the position on a state change: flip the state and back (the video keeps
  // playing). A live stream has no position of ours to re-read.
  const announce = v => {
    report(v);
    if (v.paused || !timed(v)) { mirror(v); return; }
    session.playbackState = "paused";
    setTimeout(() => mirror(v), 50);
  };

  // YouTube's player calls setPositionState() with nothing after every seek it completes (unless an experiment of its
  // is on), and Zen then drops the length and position until the next report. While a video with a length is loaded,
  // a clear reports that video instead. A live stream's state (an endless duration) passes through.
  const guard = function (state) {
    if (!(state && state.duration > 0) && video && timed(video)) { report(video); return; }
    return setPosition(state);
  };
  const page = window.wrappedJSObject;                // Firefox, when Violentmonkey runs this as a content script
  if (page && typeof exportFunction === "function")
    exportFunction(guard, page.navigator.mediaSession, { defineAs: "setPositionState" });
  else
    session.setPositionState = guard;

  // Media events do not bubble: the capture phase sees every element, the ones YouTube swaps in and the next video
  // loaded into the same one (durationchange) included. Muted ones (the home page's hover previews) are left out.
  const on = (types, act) => {
    for (const type of types) document.addEventListener(type, e => {
      const v = e.target;
      if (!(v instanceof HTMLMediaElement) || v.muted) return;
      video = v;
      act(v);
    }, true);
  };
  on(["play", "playing", "pause", "ended"], mirror);
  on(["seeked", "ratechange", "durationchange"], announce);
})();
