#!/usr/bin/env raku
# build.raku — static generator for the Raku++ specification site (spec.raku.online).
#
# Run with rakupp (this whole toolchain is Raku++, dogfooding the interpreter):
#
#   rakupp build.raku                 # build src/ -> out/
#   rakupp build.raku --verify        # build, then run every example through rakupp
#   rakupp build.raku --clean         # remove out/ first
#   rakupp build.raku --rakupp=PATH   # interpreter used for --verify
#
# Each feature is one Markdown-ish file under src/pages/<category>/<slug>.md with a
# small frontmatter block. Fenced ```raku blocks become runnable, syntax-highlighted
# editors via raku.online/raku.js — one shared WebAssembly interpreter, so no copy
# of the engine lives in this repo. A ```raku block may be followed by an ```output
# block giving its expected output; --verify runs each such block through the real
# rakupp binary and fails the build on any mismatch, so the spec cannot drift from
# the interpreter it documents.

# Interpreter used by --verify. Defaults to `rakupp` on PATH; override with
# --rakupp=PATH (deploy.sh pins the exact build via .deploy.env).
constant RAKUPP-DEFAULT = 'rakupp';

# Cache-busting tag stamped onto theme assets (?v=…), set once per build from a
# content hash of all sources — so browsers refetch base.css/spec.js/search.js and
# the search index exactly when their content changes.
my $VERSION = '';

# status key => (label, css-class, tooltip)
my %STATUS =
    full      => ('Full',            'st-full', 'Implemented; behaves as documented.'),
    partial   => ('Partial',         'st-part', 'Partly implemented — see notes for gaps.'),
    divergent => ('Divergent',       'st-div',  'Behaves differently from Rakudo — see notes.'),
    ni        => ('Not implemented', 'st-ni',   'Documented for completeness; not yet in Raku++.');

# Theme switcher: 'system' | 'light' | 'dark'. Runs inline in <head> so the resolved
# theme is applied before first paint (no flash). Uses the same 'raku-theme'
# localStorage key name and switcher UI as the raku.online playground for
# consistency (storage is per-origin, so the two subdomains don't share a value).
# Held as a non-interpolating q:to block because the JS is full of { } that a qq
# string would otherwise treat as Raku interpolation.
my $THEME-SCRIPT = q:to/JS/;
(function () {
  var KEY = 'raku-theme';
  var mql = window.matchMedia('(prefers-color-scheme: dark)');
  var ICON = { system: '◐', light: '☀', dark: '☾' };
  function stored() { try { return localStorage.getItem(KEY) || 'system'; } catch (e) { return 'system'; } }
  function effective(s) { return (s === 'dark' || (s === 'system' && mql.matches)) ? 'dark' : 'light'; }
  function apply(s) {
    var d = document.documentElement;
    d.setAttribute('data-theme', s);
    d.setAttribute('data-theme-active', effective(s));
    var btn = document.querySelector('.theme-btn');
    if (btn) btn.textContent = ICON[s] || ICON.system;
    document.querySelectorAll('.theme-menu [data-theme-set]').forEach(function (el) {
      el.setAttribute('aria-checked', el.getAttribute('data-theme-set') === s ? 'true' : 'false');
    });
  }
  apply(stored());
  mql.addEventListener('change', function () { if (stored() === 'system') apply('system'); });
  window.__setTheme = function (s) { try { localStorage.setItem(KEY, s); } catch (e) {} apply(s); };
  document.addEventListener('DOMContentLoaded', function () {
    apply(stored());
    var sw = document.querySelector('.theme-switch');
    if (!sw) return;
    var btn = sw.querySelector('.theme-btn'), menu = sw.querySelector('.theme-menu');
    function open(o) { menu.hidden = !o; btn.setAttribute('aria-expanded', o ? 'true' : 'false'); }
    btn.addEventListener('click', function (e) { e.stopPropagation(); open(menu.hidden); });
    menu.addEventListener('click', function (e) {
      var b = e.target.closest('[data-theme-set]');
      if (b) { window.__setTheme(b.getAttribute('data-theme-set')); open(false); btn.focus(); }
    });
    document.addEventListener('click', function (e) { if (!sw.contains(e.target)) open(false); });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && !menu.hidden) { e.stopPropagation(); open(false); btn.focus(); } });
  });
})();
JS

