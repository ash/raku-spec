---
title: Roles
slug: roles
status: full
order: 30
summary: Reusable bundles of behaviour composed into classes with `does`.
---

A `role` packages methods (and attributes) for reuse. A class **composes** a role
with `does`, flattening the role's members into the class. Roles are Raku's
preferred alternative to deep inheritance for sharing behaviour.

## Composing a role

```raku
role Greet {
    method hello { "Hi, I am " ~ self.name }
}
class Person does Greet {
    has $.name;
}
say Person.new(name => "Ada").hello;
```
```output
Hi, I am Ada
```

The role's `hello` becomes a method of `Person`, and `self.name` resolves against
the composing class's attribute.

## Notes

- Composition is flattening, not delegation: a method conflict between two composed
  roles is a **compile-time** error, which you resolve explicitly — unlike the
  silent shadowing of multiple inheritance.
- A role can require methods (`method name { ... }` stub) that the composing class
  must provide, forming an interface contract.
- Roles can also be applied to a single object at runtime with
  `$obj does SomeRole`, mixing behaviour into one instance.
