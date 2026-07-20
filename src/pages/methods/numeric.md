---
title: Numeric methods
slug: numeric
status: full
order: 40
summary: Ask a number about itself — primality, magnitude, roots, and radix.
---

Numbers carry a set of query and conversion methods. A representative handful:

## is-prime

```raku
say 17.is-prime;
say 18.is-prime;
```
```output
True
False
```

`is-prime` works on arbitrarily large integers (it uses a probabilistic test).

## abs and sqrt

```raku
say (-5).abs;
say 10.sqrt;
```
```output
5
3.1622776601683795
```

`abs` keeps the type (an `Int` stays an `Int`); `sqrt` returns a `Num`.

## expmod — modular exponentiation

`expmod(base, exp, mod)` computes `base ** exp mod mod` without ever building the
huge intermediate power — the workhorse behind modular arithmetic and cryptography.

```raku
say expmod(2, 10, 1000);
say 7.expmod(256, 13);
```
```output
24
9
```

`2 ** 10` is `1024`, so `mod 1000` is `24`; the method form `7.expmod(256, 13)` reads
the base as the invocant.

## narrow — the simplest exact type

`.narrow` returns the value as the simplest type that still holds it exactly — an
integral `Rat` collapses to `Int`, a genuine fraction stays a `Rat`.

```raku
say (6/3).narrow.^name;
say (3/4).narrow.^name;
```
```output
Int
Rat
```

## base — render in another radix

`base(n)` renders an integer in radix `n` (2–36) as a string.

```raku
say 255.base(2);
say 255.base(16);
```
```output
11111111
FF
```

## Notes

- `.Int`, `.Rat`, `.Num`, and `.Complex` move a number through the
  [numeric tower](/literals/numbers.html); `.narrow` picks the simplest type that
  holds the value exactly.
- Rounding methods (`.floor`, `.ceiling`, `.round`, `.truncate`) live on
  [Rounding](/builtins/rounding.html).
- `.chr` turns a codepoint number into its character (`65.chr` is `A`), the inverse
  of `.ord` on a string.
