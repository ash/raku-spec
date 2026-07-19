---
title: where constraints
slug: constraints
status: partial
order: 35
summary: Narrow a parameter with a predicate — parsed and passed, but not yet enforced in Raku++.
---

A `where` clause attaches a predicate to a parameter, so a value must both be of the
right type **and** satisfy the test. Valid arguments behave identically in Raku++ and
Rakudo; the difference is that **Raku++ does not currently reject invalid ones** (see
the gap below).

## A constrained parameter

```raku
sub f(Int $n where * > 0) {
    $n * 2;
}
say f(5);
```
```output
10
```

The predicate can be any expression — `where *.chars > 3`, `where * %% 2`, or a
literal value.

```raku
sub g($s where *.chars > 3) {
    "ok: $s";
}
say g("hello");
```
```output
ok: hello
```

## Gap: constraints aren't enforced

In Rakudo, an argument that fails the predicate causes the call to fail (no candidate
matches). Raku++ parses the `where` and passes valid values through, but **does not
reject a failing value** — it runs the body anyway.

```raku
sub pos(Int $n where * > 0) { $n }
say (try pos(-1)) // "rejected";
```

| Call | Rakudo (reference) | Raku++ |
| ---- | ------------------ | ------ |
| `pos(-1)` with `where * > 0` | fails → `rejected` | accepted → `-1` |

> Run the block to see Raku++'s result. Until this is enforced, don't rely on `where`
> for validation in Raku++ — check the value explicitly in the body if it matters.

## Notes

- `where` is also how `subset` types narrow a base type — see
  [Subsets](/types/subsets.html), which share this enforcement gap.
- For dispatch, a `where` on a [multi](/subs/multi.html) candidate is how you route
  on a value (e.g. a `0` case vs the general case) — also subject to the gap above.
- A passing constraint has zero runtime cost beyond evaluating the predicate once per
  call.
