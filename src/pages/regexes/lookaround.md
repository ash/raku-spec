---
title: Lookahead assertions
slug: lookaround
status: full
order: 46
summary: Match a position based on what follows, without consuming it.
---

A lookahead checks what comes *next* without including it in the match. `<?before …>`
succeeds when the following text matches; `<!before …>` succeeds when it does not.
Neither consumes characters — they constrain a position.

## Positive lookahead — `<?before>`

```raku
say "foobar" ~~ /foo <?before bar>/;
say so "foobaz" ~~ /foo <?before bar>/;
```
```output
｢foo｣
False
```

The match is just `foo` (the lookahead adds no characters), and it only succeeds when
`bar` follows — so `foobaz` fails.

## Negative lookahead — `<!before>`

`<!before …>` matches only when the following text does **not** match.

```raku
say so "catfish" ~~ /cat <!before fish>/;
say so "catdog" ~~ /cat <!before fish>/;
```
```output
False
True
```

`cat` is rejected in `catfish` (fish follows) and accepted in `catdog`.

## Notes

- Because a lookahead consumes nothing, the overall match text excludes it — handy
  for "match X only in context Y" without capturing Y.
- Lookbehind is the mirror: `<?after …>` / `<!after …>` constrain what *precedes* the
  position.
- Anchors like `^`, `$`, and word boundaries are themselves zero-width assertions —
  lookarounds generalise the idea to arbitrary patterns.
