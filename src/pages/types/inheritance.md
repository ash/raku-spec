---
title: Inheritance
slug: inheritance
status: full
order: 20
summary: Derive a class with `is`, and override methods in the subclass.
---

A class inherits from another with `is`. The subclass gains the parent's attributes
and methods, and may **override** any method by declaring one of the same name.

## Subclass and override

```raku
class Animal {
    method speak { "..." }
}
class Dog is Animal {
    method speak { "Woof" }
}
say Dog.new.speak;
```
```output
Woof
```

`Dog` inherits from `Animal` but replaces `speak`, so `Dog.new.speak` is `Woof`.

## Notes

- Call the overridden parent method with `self.Animal::speak` or, more commonly,
  `callsame` inside the override to run the next candidate.
- Raku supports multiple inheritance (`is A is B`), but composing **roles** is
  usually the better tool for sharing behaviour — see [Roles](/types/roles.html).
- Every class ultimately inherits from `Mu` (via `Any`), which is where universal
  methods like `.WHAT` and `.defined` come from.
