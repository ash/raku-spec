---
title: Complex methods
slug: complex
status: full
order: 48
summary: Pull apart a complex number — real & imaginary parts, conjugate, magnitude.
---

A `Complex` (see [Number forms](/literals/numbers.html)) carries a real and an
imaginary part, and offers the usual methods to inspect and transform it.

## Parts, conjugate, magnitude

`.re` and `.im` are the real and imaginary parts; `.conj` flips the sign of the
imaginary part; `.abs` is the magnitude.

```raku
say (3 + 4i).re;
say (3 + 4i).im;
say (3 + 4i).conj;
say (3 + 4i).abs;
```
```output
3
4
3-4i
5
```

`(3 + 4i).abs` is `5` — the hypotenuse of the 3–4 right triangle.

## Notes

- `.polar` returns the `(magnitude, angle)` polar form; `.arg` gives just the angle
  (in radians).
- Complex arithmetic works with the usual operators, and functions like `sqrt` and
  `exp` extend to `Complex`; taking `sqrt` of a *real* negative gives `NaN`, so use a
  `Complex` (`(-1+0i).sqrt`) for the imaginary root.
- The imaginary unit is the `i` postfix: `2i` is `0+2i` — see
  [Number forms](/literals/numbers.html).
