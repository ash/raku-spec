---
title: Splitting a string
slug: split
status: partial
order: 25
summary: Break a string on a separator or regex — with two Raku++ gaps (:skip-empty, .comb(n)).
---

`.split` breaks a string into a list on a separator, which can be a string or a
regex, with an optional limit. The basic forms match Rakudo; the `:skip-empty` adverb
and chunk-size `.comb(n)` are the current gaps.

## Split on a string or regex

```raku
say "a-b-c".split("-");
say "a1b2c".split(/\d/);
```
```output
(a b c)
(a b c)
```

## Limit the number of pieces

A second argument caps the number of fields; the last one keeps the remainder.

```raku
say "a-b-c".split("-", 2);
```
```output
(a b-c)
```

## Gap: :skip-empty

`:skip-empty` should drop empty fields (e.g. the trailing empty after a final
separator). Raku++ keeps them.

```raku
say "a1b2c3".split(/\d/, :skip-empty);
```

| Call | Rakudo (reference) | Raku++ |
| ---- | ------------------ | ------ |
| `"a1b2c3".split(/\d/, :skip-empty)` | `(a b c)` | `(a b c )` |

## Gap: .comb with a chunk size

`.comb(n)` should return **n-character chunks**; Raku++ ignores the size and returns
single characters.

```raku
say "hello".comb(2);
```

| Call | Rakudo (reference) | Raku++ |
| ---- | ------------------ | ------ |
| `"hello".comb(2)` | `(he ll o)` | `(h e l l o)` |

> Run the blocks to see Raku++'s results. Until these land, filter empties with
> `.grep(*.chars)` and chunk with `.comb(/../)` or `.rotor` instead.

## Notes

- `.words` splits on whitespace (dropping empty edges) and matches Rakudo — the right
  tool when the separator is "any run of spaces".
- `.lines` splits on line boundaries; `.comb` with no argument returns single
  characters (which matches Rakudo).
- A regex separator lets you split on patterns: `.split(/\s* ',' \s*/)` trims around
  commas.
