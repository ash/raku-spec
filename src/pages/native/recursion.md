---
title: Deep recursion
slug: recursion
status: full
browser: false
browser-why: recursion is capped at ~200 levels in the browser
order: 30
summary: The interpreter and --exe recurse without limit; the browser engine caps at ~200 levels.
---

Recursion depth is the one place a perfectly ordinary program runs in the Raku++
interpreter (and `--exe`) but not in the browser. The WebAssembly engine shares the
host JavaScript call stack, which a page can't grow, so recursion is capped at
**~200 levels**; the interpreter and native binary have no such limit. The example
below (1000 deep) is verified against Raku++ and Rakudo, but would hit the cap in the
playground.

## Recursing a thousand deep

```raku
sub sum-to($n) {
    $n == 0 ?? 0 !! $n + sum-to($n - 1);
}
say sum-to(1000);
```
```output
500500
```

## Notes

- Shallow recursion (well under ~200 frames) runs fine in the browser — most recursive
  examples elsewhere in this spec do. Only genuinely deep recursion is affected.
- The cap is the JS engine's call-stack limit, not a Raku++ one; `-Oz` WebAssembly
  reaches ~200 Raku frames before the host stack overflows.
- Rewriting deep recursion as a loop (or an explicit stack) runs anywhere, browser
  included — e.g. `[+] 1..1000` also gives `500500`.
