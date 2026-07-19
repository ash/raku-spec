---
title: Case methods
slug: case
status: partial
order: 20
summary: Upper, lower, and title case — with .wordcase not yet implemented in Raku++.
---

`Str` offers a family of case conversions. `.uc`/`.lc` (upper/lower) and `.tc`/`.tclc`
(title-case the first letter) work as in Rakudo; `.wordcase` is the gap (see below).

## Title-casing

`.tc` upper-cases the first character; `.tclc` also lower-cases the rest — useful for
normalising a word.

```raku
say "hello world".tc;
say "hELLO".tclc;
```
```output
Hello world
Hello
```

`.tc` touches only the first letter, so `hello world` becomes `Hello world` (the `w`
stays lower).

## Gap: .wordcase

`.wordcase` should title-case **every** word. Rakudo does; Raku++ currently returns
the string unchanged.

```raku
say "hello world".wordcase;
```

| Call | Rakudo (reference) | Raku++ |
| ---- | ------------------ | ------ |
| `"hello world".wordcase` | `Hello World` | `hello world` |

> Run the block to see Raku++'s result. Until `.wordcase` is implemented, title-case
> each word yourself, e.g. `.split(" ").map(*.tc).join(" ")`.

## Notes

- `.uc` and `.lc` are the plain upper/lower conversions and match Rakudo.
- `.fc` is *fold case* — a canonical form for case-insensitive comparison, distinct
  from `.lc`.
- Unicode-aware: case methods handle accented letters and multi-codepoint graphemes,
  not just ASCII.
