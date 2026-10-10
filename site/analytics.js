/* Vibe Games — landing page analytics.
 *
 * One job: count visits to vibegames.party. The games themselves are counted by
 * the app at play.vibegames.party and by the iOS client, and all three send to
 * the same property, so a screen can be followed from the marketing page into a
 * game and out again.
 *
 * Left as it is, nothing is loaded and nothing is sent: an empty id is how this
 * page is switched off. Fill in MEASUREMENT_ID (the same `G-…` value the web
 * client has as VITE_FIREBASE_MEASUREMENT_ID) to switch it on.
 *
 * No dependencies and no build step, like the rest of this page. */

(function () {
  "use strict";

  var MEASUREMENT_ID = "G-9F2T6QVFFH";

  if (!MEASUREMENT_ID) return;

  var tag = document.createElement("script");
  tag.async = true;
  tag.src = "https://www.googletagmanager.com/gtag/js?id=" + encodeURIComponent(MEASUREMENT_ID);
  document.head.appendChild(tag);

  window.dataLayer = window.dataLayer || [];
  window.gtag = function () { window.dataLayer.push(arguments); };
  window.gtag("js", new Date());
  window.gtag("config", MEASUREMENT_ID);
})();
