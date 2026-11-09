---
title: Git Basics
theme: default
---

# Git Basics

Snapshots, not diffs.

---

# What is git?

- A distributed version control system
- Every clone has the full history
- A commit is a snapshot of the whole tree plus a pointer to its parent

---

# Three places your changes live

```text
working tree  --git add-->  index (staging)  --git commit-->  history
```

- `git status` shows what is where
- `git diff` shows working tree vs index
- `git diff --staged` shows index vs last commit

---

# Branches

A branch is just a movable pointer to a commit.

```bash
git switch -c feature/login
# ...work, commit...
git switch main
git merge feature/login
```

---

# Everyday commands

| Command | What it does |
|---|---|
| `git log --oneline --graph` | history at a glance |
| `git restore <file>` | discard working tree changes |
| `git commit --amend` | fix the last commit |
| `git pull --rebase` | update without merge bubbles |
