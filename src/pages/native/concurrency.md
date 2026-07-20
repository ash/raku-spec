---
title: Concurrency — start, await, react
slug: concurrency
status: full
native: true
order: 10
summary: Promises, supplies and channels — real in Raku++, but the browser can't run threads.
---

Raku++ implements Raku's high-level concurrency: `start` runs a block on another
thread and hands back a `Promise`, `await` waits for results, and `react`/`whenever`
consume asynchronous `Supply` streams. These **work in native Raku++** and match
Rakudo — but the in-browser playground is single-threaded, so the examples here are
shown with their verified output rather than a Run button (see
[the conformance page](/conformance.html) for why).

## start and await

`start { … }` schedules the block on the thread pool and returns a `Promise`;
`await` blocks until it resolves and yields the value.

```raku
my $p = start { 40 + 2 };
say await $p;
```
```output
42
```

Several run concurrently; awaiting each collects its result.

```raku
my $a = start { 2 + 2 };
my $b = start { 3 * 3 };
say await($a) + await($b);
```
```output
13
```

## react / whenever

A `react` block sits and responds to events; each `whenever` subscribes to a
`Supply` and runs its body per emitted value.

```raku
react {
    whenever Supply.from-list(10, 20, 30) -> $v {
        say $v;
    }
}
```
```output
10
20
30
```

## Waiting on many promises

`Promise.allof` completes once every promise in a list has — then each `.result`
is ready.

```raku
my @p = (1..3).map(-> $n { start { $n * 10 } });
await Promise.allof(@p);
say @p.map(*.result);
```
```output
(10 20 30)
```

## Channels

A `Channel` is a thread-safe queue: one thread `.send`s, another reads. Closing it
ends the `.list`.

```raku
my $c = Channel.new;
start { $c.send($_) for 1..3; $c.close }
say $c.list.sort;
```
```output
(1 2 3)
```

## Notes

- The building blocks: `Promise` (`start`, `.then`, `await`, `Promise.allof`/`anyof`),
  `Supply`/`supply`/`emit`/`tap`, `Channel`, and `react`/`whenever`.
- These need real OS threads, which the browser WebAssembly sandbox doesn't provide —
  that's why they're documented here rather than run live.
- In native Raku++ the same code runs with `rakupp yourprogram.raku`.
