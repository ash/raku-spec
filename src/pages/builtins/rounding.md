---
title: Rounding — floor / ceiling / round / truncate
slug: rounding
status: divergent
order: 60
summary: Round to integers or a precision — with one Raku++/Rakudo difference on negative halves.
---

Four routines turn a fractional number into a whole one: `floor` (down), `ceiling`
(up), `truncate` (toward zero), and `round` (to nearest). Most cases agree exactly
with Rakudo; `round` differs on negative half-values — see the divergence below.

## floor, ceiling, truncate

```raku
say 3.7.floor;
say 3.2.ceiling;
say 3.7.truncate;
say (-3.7).floor;
```
```output
3
4
3
-4
```

`floor` goes toward −∞, `ceiling` toward +∞, `truncate` toward zero (so
`(-3.7).truncate` is `-3`, while `(-3.7).floor` is `-4`).

## round to a precision

`round` takes an optional scale — round to the nearest multiple of it.

```raku
say 3.5.round;
say 3.14159.round(0.01);
```
```output
4
3.14
```

## Divergence: rounding negative halves

For a value exactly halfway, **Rakudo rounds toward +∞**, while **Raku++ rounds away
from zero**. They agree on positive halves and disagree on negative ones:

```raku
say (-3.5).round;
say (-2.5).round;
```

| Input | Rakudo (reference) | Raku++ |
| ----- | ------------------ | ------ |
| `(-3.5).round` | `-3` | `-4` |
| `(-2.5).round` | `-2` | `-3` |
| `3.5.round`    | `4`  | `4`  |

> Run the block above to see Raku++'s result live. Positive halves (`3.5 → 4`) match;
> only negative halves differ. This is a Raku++ divergence from the reference.

## Notes

- The half-way rule only matters for values ending exactly in `.5`; every other
  value rounds to the genuinely nearest integer identically in both.
- `floor`, `ceiling`, and `truncate` have no half-way ambiguity and match Rakudo
  everywhere.
- `.Int` on a fractional number truncates toward zero — the same as `.truncate`.
