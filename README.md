# talks

My personal collection of [Slidev](https://sli.dev) presentations on IT topics.

## Add a deck

Drop a markdown file into `decks/`. The filename (without `.md`) becomes the URL slug.
Start it with frontmatter:

```md
---
title: My Talk
theme: default
---

# First slide
```

## Preview locally

```bash
npm install
npm run dev -- decks/<name>.md
```

## Build locally

```bash
BASE=/talks/ npm run build
```

Output goes to `public/`: one folder per deck plus `index.html` listing all decks.

Pages is a static host, so opening a slide URL directly (e.g. `/talks/git-basics/2`)
gives a 404; clicking through from the deck root works. Need shareable slide links?
Add `routerMode: hash` to that deck's frontmatter.

## Deploy

Every push to the default branch runs the `pages` job in `.gitlab-ci.yml` and
publishes to `https://<user>.gitlab.io/talks/`.
