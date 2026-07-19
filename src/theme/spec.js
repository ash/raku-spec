// spec.js — tiny bits of page chrome. The runnable editors are handled entirely
// by embed.js (loaded after this); this only wires the mobile nav toggle.
(function () {
  'use strict';
  var toggle = document.querySelector('.nav-toggle');
  if (toggle) {
    toggle.addEventListener('click', function () {
      document.body.classList.toggle('nav-open');
    });
    // Close the drawer after following a link on mobile.
    var nav = document.querySelector('.sidebar');
    if (nav) nav.addEventListener('click', function (e) {
      if (e.target.tagName === 'A') document.body.classList.remove('nav-open');
    });
  }
})();
