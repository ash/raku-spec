---
title: samecase
slug: samecase
status: full
order: 28
summary: Recase a string to follow the case pattern of another.
---

`.samecase(pattern)` rewrites a string's letters to match the upper/lower **case
pattern** of a second string, position by position (the last case carries onward).

## Matching a case pattern

```raku
say "hello".samecase("AB");
```
```output
HELLO
```

The pattern `"AB"` is all uppercase, so `hello` becomes `HELLO`; a mixed pattern like
`"Ab"` would title-case instead.

## Notes

- It's handy for preserving the casing of a word you're substituting — recase the
  replacement to `.samecase` the original.
- Related case methods (`.uc`, `.lc`, `.tc`, `.tclc`) are on the
  [Case methods](/methods/case.html) page; `.samecase` differs by taking its casing
  from another string rather than a fixed rule.
- `.indent` (add leading spaces to each line) is **not yet implemented** in Raku++ —
  use a manual `.lines.map(" " x $n ~ *).join("\n")` for now.
