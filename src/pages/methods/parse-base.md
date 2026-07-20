---
title: parse-base — read a number in any radix
slug: parse-base
status: full
order: 44
summary: Parse a string of digits in a given base into an Int — the inverse of .base.
---

`.parse-base(radix)` reads a string written in that radix and returns the `Int` it
denotes. It's the inverse of [`.base`](/methods/numeric.html), which renders an
integer *into* a radix.

## Parsing from a base

```raku
say "ff".parse-base(16);
say "101".parse-base(2);
```
```output
255
5
```

`"ff"` in base 16 is `255`; `"101"` in base 2 is `5`.

## Notes

- `.base` and `.parse-base` round-trip: `255.base(16)` is `"FF"` and
  `"FF".parse-base(16)` is `255`.
- The radix can be 2–36; digits above 9 use the letters `a`–`z` (case-insensitive).
- For base-16/8/2 *literals* in source code, the `0x`/`0o`/`0b` prefixes or the
  `:16<…>` form are more direct — see [Integer literals](/literals/integers.html);
  `parse-base` is for radix strings computed or read at runtime.
