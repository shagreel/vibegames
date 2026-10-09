/* Vibe Games — landing page behaviour.
   Two jobs: reveal things as they scroll in, and drive the per-section
   backdrop so each game blooms as it reaches the middle of the screen.
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
