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
# editors via raku.online/embed.js — one shared WebAssembly interpreter, so no copy
# of the engine lives in this repo. A ```raku block may be followed by an ```output
# block giving its expected output; --verify runs each such block through the real
# rakupp binary and fails the build on any mismatch, so the spec cannot drift from
# the interpreter it documents.

# Interpreter used by --verify. Defaults to `rakupp` on PATH; override with
# --rakupp=PATH (deploy.sh pins the exact build via .deploy.env).
constant RAKUPP-DEFAULT = 'rakupp';

# status key => (label, css-class, tooltip)
my %STATUS =
    full      => ('Full',            'st-full', 'Implemented; behaves as documented.'),
    partial   => ('Partial',         'st-part', 'Partly implemented — see notes for gaps.'),
    divergent => ('Divergent',       'st-div',  'Behaves differently from Rakudo — see notes.'),
    ni        => ('Not implemented', 'st-ni',   'Documented for completeness; not yet in Raku++.');

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

# Inline formatting. Split on backticks: even segments are prose (escaped + link /
# bold / italic applied), odd segments are code spans (escaped, wrapped in <code>).
# Splitting avoids placeholder sentinels — an embedded NUL byte would truncate the
# string under rakupp's C++ string handling.
sub inline(Str $text --> Str) {
    my @out;
    for $text.split('`').kv -> $idx, $seg {
        @out.push: $idx %% 2 ?? fmt-inline($seg) !! '<code>' ~ esc($seg) ~ '</code>';
    }
    @out.join
}

sub fmt-inline(Str $seg is copy --> Str) {
    $seg = esc($seg);
    $seg = $seg.subst(/ '[' (<-[ \] ]>+) ']' '(' (<-[ ) ]>+) ')' /,
        { '<a href="' ~ esc-attr(~$1) ~ '">' ~ (~$0) ~ '</a>' }, :g);
    $seg = $seg.subst(/ '**' (<-[*]>+) '**' /, { '<strong>' ~ (~$0) ~ '</strong>' }, :g);
    $seg = $seg.subst(/ '*' (<-[*]>+) '*' /,   { '<em>' ~ (~$0) ~ '</em>' }, :g);
    $seg
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
    my @parts = '<nav class="sidebar"><a class="brand" href="/">Raku++ <span>spec</span></a>';
    for @(%site<categories>) -> %cat {
        my @cat-pages = @(%by-cat{ %cat<slug> } // []);
        next unless @cat-pages;   # hide categories with no pages yet
        @parts.push("<div class=\"nav-cat\"><span class=\"nav-cat-title\">{esc(%cat<title>)}</span><ul>");
        for @cat-pages -> $p {
            my $active = ($current.defined && $p === $current) ?? ' class="active"' !! '';
            @parts.push("<li><a$active href=\"/{$p.category}/{$p.slug}.html\">{esc($p.title)}</a></li>");
        }
        @parts.push('</ul></div>');
    }
    @parts.push('</nav>');
    @parts.join
}

sub page-shell(%site, Str $title, Str $body, Str $nav, :$home = False --> Str) {
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
    <link rel="stylesheet" href="/theme/base.css">
    </head>
    <body class="$body-class">
    <button class="nav-toggle" aria-label="Menu">☰</button>
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
    <script src="/theme/spec.js" defer></script>
    <script src="$engine"></script>
    </body>
    </html>
    HTML
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

sub render-home(%site, %by-cat --> Str) {
    my @parts =
        "<div class=\"hero\"><h1>{esc(%site<title>)}</h1>" ~
        "<p class=\"tagline\">{esc(%site<tagline>)}</p></div>";
    for @(%site<categories>) -> %cat {
        my @pages = @(%by-cat{ %cat<slug> } // []);
        next unless @pages;
        @parts.push("<section class=\"cat-block\"><h2>{esc(%cat<title>)}</h2><ul class=\"card-list\">");
        for @pages -> $p {
            my ($label, $cls, $) = @(%STATUS{ $p.status });
            @parts.push(
                "<li><a href=\"/{$p.category}/{$p.slug}.html\">" ~
                "<span class=\"card-title\">{esc($p.title)}</span>" ~
                "<span class=\"status $cls\">{$label}</span>" ~
                "<span class=\"card-summary\">{esc($p.summary)}</span></a></li>");
        }
        @parts.push('</ul></section>');
    }
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

    my ($pages, $by-cat) = collect-pages(%site);

    for @($pages) -> $p {
        my $dest = "out/{$p.category}/{$p.slug}.html";
        mkdir("out/{$p.category}");
        spurt($dest, render-page(%site, $p, $by-cat));
    }
    spurt('out/index.html', render-home(%site, $by-cat));

    mkdir('out/theme');
    for dir('src/theme').grep({ .IO.f }) -> $asset {
        spurt("out/theme/{$asset.IO.basename}", slurp($asset.Str));
    }

    say "built {@($pages).elems} page(s) + home -> out/";

    exit verify-examples(@($pages), $rakupp, $oracle) if $verify;
}
