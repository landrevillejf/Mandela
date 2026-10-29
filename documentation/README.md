# documentation/ — the Project Mandela Pages site

This directory is the **committed** content of the GitHub Pages site that
[`.github/workflows/deploy-docs.yml`](../.github/workflows/deploy-docs.yml)
publishes. Everything here is static prose and generated HTML; nothing the build
produces (the Javadoc, the test reports) is ever committed under `documentation/`.

## What lives here

| Path | Kind | Source of truth |
| --- | --- | --- |
| `index.html` | the portal every card routes from | hand-written |
| `releases/index.html` | the release archive index | generated |
| `releases/<version>.html` | one page per released version | generated |

The pages under `releases/` are **generated** from
[`CHANGELOG.md`](../CHANGELOG.md) by
[`scripts/mandela/whats-new.mnd`](../scripts/mandela/whats-new.mnd):

```
./gradlew whatsNewRefresh    # render and write every page
./gradlew whatsNewCheck      # gate: are the committed pages current?
```

Never edit a page under `releases/` by hand — `whatsNewCheck` compares it byte
for byte against the changelog and fails the build when they drift.

## The guides

Every guide is Markdown under [`docs/`](../docs/) and is read on GitHub; the
portal (`index.html`) surfaces the whole set — the language guide, the embedding
guide, the module index, architecture, functional analysis, development guide,
usage, roadmap, history and `AGENTS.md` — each card linking to its GitHub blob
URL:

- [`docs/mandela-language.md`](../docs/mandela-language.md) — the grammar, the
  standard library and the capability model.
- [`docs/mandela-embedding-api.md`](../docs/mandela-embedding-api.md) — the host
  contract.
- [`docs/README.md`](../docs/README.md), [`ARCHITECTURE.md`](../docs/ARCHITECTURE.md),
  [`FUNCTIONAL_ANALYSIS.md`](../docs/FUNCTIONAL_ANALYSIS.md),
  [`DEVELOPMENT.md`](../docs/DEVELOPMENT.md), [`USAGE.md`](../docs/USAGE.md),
  [`ROADMAP.md`](../docs/ROADMAP.md), [`HISTORY.md`](../docs/HISTORY.md) and
  [`../AGENTS.md`](../AGENTS.md).

The guides are Markdown, not HTML, and this site is a static copy of
`documentation/` with no renderer in it, so the portal links them at their GitHub
blob URL rather than republishing them: a reader of the site reaches the same
text a reader of the repository does, and there is no second copy to drift. The
release pages are the exception — `whats-new.mnd` renders them to HTML here, and
re-bases each changelog link onto its blob URL (clamping any `..` that would
escape the repository root, so a stale relative link cannot produce a dead
`/../` address on the published page).
