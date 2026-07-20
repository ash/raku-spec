---
title: Native types — int / num / str
slug: native
status: full
order: 70
summary: Fixed-width machine types without the object wrapper, as scalars and arrays.
---

Lowercase `int`, `num`, and `str` are **native** types — fixed-width machine values
without the object wrapper of `Int`/`Num`/`Str`.

## Native scalars

A native scalar holds a machine value but introspects as its boxed type.

```raku
my int $x = 5;
say $x;
say $x.WHAT;
```
```output
5
(Int)
```

## Native arrays

A `my int @a` is a genuinely unboxed `array[int]` — a packed array of machine
integers, distinct from the object `Array`.

```raku
my int @a = 1, 2, 3;
say @a;
say @a.WHAT;
```
```output
[1 2 3]
(array[int])
```

## Notes

- Native scalars are for performance and interop; you rarely need them in ordinary
  code, where `Int`/`Num`/`Str` are the defaults.
- A native value can't hold a type object (there's no "undefined" machine int), so
  native variables default to `0`/`0e0`/`""` rather than an undefined value.
- The boxed types (`Int`, `Num`, `Str`) are what nearly every example elsewhere in
  this spec uses.