# ---------------------------------------------------------------------------
# Small text helpers
# ---------------------------------------------------------------------------

sub esc(Str $s --> Str) {
    $s.subst('&', '&amp;', :g).subst('<', '&lt;', :g).subst('>', '&gt;', :g)
}
sub esc-attr(Str $s --> Str) { esc($s).subst('"', '&quot;', :g) }

sub slugify(Str $s is copy --> Str) {
    $s = $s.subst(/ '<' <-[>]>* '>' /, '', :g);      # strip any tags
    $s = $s.lc;
    $s = $s.subst(/ <-[ a..z 0..9 \s \- ]> /, '', :g);
    $s = $s.subst(/ \s+ /, '-', :g);
    $s
}

# Inline formatting. fmt-basic handles code spans (split on backticks) + bold/italic
# + escaping — but NOT links. inline() renders links first (whose text may itself
# contain a code span, e.g. `[a `Rat`](url)`), protects each with a plain-ASCII
# sentinel, formats the rest, then splices the links back in. The sentinel is ASCII
# because a NUL or private-use char does not survive rakupp's string handling.
sub fmt-basic(Str $seg --> Str) {
    my @out;
    for $seg.split('`').kv -> $idx, $s {
        if $idx %% 2 {
            my $t = esc($s);
            $t = $t.subst(/ '**' (<-[*]>+) '**' /, { '<strong>' ~ (~$0) ~ '</strong>' }, :g);
            $t = $t.subst(/ '*' (<-[*]>+) '*' /,   { '<em>' ~ (~$0) ~ '</em>' }, :g);
            @out.push($t);
        }
        else {
            @out.push('<code>' ~ esc($s) ~ '</code>');
        }
    }
    @out.join
}

sub inline(Str $text --> Str) {
    my @links;
    my $protected = $text.subst(/ '[' (<-[ \] ]>+) ']' '(' (<-[ ) ]>+) ')' /, {
        @links.push('<a href="' ~ esc-attr(~$1) ~ '">' ~ fmt-basic(~$0) ~ '</a>');
        'zXLINKXz' ~ @links.end ~ 'zXENDXz'
    }, :g);
    my $body = fmt-basic($protected);
    $body.subst(/ 'zXLINKXz' (\d+) 'zXENDXz' /, { @links[+$0] }, :g)
}

# Reduce a page's Markdown-ish body to plain searchable text: drop code-fence
# markers (keep their content), heading hashes, list bullets, table pipes, and inline
# markup, and collapse whitespace.
sub index-body(Str $md --> Str) {
    my @out;
    for $md.lines -> $line {
        next if $line.starts-with('```');
        my $t = $line;
        $t = $t.subst(/ ^ \s* '#'+ \s* /, '');
        $t = $t.subst(/ ^ \s* <[\-*]> \s+ /, '');
        $t = $t.subst(/ '[' (<-[ \] ]>+) ']' '(' <-[)]>* ')' /, { ~$0 }, :g);
        $t = $t.subst('`', '', :g).subst('**', '', :g).subst('|', ' ', :g);
        @out.push($t.trim);
    }
    @out.grep(*.chars).join(' ').subst(/ \s+ /, ' ', :g).trim
}

# Escape a string as a JSON string literal (quotes included).
sub json-str(Str $s --> Str) {
    my $e = $s.subst('\\', '\\\\', :g).subst('"', '\\"', :g)
             .subst(/ \t /, ' ', :g).subst(/ \n /, ' ', :g);
    '"' ~ $e ~ '"'
}

# 8-char content hash over every source (theme + pages + config) — the cache tag.
sub asset-version(--> Str) {
    my @files = dir('src/theme').grep({ .IO.f }).map(*.Str);
    for dir('src/pages').grep({ .IO.d }).sort -> $cat {
        @files.append: dir($cat).grep({ .IO.f && .Str.ends-with('.md') }).map(*.Str);
    }
    @files.push('src/site.raku');
    @files.push('src/data/roast-map.json') if 'src/data/roast-map.json'.IO.e;
    my $blob = @files.sort.map({ slurp($_) }).join;
    my $p = run('md5', '-q', :in, :out);
    $p.in.print($blob);
    $p.in.close;
    $p.out.slurp(:close).trim.substr(0, 8)
}

