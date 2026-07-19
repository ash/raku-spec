# raku-spec — the Raku++ Specification site

The behavioural specification of [Raku++](https://github.com/ash/rakupp), served at
**[spec.raku.online](https://spec.raku.online/)**. Every feature is explained in
detail — syntax, examples, combinations, edge cases — and **every example runs live
in the browser** via the same WebAssembly interpreter that powers the
[raku.online](https://raku.online/) playground ([source](https://github.com/ash/raku.online)).

Where [Roast](https://github.com/Raku/roast) is a conformance *test suite* and
[docs.raku.org](https://docs.raku.org/) documents the *library*, this site aims to
pin down the *last-mile behaviour* of the interpreter itself, so there is never a
question of *why* a construct behaves as it does — for the Raku++ scope.

## The toolchain is Raku++ itself

The generator is written in Raku and run by `rakupp`; the site is previewed with
`rakus`, the Raku++ static file server. Building the spec is itself an act of
dogfooding the interpreter it documents.

## Layout

```
build.raku            the static generator (run by rakupp)
deploy.sh             build + verify + publish to the server doc root
src/
  site.raku           site config (title, category order) — EVAL'd by the build
  theme/
    base.css          light/dark theme; sidebar layout; status badges
    spec.js           mobile nav toggle (editors are handled by embed.js)
  pages/
    <category>/<slug>.md   one feature per file (frontmatter + Markdown-ish body)
out/                  generated static site (git-ignored)
```

## Authoring a page

Each page is a Markdown-ish file with frontmatter:

```
---
title: Integer literals
slug: integers          # optional; defaults to the filename
status: full            # full | partial | divergent | ni
order: 10               # sort order within the category
summary: One-line teaser shown in nav cards and the page header.
---

## A heading

Prose with `inline code`, **bold**, *italic*, and [links](/other/page.html).
```

A fenced ` ```raku ` block becomes a **runnable, editable** editor. Follow it with a
` ```output ` block to declare the expected output — that pairing is both rendered
on the page *and* checked by `--verify`:

    ```raku
    say 1/3;
    ```
    ```output
    0.333333
    ```

Fence options: ` ```raku run ` auto-runs on load; ` ```raku stdin="Ada\nGrace" `
presets standard input; ` ```raku rows="8" ` sets the editor height. Other fenced
languages (`syntax`, `text`, or anything else) render as static code blocks.

## Build & preview

`rakupp` is the Raku++ interpreter (expected on `PATH`; override with `--rakupp=PATH`).

```sh
# build to out/
rakupp build.raku

# build and check every example's output against the real interpreter
rakupp build.raku --verify

# preview locally with rakus (the Raku++ static server, from the raku++ repo),
# then open http://127.0.0.1:8080/
rakupp path/to/raku++/showcase/rakus/rakus.raku 8080 out
```

> Verify against the interpreter build that raku.online serves, so the spec
> matches the engine the runnable examples use. Pin it with `--rakupp=PATH`.

## Deploy

`./deploy.sh` builds, runs `--verify` (aborting on any example drift), and mirrors
`out/` to the server doc root. It reads two settings — with no paths hard-coded —
from a git-ignored `./.deploy.env`, the environment, or an argument:

```sh
RAKUPP      interpreter to build/verify with    (default: rakupp on PATH)
SPEC_DEST   destination directory to publish to  (or pass as ./deploy.sh <dir>)
```

The engine is **not** copied here — pages load `https://raku.online/embed.js`,
reusing the interpreter and cache of the
[raku.online](https://github.com/ash/raku.online) playground.
