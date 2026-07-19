// spec.js — tiny bits of page chrome. The runnable editors are handled entirely
// by raku.js (loaded after this); this wires the mobile nav toggle and reveals
// the current page in the sidebar.
(function () {
  'use strict';
  var nav = document.querySelector('.sidebar');

  var toggle = document.querySelector('.nav-toggle');
  if (toggle) {
    toggle.addEventListener('click', function () {
      document.body.classList.toggle('nav-open');
    });
    // Close the drawer after following a link on mobile.
    if (nav) nav.addEventListener('click', function (e) {
      if (e.target.tagName === 'A') document.body.classList.remove('nav-open');
    });
  }

  // Scroll the sidebar (not the page) so the current page's entry — and its
  // siblings in the same section — are in view on load.
  var active = nav && nav.querySelector('a.active');
  if (active && nav) {
    var a = active.getBoundingClientRect();
    var n = nav.getBoundingClientRect();
    // Only adjust when the active item isn't already comfortably visible.
    if (a.top < n.top + 8 || a.bottom > n.bottom - 8) {
      nav.scrollTop += (a.top - n.top) - (nav.clientHeight - active.offsetHeight) / 2;
    }
  }
})();
