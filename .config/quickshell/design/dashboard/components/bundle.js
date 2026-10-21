/* @ds-bundle: {"format":4,"namespace":"QSDash","components":[]} */
/* Quickshell Swiss Dashboard — preview helpers (plain DOM + SVG, no libraries).
   They draw what the QML components draw, reading every size from the tokens' CSS custom properties
   and colouring through classes, so a theme switch repaints without re-rendering. */
(function () {
  var NS = 'http://www.w3.org/2000/svg';
  function px(name) { return parseFloat(getComputedStyle(document.documentElement).getPropertyValue(name)) || 0; }
  function el(tag, attrs, parent) {
    var e = document.createElementNS(NS, tag);
    for (var k in attrs) e.setAttribute(k, attrs[k]);
    if (parent) parent.appendChild(e);
    return e;
  }
  // Deterministic sample data: a smooth walk, clamped to [lo, hi].
  function walk(n, seed, base, amp, lo, hi) {
    var out = [], v = base, s = seed;
    for (var i = 0; i < n; i++) {
      s = (s * 9301 + 49297) % 233280; var r = s / 233280 - 0.5;
      v += r * amp + (base - v) * 0.08;
      out.push(Math.max(lo, Math.min(hi, v)));
    }
    return out;
  }
  function niceMax(m) { var steps = [1, 2, 5, 10, 20, 25, 50, 100, 200, 500, 1000]; for (var i = 0; i < steps.length; i++) if (steps[i] * 4 >= m) return steps[i] * 4; return Math.ceil(m); }

  // Time series: one y-axis, hairline grid, a ruler for the time axis, crosshair + tooltip.
  // opts: { series:[{name, data, cls:'ink'|'1'..'4', wash:bool}], unit, max, height, seconds, label }
  function timeseries(host, opts) {
    var W = host.clientWidth, H = opts.height || host.clientHeight || px('--chartH'), tick = px('--tickW');
    var multi = opts.series.length > 1, padL = px('--s6') + px('--s2'), padB = px('--s5') - px('--s1'), padR = multi ? px('--s7') + px('--s4') : px('--s2');
    var plotW = W - padL - padR, plotH = H - padB;
    var n = opts.series[0].data.length;
    var max = opts.max || niceMax(Math.max.apply(null, opts.series.map(function (s) { return Math.max.apply(null, s.data); })));
    var svg = el('svg', { width: W, height: H + 4, role: 'img', 'aria-label': opts.label || '' }, host);
    var g = el('g', { class: 'grid' }, svg), yl = el('g', { class: 'ylab' }, svg);
    var steps = plotH < px('--chartH') * 0.75 ? 2 : 4;
    for (var i = 0; i <= steps; i++) {
      var y = Math.round(plotH - plotH * i / steps) + 0.5;
      if (i > 0) el('line', { x1: padL, x2: padL + plotW, y1: y, y2: y }, g);
      var t = el('text', { x: padL - px('--s2'), y: y + px('--s1'), 'text-anchor': 'end', class: 'label' }, yl);
      t.textContent = Math.round(max * i / steps);
    }
    if (opts.unit) { var u = el('text', { x: padL - px('--s2'), y: -px('--s2'), 'text-anchor': 'end', class: 'label unit' }, yl); u.textContent = opts.unit.trim(); }
    // time ruler: baseline, minor ticks every 30 s, major + label every minute
    var ax = el('g', { class: 'axis' }, svg), secs = opts.seconds || n;
    el('rect', { x: padL, y: plotH, width: plotW, height: tick }, ax);
    for (var s = 0; s <= secs; s += 30) {
      var x = Math.round(padL + plotW * (1 - s / secs)), major = s % 60 === 0;
      el('rect', { x: x, y: plotH, width: tick, height: major ? px('--tickMajor') : px('--tickMinor') }, ax);
      if (major && s > 0 && (s / 60) % (secs > 300 ? 2 : 1) === 0) { var lt = el('text', { x: x, y: plotH + px('--s4') + px('--s1') / 2, 'text-anchor': 'middle', class: 'label' }, ax); lt.textContent = '−' + (s / 60) + 'm'; }
    }
    var xs = function (i) { return padL + plotW * i / (n - 1); }, ys = function (v) { return plotH - plotH * v / max; };
    opts.series.forEach(function (sr) {
      var d = sr.data.map(function (v, i) { return (i ? 'L' : 'M') + xs(i).toFixed(1) + ' ' + ys(v).toFixed(1); }).join('');
      if (sr.wash) el('path', { d: d + 'L' + xs(n - 1) + ' ' + plotH + 'L' + padL + ' ' + plotH + 'Z', class: 'w-' + sr.cls }, svg);
      el('path', { d: d, class: 'line s-' + sr.cls }, svg);
      el('circle', { cx: xs(n - 1), cy: ys(sr.data[n - 1]), r: px('--dotD') / 2, class: 'dot f-' + sr.cls }, svg);
      if (multi) { var el2 = el('text', { x: padL + plotW + px('--s2'), y: ys(sr.data[n - 1]) + px('--s1'), class: 'endlab label' }, svg); el2.textContent = sr.name; }
    });
    // hover layer
    var cross = el('line', { y1: 0, y2: plotH, class: 'cross', visibility: 'hidden' }, svg);
    var tip = document.createElement('div'); tip.className = 'tip label'; host.appendChild(tip);
    var hit = el('rect', { x: padL, y: 0, width: plotW, height: plotH, fill: 'transparent' }, svg);
    hit.addEventListener('mousemove', function (ev) {
      var r = svg.getBoundingClientRect(), i = Math.max(0, Math.min(n - 1, Math.round((ev.clientX - r.left - padL) / plotW * (n - 1))));
      var x = xs(i); cross.setAttribute('x1', x); cross.setAttribute('x2', x); cross.setAttribute('visibility', 'visible');
      var ago = Math.round((n - 1 - i) * secs / (n - 1));
      tip.innerHTML = '<div class="mono muted">' + (ago ? '−' + ago + ' s' : 'now') + '</div>' + opts.series.map(function (sr) {
        return '<div class="row"><span class="key" style="color:var(--' + (sr.cls === 'ink' ? 'text' : 'series' + sr.cls) + ')"></span>' + sr.name + '<span class="v num w600">' + sr.data[i].toFixed(0) + (opts.unit || '') + '</span></div>';
      }).join('');
      tip.style.display = 'block'; tip.style.top = '0px';
      var tw = px('--tipW'); var o = px('--s3'); tip.style.left = (x + o + tw > W ? x - o - tw : x + o) + 'px';
    });
    hit.addEventListener('mouseleave', function () { cross.setAttribute('visibility', 'hidden'); tip.style.display = 'none'; });
  }

  function sparkline(host, data, o) {
    o = o || {}; var W = o.w || px('--sparkW'), H = o.h || px('--vitalSparkH'), n = data.length, mx = Math.max.apply(null, data), mn = Math.min.apply(null, data);
    var svg = el('svg', { width: W, height: H, 'aria-hidden': 'true' }, host);
    var m = px('--marker'), y = function (v) { return H - m - (H - 2 * m) * (v - mn) / ((mx - mn) || 1); }, x = function (i) { return W * i / (n - 1); };
    el('path', { d: data.map(function (v, i) { return (i ? 'L' : 'M') + x(i).toFixed(1) + ' ' + y(v).toFixed(1); }).join(''), class: 'line faintline', style: 'stroke-width:var(--tickW)' }, svg);
    el('circle', { cx: W, cy: y(data[n - 1]), r: px('--dotD') / 4 + 1, class: 'f-ink' }, svg);
  }

  // Core strip: one square per thread, sequential ramp by load; hover tooltip.
  function cores(host, loads) {
    var row = document.createElement('div'); row.className = 'cores'; var lbl = document.createElement('div'); lbl.className = 'cores lbl';
    var tip = document.createElement('div'); tip.className = 'tip label'; host.style.position = 'relative';
    loads.forEach(function (v, i) {
      var c = document.createElement('div'), step = Math.min(7, 1 + Math.floor(v / 100 * 7));
      c.className = 'cell'; c.style.background = 'var(--seq' + step + ')'; c.setAttribute('aria-label', 'thread ' + i + ' ' + Math.round(v) + ' %');
      c.addEventListener('mouseenter', function () { tip.innerHTML = '<div class="row">thread ' + i + '<span class="v num w600">' + Math.round(v) + ' %</span></div>'; tip.style.display = 'block'; tip.style.left = c.offsetLeft + 'px'; tip.style.top = (c.offsetTop + c.offsetHeight + px('--s5')) + 'px'; });
      c.addEventListener('mouseleave', function () { tip.style.display = 'none'; });
      row.appendChild(c); var l = document.createElement('span'); l.className = 'mono'; l.textContent = i; lbl.appendChild(l);
    });
    host.appendChild(row); host.appendChild(lbl); host.appendChild(tip);
  }

  window.QSDash = { timeseries: timeseries, sparkline: sparkline, cores: cores, walk: walk };
})();
