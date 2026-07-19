---
title: Unicode & graphemes
slug: unicode
status: divergent
order: 45
summary: Grapheme-aware length, codepoints, names and values — with one normalization difference.
---

Raku strings are sequences of **graphemes** (what a reader perceives as a character),
not bytes or codepoints. `.chars` counts graphemes and matches Rakudo; the difference
is that Raku++ does not normalise combining sequences (see the divergence).

## Grapheme-aware length

`.chars` counts graphemes, so a base letter plus a combining mark is **one**
character.

```raku
say "café".chars;
my $s = "e" ~ "\x[301]";
say $s.chars;
```
```output
4
1
```

## Codepoints, names, and values

`.ord`/`.chr` convert between a character and its codepoint; `.uniname` gives the
Unicode name, `.uniprop` a property, `.unival` a numeric value.

```raku
say "A".ord;
say 65.chr;
say "α".uniname;
say "½".unival;
```
```output
65
A
GREEK SMALL LETTER ALPHA
0.5
```

## Divergence: normalization

Rakudo normalises strings (NFG/NFC), so `e` + a combining acute becomes the single
precomposed `é` — one codepoint. Raku++ counts it as **one grapheme** but keeps the
**two codepoints**, unnormalised.

```raku
my $s = "e" ~ "\x[301]";
say $s.codes;
```

| Value | Rakudo (reference) | Raku++ |
| ----- | ------------------ | ------ |
| `("e" ~ "\x[301]").chars` | `1` | `1` |
| `("e" ~ "\x[301]").codes` | `1` (NFC) | `2` (unnormalised) |

> Run the block to see Raku++'s result. Grapheme operations (`.chars`, indexing,
> reversing) work correctly; the difference shows only in codepoint counts and when
> comparing a composed vs decomposed spelling of the same text.

## Notes

- `.codes` counts codepoints, `.chars` counts graphemes — they differ whenever a
  grapheme is built from more than one codepoint.
- `.ords` returns all codepoints as a list; `.uniprop` exposes character properties
  (`"A".uniprop` is `Lu`, an uppercase letter).
- Because of the normalization difference, treat `.codes` and codepoint-level
  identity as implementation-specific in Raku++; grapheme-level operations are safe.