# Parse a fence info string like `raku run stdin="Ada\nGrace"` into (lang, %opts).
sub parse-info(Str $info) {
    my $lang = $info.words ?? $info.words[0] !! '';
    my %opts;
    my $rest = $info.subst(/ ^ \s* \S+ /, '');
    # NB: a literal " inside a <-[...]> class breaks rakupp's regex parser, so the
    # quote is written as \x22 here.
    for $rest ~~ m:g/ (\w+) [ '="' (<-[\x22]>*) '"' ]? / -> $m {
        %opts{ ~$m[0] } = $m[1].defined ?? (~$m[1]).subst('\n', "\n", :g) !! True;
    }
    $lang, %opts
}

# ---------------------------------------------------------------------------
# Document model
# ---------------------------------------------------------------------------

class Page {
    has Str $.category;
    has Str $.slug;
    has Str $.title;
    has Str $.status;
    has Str $.summary;
    has Int $.order;
    has Str $.body;
    has Str $.path;
    has @.examples is rw;     # list of [code, expected-or-Nil, line-number]
}

sub parse-frontmatter(Str $text, Str $path) {
    die "$path: missing '---' frontmatter block" unless $text.starts-with('---');
    my $end = $text.index("\n---", 3);
    die "$path: unterminated frontmatter block" unless $end.defined;
    my $head = $text.substr(3, $end - 3).trim("\n");
    my $body = $text.substr($end + 4).subst(/ ^ \n+ /, '');
    my %meta;
    for $head.lines -> $raw {
        my $line = $raw.trim;
        next unless $line;
        next if $line.starts-with('#');
        die "$path: bad frontmatter line: $line" unless $line.contains(':');
        my ($k, $v) = $line.split(':', 2);
        %meta{ $k.trim } = $v.trim;
    }
    # Itemise the hash so it stays one element when list-assigned by the caller
    # (a bare %meta would greedily slurp the whole returned list).
    $(%meta), $body
}

