---
title: Hello, Slidev
theme: default
---

# Hello, Slidev

Slides as markdown — versioned, diffable, reviewable.

---

# Why markdown slides?

- Plain text → lives in git next to the code
- Code highlighting out of the box
- Hot reload while you write
- Builds into a static site

---

# Code highlighting

```ts {2-3}
function greet(name: string) {
  const greeting = `Hello, ${name}!`
  return greeting
}
```

---
layout: two-cols
---

# Left

Slides are separated by `---`.

::right::

# Right

Per-slide frontmatter picks the layout.

---
layout: center
---

# That's it

`npm run dev -- decks/hello-slidev.md`
