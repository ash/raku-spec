---
title: proto
slug: proto
status: full
order: 45
summary: A shared front-end for a family of multi candidates.
---

A `proto` declares the common shape of a `multi` family — one place to name the
routine and, optionally, run shared code around every candidate. The body `{*}`
means "dispatch to the best matching multi".

## Declaring a proto

```raku
proto describe(|) {*}
multi describe(Int $) { "int" }
multi describe(Str $) { "str" }
say describe(5);
say describe("x");
```
```output
int
str
```

The `proto`'s signature `(|)` accepts any arguments (a capture); each `multi`
narrows it, and `{*}` hands off to the one that fits.

## Notes

- A `proto` is optional — a bare set of `multi`s works — but it documents the family
  and lets you constrain what *any* candidate may accept.
- Because the `{*}` can be surrounded by code, a `proto` can validate or transform
  arguments once, before dispatch: `proto f($x) { $x < 0 ?? die !! {*} }`.
- The `proto` also fixes the routine's return-type and name for tools; individual
  candidates fill in the behaviour — see [Multi dispatch](/subs/multi.html).
