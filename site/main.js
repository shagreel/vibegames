/* Vibe Games — landing page behaviour.
   Four jobs: reveal things as they scroll in, drive the per-section backdrop so
   each game blooms as it reaches the middle of the screen, and — on the one page
   that has them — run the ways to help: the feedback box, the share button and
   the copy-the-handle button.
   No dependencies. */

(function () {
  "use strict";

  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ── reveal on entry ─────────────────────────────────────────────────── */

  var revealables = document.querySelectorAll(".reveal, .reveal-up");

  if (!("IntersectionObserver" in window)) {
    // Very old browser: show everything rather than hiding it forever.
    revealables.forEach(function (el) { el.classList.add("is-visible"); });
  } else {
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      });
    }, { threshold: 0.18, rootMargin: "0px 0px -6% 0px" });

    revealables.forEach(function (el) { observer.observe(el); });
  }

  /* ── ways to help ────────────────────────────────────────────────────────
     Only on that page, so the landing page pays nothing for the lookups.
     Share uses the OS sheet where there is one and copies the link where
     there is not; both buttons say what happened either way. */

  var PLAY_URL = "https://play.vibegames.party";
  var VENMO_HANDLE = "@chill-gelato";

  /* The browser version logs its donation taps and shares under these names, so
     the page that the *app* sends people to logs them the same way and the whole
     funnel lands in one report rather than two. */
  function track(name, params) {
    if (typeof window.gtag !== "function") return;
    try {
      window.gtag("event", name, params || {});
    } catch (e) {
      // A counter must never be able to stop somebody helping.
    }
  }

  var donateRow = document.querySelector("[data-donation]");

  if (donateRow) {
    donateRow.addEventListener("click", function () { track("donation_tap"); });
  }

  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text);
    }
    // Fallback for an old browser or a non-secure context.
    return new Promise(function (resolve, reject) {
      var field = document.createElement("textarea");
      field.value = text;
      field.setAttribute("readonly", "");
      field.style.position = "fixed";
      field.style.opacity = "0";
      document.body.appendChild(field);
      field.select();
      var ok = false;
      try { ok = document.execCommand("copy"); } catch (e) { ok = false; }
      document.body.removeChild(field);
      ok ? resolve() : reject(new Error("copy failed"));
    });
  }

  function settle(el, text) {
    if (!el) return;
    var original = el.textContent;
    el.textContent = text;
    window.setTimeout(function () { el.textContent = original; }, 2200);
  }

  var shareRow = document.querySelector("[data-share]");

  if (shareRow) {
    shareRow.addEventListener("click", function () {
      var label = shareRow.querySelector("[data-share-label]");

      if (navigator.share) {
        navigator.share({ title: "Vibe Games", text: "Party games for the phone in your pocket.", url: PLAY_URL })
          .then(function () {
            track("share", { content_type: "app", item_id: "vibe-games" });
          })
          .catch(function () { /* dismissed, or nothing to share with */ });
        return;
      }

      copyText(PLAY_URL).then(function () {
        settle(label, "Link copied");
        track("share", { content_type: "app", item_id: "vibe-games", method: "copy_link" });
      }).catch(function () {
        settle(label, PLAY_URL);
      });
    });
  }

  var copyButton = document.querySelector("[data-copy-venmo]");

  if (copyButton) {
    copyButton.addEventListener("click", function () {
      copyText(VENMO_HANDLE).then(function () {
        settle(copyButton, "Copied " + VENMO_HANDLE);
      }).catch(function () {
        settle(copyButton, "Copy failed — it is " + VENMO_HANDLE);
      });
    });
  }

  /* ── the feedback box ────────────────────────────────────────────────────
     The same inbox the browser version writes to: a write-only node in the
     Realtime Database, with no token here and none anywhere else — a token in a
     client is a token anyone can read out of it. The rules are what keep it
     honest (text of 4 to 2000 characters, a source of "web"), and a scheduled
     drain turns an entry into an issue on the repository.

     `fetch` rather than the Firebase SDK: this page has no build step and no
     dependencies, and one POST is not worth a hundred kilobytes of client. */

  var FEEDBACK_URL = "https://vibe-words-party-default-rtdb.firebaseio.com/feedback.json";
  var MIN_FEEDBACK = 4;
  var MAX_FEEDBACK = 2000;

  var feedback = document.querySelector("[data-feedback]");

  if (feedback) {
    var form = feedback.querySelector("[data-feedback-form]");
    var field = feedback.querySelector("[data-feedback-text]");
    var send = feedback.querySelector("[data-feedback-send]");
    var problem = feedback.querySelector("[data-feedback-problem]");
    var sent = feedback.querySelector("[data-feedback-sent]");

    var note = function () { return field.value.trim(); };

    var fail = function (message) {
      problem.textContent = message;
      problem.hidden = false;
      send.disabled = false;
      send.textContent = "Send";
    };

    field.addEventListener("input", function () {
      send.disabled = note().length < MIN_FEEDBACK;
    });

    form.addEventListener("submit", function (event) {
      event.preventDefault();

      var text = note();
      if (text.length < MIN_FEEDBACK) return fail("Please write a little more.");
      if (text.length > MAX_FEEDBACK) {
        return fail("Please keep it under " + MAX_FEEDBACK + " characters.");
      }

      send.disabled = true;
      send.textContent = "Sending…";
      problem.hidden = true;

      fetch(FEEDBACK_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text: text, source: "web", createdAt: Date.now() })
      }).then(function (response) {
        if (!response.ok) throw new Error("HTTP " + response.status);
        // Only on the way through: "thank you" for a note that went nowhere is
        // worse than an error, because the person then believes they were heard.
        form.hidden = true;
        sent.hidden = false;
        track("feedback_sent", {});
      }).catch(function () {
        fail("That did not go through. Please try again in a moment.");
      });
    });
  }

  /* ── backdrop bloom ──────────────────────────────────────────────────── */

  var games = Array.prototype.slice.call(document.querySelectorAll(".game"));

  if (reduceMotion || games.length === 0) return;

  var ticking = false;

  function update() {
    ticking = false;
    var viewportCentre = window.innerHeight / 2;

    games.forEach(function (game) {
      var rect = game.getBoundingClientRect();
      var centre = rect.top + rect.height / 2;
      var reach = viewportCentre + rect.height / 2;

      // 1 when the section is centred, 0 once it is a full section away.
      var progress = 1 - Math.min(1, Math.abs(centre - viewportCentre) / reach);
      game.style.setProperty("--p", progress.toFixed(3));
    });
  }

  function requestUpdate() {
    if (ticking) return;
    ticking = true;
    window.requestAnimationFrame(update);
  }

  window.addEventListener("scroll", requestUpdate, { passive: true });
  window.addEventListener("resize", requestUpdate);
  update();
})();