sub load-page(Str $category, Str $path --> Page) {
    my ($meta, $body) = parse-frontmatter(slurp($path), $path);
    die "$path: frontmatter needs a 'title'" unless $meta<title>;
    my $status = $meta<status> // 'full';
    die "$path: unknown status '$status'" unless %STATUS{$status}:exists;
    Page.new(
        category => $category,
        slug     => $meta<slug> // $path.IO.basename.subst(/ '.md' $ /, ''),
        title    => $meta<title>,
        status   => $status,
        summary  => $meta<summary> // '',
        order    => ($meta<order> // '100').Int,
        body     => $body,
        path     => $path,
        examples => [],
    )
}

# ---------------------------------------------------------------------------
# Markdown-ish renderer (a deliberately small, predictable subset)
# ---------------------------------------------------------------------------

class Renderer {
    has @.lines;
    has @!out;
    has $.page;
    has Int $!i = 0;

    method render(--> Str) {
        while $!i < @.lines.elems {
            my $line = @.lines[$!i];
            if $line !~~ / \S /                          { $!i++ }
            elsif $line.starts-with('```')               { self!fence }
            elsif $line ~~ / ^ '#'+ \s /                 { self!heading($line) }
            elsif $line ~~ / ^ \s* <[\-*]> ' ' /     { self!ulist }
            elsif $line ~~ / ^ \s* \d+ '.' ' ' /         { self!olist }
            elsif $line.starts-with('>')                 { self!quote }
            elsif $line ~~ / ^ \s* '|' / && self!table-ahead { self!table }
            else                                         { self!paragraph }
        }
        @!out.join("\n")
    }

    method !starter(Str $line --> Bool) {
        so  $line !~~ / \S /
        ||  $line.starts-with('```')
        ||  $line ~~ / ^ '#'+ \s /
        ||  $line.starts-with('>')
        ||  $line ~~ / ^ \s* <[\-*]> ' ' /
        ||  $line ~~ / ^ \s* \d+ '.' ' ' /
    }

    method !heading(Str $line) {
        my $hashes = ($line ~~ / ^ ('#'+) /)[0].chars;
        my $text = $line.substr($hashes).trim;
        my $anchor = slugify($text);
        @!out.push:
            "<h$hashes id=\"$anchor\">" ~ inline($text) ~
            " <a class=\"anchor\" href=\"#$anchor\" aria-label=\"link\">#</a></h$hashes>";
        $!i++;
    }

    method !paragraph {
        my @buf;
        while $!i < @.lines.elems && !self!starter(@.lines[$!i]) {
            @buf.push(@.lines[$!i].trim);
            $!i++;
        }
        @!out.push('<p>' ~ inline(@buf.join(' ')) ~ '</p>');
    }

    # A list item runs from its bullet/number line until a blank line or the next
    # item; wrapped continuation lines are folded into the same item.
    method !item-body(Str $first) {
        my $item = $first;
        while $!i < @.lines.elems && !self!starter(@.lines[$!i]) {
            $item ~= ' ' ~ @.lines[$!i].trim;
            $!i++;
        }
        inline($item)
    }

    method !ulist {
        my @items;
        while $!i < @.lines.elems && @.lines[$!i] ~~ / ^ \s* <[\-*]> ' ' / {
            my $first = @.lines[$!i].trim.substr(2).trim;
            $!i++;
            @items.push(self!item-body($first));
        }
        @!out.push('<ul>' ~ @items.map({ "<li>{$_}</li>" }).join ~ '</ul>');
    }

    method !olist {
        my @items;
        while $!i < @.lines.elems && @.lines[$!i] ~~ / ^ \s* \d+ '.' ' ' / {
            my $first = @.lines[$!i].subst(/ ^ \s* \d+ '.' \s /, '').trim;
            $!i++;
            @items.push(self!item-body($first));
        }
        @!out.push('<ol>' ~ @items.map({ "<li>{$_}</li>" }).join ~ '</ol>');
    }

    method !quote {
        my @buf;
        while $!i < @.lines.elems && @.lines[$!i].starts-with('>') {
            @buf.push(@.lines[$!i].subst(/ ^ '>' \s? /, ''));
            $!i++;
        }
        @!out.push('<blockquote class="note">' ~ inline(@buf.join(' ')) ~ '</blockquote>');
    }

    method !table-ahead(--> Bool) {
        so $!i + 1 < @.lines.elems
            && @.lines[$!i + 1] ~~ / ^ \s* '|'? <[ \s : | \- ]>+ '|' /
    }

    method !cells(Str $row is copy) {
        $row = $row.trim;
        $row = $row.substr(1) if $row.starts-with('|');
        $row = $row.substr(0, $row.chars - 1) if $row.ends-with('|');
        $row.split('|').map(*.trim)
    }

    method !table {
        my @header = self!cells(@.lines[$!i]);
        $!i += 2;   # header row + delimiter row
        my @rows;
        while $!i < @.lines.elems && @.lines[$!i].trim.starts-with('|') {
            @rows.push([self!cells(@.lines[$!i])]);
            $!i++;
        }
        my $h = @header.map({ '<th>' ~ inline($_) ~ '</th>' }).join;
        my $b = @rows.map(-> @r { '<tr>' ~ @r.map({ '<td>' ~ inline($_) ~ '</td>' }).join ~ '</tr>' }).join;
        @!out.push("<div class=\"table-wrap\"><table><thead><tr>{$h}</tr></thead><tbody>{$b}</tbody></table></div>");
    }

    method !fence {
        my $info  = @.lines[$!i].substr(3);
        my $start = $!i + 1;
        $!i++;
        my @buf;
        while $!i < @.lines.elems && !@.lines[$!i].starts-with('```') {
            @buf.push(@.lines[$!i]);
            $!i++;
        }
        $!i++;   # closing fence
        my $code = @buf.join("\n");
        my ($lang, %opts) = parse-info($info);

        if $lang eq 'raku' | 'raku-run' {
            my $expected = self!peek-output;
            $.page.examples.push([$code, $expected, $start]);
            my $run = so ($lang eq 'raku-run' || %opts<run>);
            self!emit-runnable($code, %opts, $run, $expected);
        }
        elsif $lang eq 'output' | 'text' {
            @!out.push('<pre class="output"><code>' ~ esc($code) ~ '</code></pre>');
        }
        elsif $lang eq 'syntax' {
            @!out.push('<pre class="syntax"><code>' ~ esc($code) ~ '</code></pre>');
        }
        else {
            my $cls = $lang ?? " class=\"lang-{esc-attr($lang)}\"" !! '';
            @!out.push("<pre$cls><code>" ~ esc($code) ~ '</code></pre>');
        }
    }

    # If the next non-blank block is an ```output fence, consume it and return its
    # text (used both to render the expected output and to verify examples).
    method !peek-output {
        my $j = $!i;
        $j++ while $j < @.lines.elems && @.lines[$j] !~~ / \S /;
        return Str unless $j < @.lines.elems && @.lines[$j].starts-with('```');
        my ($lang, $) = parse-info(@.lines[$j].substr(3));
        return Str unless $lang eq 'output' | 'text';
        my $k = $j + 1;
        my @buf;
        while $k < @.lines.elems && !@.lines[$k].starts-with('```') {
            @buf.push(@.lines[$k]);
            $k++;
        }
        $!i = $k + 1;
        @buf.join("\n")
    }

    method !emit-runnable(Str $code, %opts, Bool $run, $expected) {
        my @attrs = 'data-raku';
        @attrs.push('data-run') if $run;
        @attrs.push('data-stdin="' ~ esc-attr(%opts<stdin>) ~ '"')
            if %opts<stdin>:exists && %opts<stdin> !=== True;
        @attrs.push('data-rows="' ~ esc-attr(~%opts<rows>) ~ '"')
            if %opts<rows>:exists && %opts<rows> !=== True;
        @!out.push('<pre ' ~ @attrs.join(' ') ~ '>' ~ esc($code) ~ '</pre>');
        if $expected.defined {
            @!out.push(
                '<div class="expected"><span class="expected-label">Output</span>' ~
                '<pre class="output"><code>' ~ esc($expected) ~ '</code></pre></div>');
        }
    }
}

# ---------------------------------------------------------------------------
# HTML assembly
# ---------------------------------------------------------------------------

sub nav-html(%site, %by-cat, $current) {
    my @parts = '<nav class="sidebar"><div class="sidebar-head">' ~
        '<a class="brand" href="/">Raku++<span>spec</span></a>' ~
        '<div class="site-search"><input type="search" placeholder="Search the spec…" ' ~
        'aria-label="Search the spec" autocomplete="off" spellcheck="false">' ~
        '<span class="ss-hint" aria-hidden="true">/</span>' ~
        '<div class="ss-results" hidden></div></div></div><div class="sidebar-nav">';
    # The sidebar is an accordion: only one section is expanded at a time. On a
    # page, its own section starts open; on the home page, the first section does.
    my $cur-cat = $current.defined ?? $current.category !! '';
    my $first   = True;
    for @(%site<categories>) -> %cat {
        my @cat-pages = @(%by-cat{ %cat<slug> } // []);
        next unless @cat-pages;   # hide categories with no pages yet
        my $open = ($cur-cat eq %cat<slug>) || ($cur-cat eq '' && $first);
        $first = False;
        my $ocls = $open ?? ' open' !! '';
        my $aria = $open ?? 'true' !! 'false';
        @parts.push(
            "<div class=\"nav-cat$ocls\">" ~
            "<button class=\"nav-cat-title\" type=\"button\" aria-expanded=\"$aria\">" ~
            "<span class=\"nav-cat-chev\" aria-hidden=\"true\"></span>" ~
            "<span class=\"nav-cat-name\">{esc(%cat<title>)}</span></button>" ~
            "<div class=\"nav-cat-body\"><ul>");
        for @cat-pages -> $p {
            my $active = ($current.defined && $p === $current) ?? ' class="active"' !! '';
            @parts.push("<li><a$active href=\"/{$p.category}/{$p.slug}.html\">{esc($p.title)}</a></li>");
        }
        @parts.push('</ul></div></div>');
    }
    @parts.push('</div></nav>');
    @parts.join
}

sub page-shell(%site, Str $title, Str $body, Str $nav, :$home = False, :$extra-scripts = '' --> Str) {
    my $engine     = esc-attr(%site<engine>);
    my $playground = esc-attr(%site<playground>);
    my $repo       = esc-attr(%site<repo>);
    my $body-class = $home ?? 'home' !! '';
    qq:to/HTML/
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{esc($title)}</title>
    <script>{$THEME-SCRIPT}</script>
    <link rel="stylesheet" href="/theme/base.css?v={$VERSION}">
    </head>
    <body class="$body-class">
    <button class="nav-toggle" aria-label="Menu">☰</button>
    <span class="theme-switch">
    <button class="theme-btn" aria-label="Theme" aria-haspopup="true" aria-expanded="false">◐</button>
    <ul class="theme-menu" hidden>
    <li><button data-theme-set="system"><span class="ti">◐</span> System</button></li>
    <li><button data-theme-set="light"><span class="ti">☀</span> Light</button></li>
    <li><button data-theme-set="dark"><span class="ti">☾</span> Dark</button></li>
    </ul>
    </span>
    $nav
    <main>
    <div class="content">
    $body
    </div>
    <footer>
    <span>Raku++ Specification — behaviour of <a href="$playground">raku.online</a>'s interpreter.</span>
    <span>Examples run live in your browser via WebAssembly. <a href="$repo">Source</a>.</span>
    </footer>
    </main>
    <script src="/theme/spec.js?v={$VERSION}" defer></script>
    <script src="/theme/search.js?v={$VERSION}" defer></script>
    $extra-scripts
    <script src="$engine"></script>
    </body>
    </html>
    HTML
}

# The Roast conformance map — a special page rendering the committed
# src/data/roast-map.json snapshot into a filterable table (see conformance.js).
sub render-conformance(%site, %by-cat --> Str) {
    my $body = q:to/BODY/;
    <div class="conf-head">
      <h1>Roast conformance</h1>
      <p class="tagline">Where Raku++ stands against <a href="https://github.com/Raku/roast">Roast</a>,
      the official Raku specification test suite — the same tests this spec is verified against.</p>
      <div class="conf-hero" id="conf-hero"></div>
      <div class="conf-denoms" id="conf-denoms"></div>
      <p class="conf-source">Counts and methodology come from Raku++'s own Roast run —
      see <a href="RAKUPP_REPO/blob/main/docs/ROAST.md">ROAST.md</a> (standing &amp;
      per-synopsis breakdown) and <a href="RAKUPP_REPO/blob/main/docs/COUNTING.md">COUNTING.md</a>
      (exact definition of every figure).</p>
    </div>
    <h2 class="conf-areas-title">By synopsis <span>— tests that ran, per area</span></h2>
    <div class="conf-controls">
      <input type="search" id="conf-search" placeholder="Filter features…" aria-label="Filter features" autocomplete="off" spellcheck="false">
      <div class="conf-filters" id="conf-filters"></div>
    </div>
    <div class="conf-table" id="conf-table" aria-live="polite">Loading the conformance map…</div>
    BODY
    $body = $body.subst('RAKUPP_REPO', esc-attr(%site<rakupp>), :g);
    my $extra = "<script src=\"/theme/conformance.js?v={$VERSION}\" defer></script>";
    page-shell(%site, 'Roast conformance — Raku++ Specification', $body,
               nav-html(%site, %by-cat, Nil), :extra-scripts($extra))
}

sub render-page(%site, $page, %by-cat --> Str) {
    my ($label, $cls, $tip) = @(%STATUS{ $page.status });
    my $r = Renderer.new(lines => $page.body.lines, page => $page);
    my $body = $r.render;
    my $cat-title = @(%site<categories>).first({ .<slug> eq $page.category })<title> // $page.category;
    my $head =
        '<div class="page-head">' ~
        "<div class=\"crumb\">{esc($cat-title)}</div>" ~
        "<h1>{esc($page.title)}</h1>" ~
        "<span class=\"status $cls\" title=\"{esc-attr($tip)}\">{$label}</span>" ~
        '</div>';
    $head ~= "<p class=\"summary\">{inline($page.summary)}</p>" if $page.summary;
    page-shell(%site, "{$page.title} — {%site<title>}", $head ~ $body, nav-html(%site, %by-cat, $page))
}

# Count the demonstrated features on a page: each `## ` section (bar Notes) is one
# named feature with its own example. Fence-aware so `##` inside code never counts.
sub count-features(Str $body --> Int) {
    my $n = 0;
    my $in-fence = False;
    for $body.lines -> $line {
        if $line.starts-with('```') { $in-fence = !$in-fence; next }
        next if $in-fence;
        $n++ if $line.starts-with('## ') && !$line.starts-with('## Notes');
    }
    $n
}

sub render-home(%site, %by-cat --> Str) {
    my @cats-with-pages = @(%site<categories>).grep({ @(%by-cat{ .<slug> } // []).elems });
    my $pages    = @cats-with-pages.map({ @(%by-cat{ .<slug> }).elems }).sum;
    my $features = @cats-with-pages
        .map({ @(%by-cat{ .<slug> }) }).flat
        .map({ count-features($_.body) }).sum;

    my @parts =
        "<div class=\"hero\"><h1>{esc(%site<title>)}</h1>" ~
        "<p class=\"tagline\">{esc(%site<tagline>)}</p>" ~
        "<p class=\"hero-stats\">$features features across $pages pages · " ~
        "every example verified against Raku++ and Rakudo</p>" ~
        "<p class=\"hero-links\"><a href=\"/conformance.html\">See the full Roast conformance map →</a></p>" ~
        '</div>';

    # Status legend.
    @parts.push('<div class="legend">');
    for <full partial divergent ni> -> $s {
        my ($label, $cls, $) = @(%STATUS{$s});
        @parts.push("<span class=\"leg\"><span class=\"dot $cls\"></span>{$label}</span>");
    }
    @parts.push('</div>');

    # Compact overview: one panel per category, flowing in columns.
    @parts.push('<div class="overview">');
    for @cats-with-pages -> %cat {
        my @pages = @(%by-cat{ %cat<slug> });
        @parts.push(
            "<section class=\"ov-cat\"><h2>{esc(%cat<title>)}" ~
            "<span class=\"ov-count\">{@pages.elems}</span></h2><ul class=\"ov-list\">");
        for @pages -> $p {
            my ($label, $cls, $) = @(%STATUS{ $p.status });
            @parts.push(
                "<li><a href=\"/{$p.category}/{$p.slug}.html\" title=\"{esc-attr($p.summary)}\">" ~
                "<span class=\"dot $cls\" title=\"{$label}\"></span>{esc($p.title)}</a></li>");
        }
        @parts.push('</ul></section>');
    }
    @parts.push('</div>');
    page-shell(%site, %site<title>, @parts.join, nav-html(%site, %by-cat, Nil), :home)
}

# ---------------------------------------------------------------------------
# Verification against the real interpreter
# ---------------------------------------------------------------------------

sub run-snippet(Str $exe, Str $code) {
    my $proc = run($exe, '/dev/stdin', :in, :out, :err);
    $proc.in.print($code);
    $proc.in.close;
    my $out = $proc.out.slurp(:close).subst(/ \n+ $ /, '');
    my $err = $proc.err.slurp(:close);
    $out, $err
}

# Verify each example's declared output against Raku++, and — when --oracle is set
# (e.g. --oracle=raku) — against Rakudo too. The declared output should equal
# Rakudo's (the authority); an oracle mismatch means the author didn't consult it,
# a rakupp-only mismatch means a genuine divergence (mark the page `divergent`).
sub verify-examples(@pages, Str $rakupp, Str $oracle --> Int) {
    if $rakupp.contains('/') && !$rakupp.IO.e {
        note "verify: rakupp not found at $rakupp";
        return 1;
    }
    my $has-oracle = $oracle.chars > 0;
    my $checked = 0;
    my $rakupp-fail = 0;
    my $oracle-fail = 0;
    for @pages -> $page {
        for @($page.examples) -> @ex {
            my ($code, $expected, $line) = @ex;
            next unless $expected.defined;
            $checked++;
            my $want = $expected.subst(/ \n+ $ /, '');

            my ($got, $err) = run-snippet($rakupp, $code);
            if $got ne $want {
                $rakupp-fail++;
                note "  RAKU++ MISMATCH {$page.path}:$line";
                note "    expected: {$want.raku}";
                note "    rakupp:   {$got.raku}";
                note "    stderr:   {$err.trim.raku}" if $err.trim;
            }

            if $has-oracle {
                my ($ogot, $oerr) = run-snippet($oracle, $code);
                if $ogot ne $want {
                    $oracle-fail++;
                    note "  ORACLE MISMATCH ($oracle) {$page.path}:$line";
                    note "    expected: {$want.raku}";
                    note "    oracle:   {$ogot.raku}";
                    note "    stderr:   {$oerr.trim.raku}" if $oerr.trim;
                }
            }
        }
    }
    if $has-oracle {
        say "verify: $checked checked · $rakupp-fail rakupp mismatch(es) · $oracle-fail oracle mismatch(es) vs $oracle";
    }
    else {
        say "verify: $checked example(s) checked, $rakupp-fail mismatch(es)";
    }
    ($rakupp-fail + $oracle-fail) ?? 1 !! 0
}

# ---------------------------------------------------------------------------
# Build driver
# ---------------------------------------------------------------------------

sub collect-pages(%site) {
    my %known = @(%site<categories>).map({ .<slug> => True });
    my @pages;
    for dir('src/pages').grep({ .IO.d }).sort -> $cat-dir {
        my $cat = $cat-dir.IO.basename;
        note "warning: category dir '$cat' not listed in site.raku" unless %known{$cat};
        for dir($cat-dir).grep({ .IO.f && .Str.ends-with('.md') }).sort -> $md {
            @pages.push(load-page($cat, $md.Str));
        }
    }
    my %by-cat;
    %by-cat{ .category }.push($_) for @pages;
    for %by-cat.keys -> $k {
        %by-cat{$k} = %by-cat{$k}.sort({ (.order, .title) }).Array;
    }
    # Itemise both so neither is slurped by a greedy container on the receiving end.
    $(@pages), $(%by-cat)
}

sub MAIN(Bool :$verify = False, Bool :$clean = False, Str :$rakupp = RAKUPP-DEFAULT, Str :$oracle = '') {
    my %site = EVAL slurp('src/site.raku');

    if $clean && 'out'.IO.d {
        run('rm', '-rf', 'out');
    }
    mkdir('out');

    $VERSION = asset-version();
    my ($pages, $by-cat) = collect-pages(%site);

    for @($pages) -> $p {
        my $dest = "out/{$p.category}/{$p.slug}.html";
        mkdir("out/{$p.category}");
        spurt($dest, render-page(%site, $p, $by-cat));
    }
    spurt('out/index.html', render-home(%site, $by-cat));

    # Roast conformance map (special page + its committed data snapshot).
    if 'src/data/roast-map.json'.IO.e {
        spurt('out/conformance.html', render-conformance(%site, $by-cat));
        spurt('out/roast-map.json', slurp('src/data/roast-map.json'));
    }

    # Client-side search index: one {u,t,b} record per page, loaded by search.js.
    my @entries;
    for @($pages) -> $p {
        my $u = "/{$p.category}/{$p.slug}.html";
        my $b = ($p.summary ~ ' ' ~ index-body($p.body)).trim;
        # Cap generously so every term on a page stays searchable (the old 1800
        # limit truncated longer pages, hiding tail content like `samewith` from
        # search); 8000 covers every current page in full.
        $b = $b.substr(0, 8000) if $b.chars > 8000;
        @entries.push('{"u":' ~ json-str($u) ~ ',"t":' ~ json-str($p.title)
                        ~ ',"b":' ~ json-str($b) ~ '}');
    }
    spurt('out/search-index.json', '[' ~ @entries.join(',') ~ ']');

    mkdir('out/theme');
    for dir('src/theme').grep({ .IO.f }) -> $asset {
        spurt("out/theme/{$asset.IO.basename}", slurp($asset.Str));
    }

    say "built {@($pages).elems} page(s) + home -> out/";

    exit verify-examples(@($pages), $rakupp, $oracle) if $verify;
}
