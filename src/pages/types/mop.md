---
title: The metaobject protocol  .^
slug: mop
status: partial
order: 65
summary: Introspect types through their metaobject — MRO and attributes work; some metamethods differ.
---

The `.^` operator calls a **metamethod** — a method on a type's metaobject — to ask
about its structure. `.^mro` and `.^attributes` behave as in Rakudo; several other
metamethods are missing or differ (see the gaps).

## Method resolution order — .^mro

`.^mro` lists a type and its ancestors, in the order methods are resolved.

```raku
say Int.^mro.map(*.^name);
```
```output
(Int Cool Any Mu)
```

## Attributes — .^attributes

`.^attributes` returns a class's attributes; `.name` gives each one's `$!`-twigil
name.

```raku
class Point { has $.x; has $.y }
say Point.^attributes.map(*.name);
```
```output
($!x $!y)
```

## Gaps and differences

Several metaobject features differ from the reference:

| Feature | Rakudo (reference) | Raku++ |
| ------- | ------------------ | ------ |
| `Int.^parents` | `()` (works) | not implemented (errors) |
| `5.isa(Numeric)` | `False` (a role, not a superclass) | `True` (includes roles) |
| `C.^methods.map(*.name)` | includes generated methods (`POPULATE`, …) | user methods only |
| `&f.signature.params` | list of parameters | not implemented (errors) |

> `.isa` in Raku++ answers "does it type-match" (including roles), whereas Rakudo's
> `.isa` is strict class inheritance — use `~~` for role/type membership in both.

## Notes

- `.^name` (the type's name) is fully supported — see
  [The type tower & introspection](/types/introspection.html).
- `&sub.arity` and `&sub.count` work directly (see
  [Universal methods](/methods/universal.html)) even though `.signature.params`
  doesn't, so use those for parameter counts.
- The metaobject protocol is how Raku implements classes/roles reflectively; the
  supported subset here covers the common "what does this type look like" queries.
