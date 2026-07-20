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

  // Scroll the nav list (not the page, and not the pinned head) so the current
  // page's entry — and its siblings in the same section — are in view on load.
  var scroller = document.querySelector('.sidebar-nav');
  var active = scroller && scroller.querySelector('a.active');
  if (active && scroller) {
    var a = active.getBoundingClientRect();
    var n = scroller.getBoundingClientRect();
    // Only adjust when the active item isn't already comfortably visible.
    if (a.top < n.top + 8 || a.bottom > n.bottom - 8) {
      scroller.scrollTop += (a.top - n.top) - (scroller.clientHeight - active.offsetHeight) / 2;
    }
  }
})();
