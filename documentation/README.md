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

The language guide and the embedding guide are Markdown under `docs/` and are
read on GitHub:

- [`docs/mandela-language.md`](../docs/mandela-language.md) — the grammar, the
  standard library and the capability model.
- [`docs/mandela-embedding-api.md`](../docs/mandela-embedding-api.md) — the host
  contract.

The portal links to them at their GitHub blob URL, so a reader of the published
site reaches the same text a reader of the repository does.
