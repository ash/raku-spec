// conformance.js — renders the Roast conformance map from /roast-map.json into a
// filterable, grouped table. Only runs on the conformance page (guarded on the
// container). Theme-aware via CSS variables; no external dependencies.
(function () {
  'use strict';
  var root = document.getElementById('conf-table');
  if (!root) return;

  // Cache-bust the data with the same ?v tag this script was loaded with.
  var me = document.currentScript || [].slice.call(document.scripts).pop();
  var ver = (me && me.src.match(/\?v=([0-9a-f]+)/) || [])[1];
  var url = '/roast-map.json' + (ver ? '?v=' + ver : '');

  var GH = 'https://github.com/Raku/roast/blob/master/';
  var STATUS = {
    pass: { dot: 'st-full', label: 'Passing' },
    part: { dot: 'st-part', label: 'Partial' },
    time: { dot: 'st-ni',   label: 'Timeout' }
  };
  // Synopsis number → human title (from the Raku Synopses).
  var SYN = {
    S01:'Overview', S02:'Bits & pieces', S03:'Operators', S04:'Blocks & statements',
    S05:'Regexes & grammars', S06:'Subroutines', S07:'Iterators', S09:'Data structures',
    S10:'Packages', S11:'Modules', S12:'Objects', S13:'Overloading', S14:'Roles & types',
    S15:'Unicode', S16:'IO', S17:'Concurrency', S19:'Command line', S22:'Distributions',
    S24:'Testing', S26:'Documentation', S28:'Special names', S29:'Builtins', S32:'Standard types'
  };

  var state = { q: '', filter: 'all', data: null };

  fetch(url).then(function (r) { return r.json(); }).then(function (d) {
    state.data = d;
    renderStats(d);
    renderFilters();
    render();
  }).catch(function () {
    root.textContent = 'Could not load the conformance map.';
  });

  function pct(a, b) { return b ? Math.round(a / b * 100) : 0; }

  function renderStats(d) {
    var t = d.totals;
    // Lead with tests passing — the real measure of coverage. Files-fully-green is
    // a strict secondary count (not a percentage, which would misread as success).
    var tiles = [
      ['Tests passing', pct(t.assertPass, t.assertTotal) + '%'],
      ['Tests', t.assertPass.toLocaleString() + ' / ' + t.assertTotal.toLocaleString()],
      ['Files fully green', t.pass.toLocaleString() + ' of ' + t.files.toLocaleString()],
      ['Synopsis areas', d.synopses.length]
    ];
    document.getElementById('conf-stats').innerHTML = tiles.map(function (x) {
      return '<div class="conf-stat"><span class="conf-stat-n">' + x[1] +
             '</span><span class="conf-stat-l">' + x[0] + '</span></div>';
    }).join('');
  }

  function renderFilters() {
    var box = document.getElementById('conf-filters');
    var opts = [['all', 'All'], ['pass', 'Passing'], ['part', 'Partial'], ['time', 'Timeout']];
    box.innerHTML = opts.map(function (o) {
      return '<button class="conf-chip" data-f="' + o[0] + '"' +
             (o[0] === state.filter ? ' aria-pressed="true"' : '') + '>' + o[1] + '</button>';
    }).join('');
    box.addEventListener('click', function (e) {
      var b = e.target.closest('[data-f]'); if (!b) return;
      state.filter = b.getAttribute('data-f');
      [].forEach.call(box.children, function (c) {
        c.setAttribute('aria-pressed', c === b ? 'true' : 'false');
      });
      render();
    });
    var search = document.getElementById('conf-search');
    search.addEventListener('input', function () { state.q = search.value.trim().toLowerCase(); render(); });
  }

  function synTitle(s) {
    var m = s.match(/^S(\d+)-(.+)$/);
    if (!m) return s;
    var t = SYN['S' + m[1]] || '';
    return '<span class="conf-syn-code">S' + m[1] + '</span> ' +
           m[2].replace(/-/g, ' ') + (t ? ' <span class="conf-syn-sub">' + t + '</span>' : '');
  }

  function render() {
    var d = state.data, q = state.q, filt = state.filter;
    // Group filtered rows by synopsis.
    var groups = {};
    d.rows.forEach(function (r) {
      if (filt !== 'all' && r.st !== filt) return;
      if (q && (r.n + ' ' + r.s).toLowerCase().indexOf(q) === -1) return;
      (groups[r.s] = groups[r.s] || []).push(r);
    });
    var keys = Object.keys(groups).sort();
    if (!keys.length) { root.innerHTML = '<p class="conf-empty">No features match.</p>'; return; }

    var open = !!q;  // auto-expand groups while searching
    var html = keys.map(function (s) {
      var rows = groups[s];
      // The bar and count track assertions (tests) passing, not files fully green —
      // a synopsis with many near-complete files reads far higher on tests than on
      // the strict file-pass ratio, and tests are the real measure of coverage.
      var ap = rows.reduce(function (n, r) { return n + r.p; }, 0);
      var at = rows.reduce(function (n, r) { return n + r.t; }, 0);
      var bar = '<span class="conf-bar"><i style="width:' + pct(ap, at) + '%"></i></span>';
      var items = rows.map(function (r) {
        var st = STATUS[r.st] || STATUS.part;
        return '<li><a href="' + GH + r.path + '" target="_blank" rel="noopener">' +
               '<span class="dot ' + st.dot + '" title="' + st.label + '"></span>' +
               '<span class="conf-name">' + esc(r.n) + '</span>' +
               '<span class="conf-count">' + r.p + '/' + r.t + '</span></a></li>';
      }).join('');
      return '<details class="conf-group"' + (open ? ' open' : '') + '>' +
             '<summary><span class="conf-syn">' + synTitle(s) + '</span>' +
             '<span class="conf-syn-meta">' + ap + '/' + at + ' ' + bar + '</span></summary>' +
             '<ul class="conf-list">' + items + '</ul></details>';
    }).join('');
    root.innerHTML = html;
  }

  function esc(s) { return s.replace(/[&<>]/g, function (c) { return { '&':'&amp;','<':'&lt;','>':'&gt;' }[c]; }); }
})();
