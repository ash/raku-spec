#!/usr/bin/env rakupp
# gen-roast-map.raku — snapshot rakupp's Roast conformance into a static JSON the
# spec site renders. Reads a run-roast results file (lines like
#   [PASS]    3/3  6.c/S14-roles/attributes.t
#   [part]  31/51  6.c/S02-types/subset-6c.t
# ) and emits src/data/roast-map.json. Run it after a fresh Roast run:
#   rakupp tools/gen-roast-map.raku <results.txt> <YYYY-MM-DD>
# The results file lives in the raku++ repo (machine-specific), so this is a
# periodic snapshot tool — the committed JSON keeps the site build portable.

sub json-str(Str $s --> Str) {
    '"' ~ $s.subst('\\', '\\\\', :g).subst('"', '\\"', :g) ~ '"'
}

sub MAIN(Str $results, Str $date = 'unknown') {
    my @rows;
    my %by-syn;                       # synopsis -> [pass, part, total-files, assertions-pass, assertions-total]
    my ($files, $ap, $at) = 0, 0, 0;

    for $results.IO.lines -> $line {
        # e.g. "  [PASS]    3/3  6.c/S14-roles/attributes.t"
        next unless $line ~~ / '[' (PASS|part|TIME) ']' \s+ (\d+) '/' (\d+) \s+ (\S+) /;
        my $st   = ~$0 eq 'PASS' ?? 'pass' !! (~$0 eq 'TIME' ?? 'time' !! 'part');
        my $pass = +$1;
        my $tot  = +$2;
        my $path = ~$3;                                   # 6.c/S02-types/subset-6c.t
        my $rel  = $path.subst(/^ '6.' <[cd]> '/'/, '');  # S02-types/subset-6c.t
        next unless $rel.contains('/');
        my $syn  = $rel.substr(0, $rel.index('/'));       # S02-types
        my $name = $rel.substr($rel.index('/') + 1).subst(/ '.t' $/, '');

        @rows.push: %( :s($syn), :n($name), :st($st), :p($pass), :t($tot), :path($path) );
        %by-syn{$syn} //= [0, 0, 0, 0, 0];
        %by-syn{$syn}[0]++ if $st eq 'pass';
        %by-syn{$syn}[1]++ if $st eq 'part';
        %by-syn{$syn}[2]++;
        %by-syn{$syn}[3] += $pass;
        %by-syn{$syn}[4] += $tot;
        $files++; $ap += $pass; $at += $tot;
    }

    my @row-json = @rows.map({
        '{"s":' ~ json-str(.<s>) ~ ',"n":' ~ json-str(.<n>) ~ ',"st":' ~ json-str(.<st>)
        ~ ',"p":' ~ .<p> ~ ',"t":' ~ .<t> ~ ',"path":' ~ json-str(.<path>) ~ '}'
    });

    my @syn-json = %by-syn.keys.sort.map({
        my @v = %by-syn{$_};
        '{"s":' ~ json-str($_) ~ ',"pass":' ~ @v[0] ~ ',"part":' ~ @v[1]
        ~ ',"files":' ~ @v[2] ~ ',"ap":' ~ @v[3] ~ ',"at":' ~ @v[4] ~ '}'
    });

    my $pass-files = @rows.grep(*.<st> eq 'pass').elems;
    my $json = '{"generated":' ~ json-str($date)
        ~ ',"totals":{"files":' ~ $files ~ ',"pass":' ~ $pass-files
        ~ ',"assertPass":' ~ $ap ~ ',"assertTotal":' ~ $at ~ '}'
        ~ ',"synopses":[' ~ @syn-json.join(',') ~ ']'
        ~ ',"rows":[' ~ @row-json.join(',') ~ ']}';

    'src/data'.IO.mkdir;
    spurt('src/data/roast-map.json', $json);
    say "wrote src/data/roast-map.json — $files files, $pass-files fully pass, "
        ~ "$ap/$at assertions across {%by-syn.elems} synopses";
}
