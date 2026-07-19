---
title: Grammars
slug: grammars
status: full
order: 50
summary: Named, composable regexes as a class — the basis of Raku's parsing.
---

A `grammar` is a class whose methods are regexes. Rules reference one another as
subrules, so a grammar describes a whole language, not just one pattern. `.parse`
runs it against a string and returns a Match tree.

## A tiny grammar

`token` and `rule` declare named patterns; `rule` additionally makes whitespace
significant (handy between tokens). Parsing starts at `TOP`.

```raku
grammar Calc {
    rule TOP { <num> "+" <num> }
    token num { \d+ }
}
say Calc.parse("2 + 3") ?? "parsed" !! "failed";
```
```output
parsed
```

## Reading the parse tree

Subrules capture by name, so the result indexes like a nested Match.

```raku
grammar KV {
    token TOP { <key> "=" <value> }
    token key { \w+ }
    token value { \N+ }
}
my $m = KV.parse("name=Ada");
say ~$m<key>;
say ~$m<value>;
```
```output
name
Ada
```

## Notes

- `token` is non-backtracking and ignores declared whitespace; `rule` is like
  `token` but treats whitespace between atoms as `<.ws>`; `regex` backtracks. Reach
  for `token` by default.
- `.parse` requires the whole string to match `TOP`; `.subparse` allows a partial
  match from the start.
- Pair a grammar with an **actions class** to build a result (an AST, a data
  structure) as it parses — the standard way to turn a parse into something useful.
