// dashboard.js — renders /dashboard.json into stat tiles and SVG line charts.
// Only runs on the dashboard page (guarded on the container). Theme-aware: all
// colors come from CSS variables, so the site's light/dark toggle restyles the
// charts live with no re-render. No external dependencies.
(function () {
  'use strict';
  var tiles = document.getElementById('dash-tiles');
  if (!tiles) return;

  var me = document.currentScript || [].slice.call(document.scripts).pop();
  var ver = (me && me.src.match(/\?v=([0-9a-f]+)/) || [])[1];

  var NS = 'http://www.w3.org/2000/svg';
  function el(name, attrs, parent) {
    var n = document.createElementNS(NS, name);
    for (var k in attrs) n.setAttribute(k, attrs[k]);
    if (parent) parent.appendChild(n);
    return n;
  }
  function div(cls, parent, text) {
    var n = document.createElement('div');
    n.className = cls;
    if (text != null) n.textContent = text;
    if (parent) parent.appendChild(n);
    return n;
  }
  function fmt(n) { return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ','); }

  // One shared tooltip element for every chart.
  var tip = div('dash-tip', document.body);
  tip.hidden = true;
  function showTip(html, x, y) {
    tip.innerHTML = html;
    tip.hidden = false;
    var r = tip.getBoundingClientRect();
    var left = Math.min(x + 14, window.innerWidth - r.width - 8);
    tip.style.left = (left + window.scrollX) + 'px';
    tip.style.top = (y - r.height - 12 + window.scrollY) + 'px';
  }
  function hideTip() { tip.hidden = true; }

  // ---- line chart -------------------------------------------------------
  // opts: { labels: [x labels], series: [{name, cls, dash?, values: [num|null]}],
  //         yMax, yFmt(v), tipRow(seriesIdx, ptIdx) -> string, height? }
  // Mark spec: 2px lines, small round markers, hairline grid, 0-based y axis.
  // Interaction: nearest-point crosshair + tooltip. Identity: legend chips for
  // >=2 series plus a direct label at each line's end (ink text, colored dot).
  // Round a data maximum up to a "nice" axis maximum (1/2/2.5/4/5/8 × 10^k) —
  // the tightest nice ceiling, so lines fill the plot instead of sitting in
  // the bottom half under empty headroom.
  function niceMax(v) {
    var p = Math.pow(10, Math.floor(Math.log10(v)));
    var m = v / p;
    var f = m <= 1 ? 1 : m <= 2 ? 2 : m <= 2.5 ? 2.5 : m <= 4 ? 4 : m <= 5 ? 5 : m <= 8 ? 8 : 10;
    return f * p;
  }
  // Prefer a tick count whose step is itself nice (integers on small axes).
  function tickCount(yMax) {
    var counts = [5, 4], best = 4;
    for (var i = 0; i < counts.length; i++) {
      var s = yMax / counts[i];
      var m = s / Math.pow(10, Math.floor(Math.log10(s)));
      if ([1, 2, 2.5, 5].some(function (f) { return Math.abs(m - f) < 1e-9; })) { best = counts[i]; break; }
    }
    return best;
  }

  function lineChart(host, opts) {
    host.textContent = '';
    var n = opts.labels.length;
    var W = opts.width || 720, H = opts.height || 240;
    var padL = 46, padR = 30, padT = 12, padB = 26;
    var iw = W - padL - padR, ih = H - padT - padB;
    var X = function (i) { return padL + (n === 1 ? iw / 2 : i * iw / (n - 1)); };
    var Y = function (v) { return padT + ih - (v / opts.yMax) * ih; };

    if (opts.series.length > 1) {
      var leg = div('dash-legend', host);
      opts.series.forEach(function (s) {
        var chip = div('dash-chip', leg);
        div('dash-swatch ' + s.cls + (s.dash ? ' dashed' : ''), chip);
        var t = document.createElement('span');
        t.textContent = s.name;
        chip.appendChild(t);
      });
    }

    var svg = el('svg', { viewBox: '0 0 ' + W + ' ' + H, 'class': 'dash-svg', role: 'img' }, host);

    // grid + y ticks (recessive hairlines, muted ink)
    var ticks = tickCount(opts.yMax);
    for (var t = 0; t <= ticks; t++) {
      var v = opts.yMax * t / ticks;
      var y = Y(v);
      el('line', { x1: padL, x2: W - padR, y1: y, y2: y, 'class': 'dash-grid' }, svg);
      el('text', { x: padL - 6, y: y + 3.5, 'text-anchor': 'end', 'class': 'dash-tick' }, svg)
        .textContent = opts.yFmt(v);
    }
    // x labels — thin them out when the chart is narrow
    var every = Math.max(1, Math.ceil(n / (opts.maxXLabels || n)));
    opts.labels.forEach(function (lab, i) {
      if (i % every && i !== n - 1) return;
      if (i === n - 1 && (n - 1) % every && n > 2) {
        // keep the final label from crowding its predecessor
        var prev = Math.floor((n - 2) / every) * every;
        if (X(i) - X(prev) < 46) return;
      }
      el('text', { x: X(i), y: H - 8, 'text-anchor': 'middle', 'class': 'dash-tick' }, svg)
        .textContent = lab;
    });

    // series lines + markers
    opts.series.forEach(function (s) {
      var d = '';
      s.values.forEach(function (v, i) {
        if (v == null) return;
        d += (d ? ' L' : 'M') + X(i).toFixed(1) + ' ' + Y(v).toFixed(1);
      });
      var line = el('path', { d: d, 'class': 'dash-line ' + s.cls }, svg);
      if (s.dash) line.classList.add('dashed');
      s.values.forEach(function (v, i) {
        if (v == null) return;
        el('circle', { cx: X(i), cy: Y(v), r: 3, 'class': 'dash-dot ' + s.cls }, svg);
      });
    });

    // crosshair (hidden until hover)
    var cross = el('line', { y1: padT, y2: padT + ih, 'class': 'dash-cross' }, svg);
    cross.style.display = 'none';

    svg.addEventListener('mousemove', function (e) {
      var r = svg.getBoundingClientRect();
      var mx = (e.clientX - r.left) * (W / r.width);
      var i = Math.round((mx - padL) / (n === 1 ? 1 : iw / (n - 1)));
      i = Math.max(0, Math.min(n - 1, i));
      cross.style.display = '';
      cross.setAttribute('x1', X(i));
      cross.setAttribute('x2', X(i));
      var rows = opts.series.map(function (s, si) {
        if (s.values[i] == null) return '';
        return '<div class="dash-tip-row"><span class="dash-swatch ' + s.cls +
               (s.dash ? ' dashed' : '') + '"></span>' + opts.tipRow(si, i) + '</div>';
      }).join('');
      showTip('<div class="dash-tip-head">' + opts.labels[i] + '</div>' + rows,
              e.clientX, e.clientY);
    });
    svg.addEventListener('mouseleave', function () {
      cross.style.display = 'none';
      hideTip();
    });

    // table view (the accessibility/relief channel)
    var det = document.createElement('details');
    det.className = 'dash-table';
    var sum = document.createElement('summary');
    sum.textContent = 'Data table';
    det.appendChild(sum);
    var tbl = document.createElement('table');
    var thead = '<tr><th></th>' + opts.series.map(function (s) {
      return '<th>' + s.name + '</th>';
    }).join('') + '</tr>';
    var rows = opts.labels.map(function (lab, i) {
      return '<tr><td>' + lab + '</td>' + opts.series.map(function (s, si) {
        return '<td>' + (s.values[i] == null ? '—' : opts.tipRow(si, i).replace(/^.*?: /, '')) + '</td>';
      }).join('') + '</tr>';
    }).join('');
    tbl.innerHTML = '<thead>' + thead + '</thead><tbody>' + rows + '</tbody>';
    det.appendChild(tbl);
    host.appendChild(det);
  }

  fetch('/dashboard.json' + (ver ? '?v=' + ver : ''))
    .then(function (r) { return r.json(); })
    .then(function (data) {
      var rel = data.releases;
      var last = rel[rel.length - 1];
      var mods = data.modules;
      var lastMod = mods.length ? mods[mods.length - 1] : null;

      // ---- stat tiles --------------------------------------------------
      function tile(n, l) {
        var t = div('conf-stat', tiles);
        div('conf-stat-n', t, n);
        div('conf-stat-l', t, l);
      }
      tile((100 * last.tests_pass / last.tests_total).toFixed(1) + '%',
           'declared Roast tests passing — ' + fmt(last.tests_pass) + ' / ' + fmt(last.tests_total));
      tile(fmt(last.files_pass) + ' / ' + fmt(last.files_total), 'Roast files fully passing');
      if (lastMod) tile(lastMod.n + ' / ' + lastMod.total, 'top-50 modules running byte-identical');
      tile(String(rel.length - 1), 'releases tracked (plus main)');

      // ---- Roast charts ------------------------------------------------
      // Two measures on two scales — so two charts, never one dual axis.
      // Tests passing is a share (%); fully-passing files is a COUNT: as a
      // share of the suite the strict all-or-nothing bar reads as "failing",
      // which is the wrong impression — the count rising is the fact.
      // Both series are prefixed with the pre-release daily points mined from
      // ROAST.md's git history; the % series starts only where the modern
      // "declared" denominator applies (the miner already filtered the rest).
      var dev = data.dev || [];
      var span = dev.concat(rel);
      var devCount = dev.length;
      var tagLabels = rel.map(function (r) { return r.tag; });
      var spanLabels = span.map(function (r) { return r.tag; });
      var testsPct = span.map(function (r) {
        return r.tests_total ? 100 * r.tests_pass / r.tests_total : null;
      });
      var filesN = span.map(function (r) { return r.files_pass; });
      var roast = document.getElementById('dash-roast');
      roast.textContent = '';
      function preTag(i) { return i < devCount ? ' · pre-release' : ''; }

      var cardA = div('dash-bench-card', roast);
      div('dash-card-title', cardA, 'declared tests passing');
      lineChart(div('dash-chart', cardA), {
        labels: spanLabels,
        series: [{ name: 'declared tests passing', cls: 's1', values: testsPct }],
        yMax: 100,
        yFmt: function (v) { return v + '%'; },
        width: 380, height: 230, maxXLabels: 5,
        tipRow: function (si, i) {
          var r = span[i];
          return 'tests: ' + testsPct[i].toFixed(1) + '% (' + fmt(r.tests_pass) + ' / ' + fmt(r.tests_total) + ')' + preTag(i);
        }
      });

      var cardB = div('dash-bench-card', roast);
      div('dash-card-title', cardB, 'files fully passing (of ' + fmt(last.files_total) + ' in the suite)');
      lineChart(div('dash-chart', cardB), {
        labels: spanLabels,
        series: [{ name: 'files fully passing', cls: 's2', values: filesN }],
        yMax: niceMax(Math.max.apply(null, filesN.filter(function (v) { return v != null; }))),
        yFmt: function (v) { return fmt(Math.round(v)); },
        width: 380, height: 230, maxXLabels: 5,
        tipRow: function (si, i) {
          var r = span[i];
          return 'files: ' + fmt(r.files_pass) + (r.files_total ? ' of ' + fmt(r.files_total) : '') + preTag(i);
        }
      });

      // ---- modules chart -----------------------------------------------
      if (mods.length) {
        lineChart(document.getElementById('dash-modules'), {
          labels: mods.map(function (m, i) { return 'batch ' + (m.batch || i + 1); }),
          series: [
            { name: 'modules running byte-identical', cls: 's1',
              values: mods.map(function (m) { return m.n; }) }
          ],
          yMax: lastMod.total,
          yFmt: function (v) { return String(Math.round(v)); },
          height: 200,
          tipRow: function (si, i) {
            return 'modules: ' + mods[i].n + ' / ' + mods[i].total + ' (' + mods[i].date + ')';
          }
        });
      }

      // ---- benchmark small multiples -----------------------------------
      var bench = document.getElementById('dash-bench');
      ['fib', 'loopsum', 'strcat'].forEach(function (kernel) {
        var vals = function (key) {
          return rel.map(function (r) {
            return r.bench && r.bench[kernel] && r.bench[kernel][key] != null
              ? r.bench[kernel][key] : null;
          });
        };
        var interp = vals('interp'), native = vals('native'), rakudo = vals('rakudo');
        var max = Math.max.apply(null, [].concat(interp, native, rakudo).filter(function (v) { return v != null; }));
        var card = div('dash-bench-card', bench);
        div('dash-bench-title', card, kernel);
        var host = div('dash-chart', card);
        lineChart(host, {
          labels: tagLabels,
          series: [
            { name: 'interpreter', cls: 's1', values: interp },
            { name: 'native --exe', cls: 's2', values: native },
            { name: 'Rakudo', cls: 'sref', dash: true, values: rakudo }
          ],
          yMax: niceMax(max),
          yFmt: function (v) { return fmt(Math.round(v)); },
          width: 380, height: 230, maxXLabels: 4,
          tipRow: function (si, i) {
            var names = ['interpreter', 'native --exe', 'Rakudo'];
            var v = [interp, native, rakudo][si][i];
            return names[si] + ': ' + v + ' ms';
          }
        });
      });
    })
    .catch(function (e) {
      document.getElementById('dash-roast').textContent = 'Could not load dashboard data (' + e + ').';
    });
})();
