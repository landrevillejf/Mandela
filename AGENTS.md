# AGENTS.md — lg3d-mandela

> Role-aware guide for everyone working on **lg3d-mandela** (Project Mandela, a
> zero-dependency scripting language for the JVM). This repository is standalone:
> this file is its own governance — the build system, module map, exclusions and
> commit conventions all live here, and the shared per-role view below keeps **all
> roles coherent**. Mandela originated in the ProjectLookingGlass desktop and is
> still embedded by it, but nothing in this repository depends on that tree.

## Module at a glance

| Item | Value |
| --- | --- |
| Purpose | **Project Mandela**: an embeddable scripting language — lexer, parser, AST, bytecode compiler, stack VM, capability-gated runtime, standard library, JSR-223 engine, embedding API, CLI and REPL, in one jar. |
| Root package | `org.jdesktop.lg3d.mandela` — `lang` · `code` · `vm` · `values` · `rt` · `api` · `cli` |
| Source layout | Maven-standard `src/main/java`, `src/test/java`, `src/main/resources` (not the `src/classes` layout the other modules use) |
| Language / encoding | Java 21, **UTF-8** (the root default) |
| Depends on | **Nothing** — no repo module, no third-party jar. `java.base` + `javax.script` only. |
| Depended on by | **Nothing in this repository.** Downstream, any Java/Kotlin host may drop the jar on its classpath; the ProjectLookingGlass desktop embeds it (Espresso's `MandelaTools`, the Web Browser's `MandelaUserscriptsExtension`), but those hosts live in their own tree, not here. |
| Jar | `build-gradle/libs/lg3d-mandela-<version>.jar`, `Main-Class: …mandela.cli.MandelaCli` |
| Version | **Its own** two axes: `mandela.version` (the jar, `1.1.0`) and `mandela.language` (the grammar, `1.0`) in [`gradle.properties`](gradle.properties), mirrored in `api.Mandela`'s two constants and the jar manifest. `mandela-version.mnd` gates all eight copies; the policy and the release record are in [CHANGELOG.md](CHANGELOG.md). |
| Build | `./gradlew build` |
| Run | `./gradlew mandelaRun -Pscript=hello.mnd` · `mandelaRepl` |
| Tests | `./gradlew test` — 1473 headless cases (`java.awt.headless=true`): 1289 JUnit 5 tests plus the 184-scenario Cucumber `MandelaSuite` |
| Mutation | `./gradlew pitest` (report-only, on-demand, **not** in `check`) |
| Docs | [`docs/mandela-language.md`](docs/mandela-language.md) (the grammar and the library) · [`docs/mandela-embedding-api.md`](docs/mandela-embedding-api.md) (the host contract) |

**Nature of the module:** a language *is* a contract. Every grammar decision,
every error message and every capability default is something host applications
(an editor, a browser) and user-written `.mnd` scripts depend on. Correctness
here is measured by parsing and execution behaviour, not by anything rendered.

## How the roles work together

The Architect owns the package layering and the sandbox boundary; the Engineer
keeps the jar dependency-free and the grammar unambiguous; QA verifies through
the parser, the machine and the two host-facing surfaces (no live host needed,
which is why this module is so thoroughly tested); the Business Analyst
guards "a script is a host's automation surface"; the Functional Analyst
keeps the grammar and the capability model explicitly rationalised; the PM
tracks the blast radius into downstream hosts. A disagreement is settled in the
PR, never silently in code.

## Architect

- **Dependency direction:** `lang` is a leaf (it knows nothing above it). `code`
  and `values` are the inner pair — a compiled body is callable, so they
  reference each other and that is the one accepted cycle. `vm` runs on them,
  `rt` wires machine + library + capabilities, `api` is the **only** package a
  host should import, `cli` is outermost. Never let `lang`, `values` or `code`
  import `rt`, `api` or `cli`.
- **Zero dependencies is the feature.** No AWT, no Swing, no Java 3D, no
  host framework, no library jar: that is what lets the same `Runtime` run inside
  a headless test, inside a host's JVM and inside a browser page. A single
  `import java.awt.` here breaks the module's reason for existing.
- Any hosts live outside this repository. This module must never reference
  `org.jdesktop.lg3d.*` at all — a host binds the language through `api`, the
  language never reaches back into a host.
- `META-INF/services/javax.script.ScriptEngineFactory` is a published
  registration; the JSR-223 names and MIME types in `api.Mandela` are part of the
  contract for hosts that discover the engine.
- The CLI's exit codes (`0` ok, `1` usage, `2` the program failed, `3` a named
  file was unreadable, `4` `check` found a blocking diagnostic) are a contract
  with scripts and CI, not a convenience — they are the `MandelaCli` constants,
  and the embedding guide tabulates them.

## Engineer / Developer

- **The grammar is the single source of truth.** A host that needs keywords,
  diagnostics, an outline or completions calls `api.EditorServices` and
  `api.Mandela.check` — it never re-implements a regex. When you add syntax, the
  keywords, `EditorServices.vocabulary`, the language guide and any host all read
  the same tables automatically; if you find yourself painting a word in a host,
  you have built a second grammar.
- New keywords are **contextual by default**. `Keywords.RESERVED` is 34 words,
  pinned word-for-word by `EditorServicesTest`, and it grows only where the parser
  already has a position for the word; a soft
  keyword (`init`, `export`, `step`) costs no script its name. Never make a word
  reserved because it is convenient.
- An ambiguity must be resolved by a rule that is *visible in the error*, not by
  a heuristic that silently mis-parses. Precedent: the trailing lambda
  (`xs.map { x -> x * 2 }`) requires the block to open on the same line as the
  call **and** to carry a `->` header at nesting level one — which is exactly
  what keeps `for x in items() { … }` a loop body and `match f(2) { 1 => … }` a
  match block. Copy that reasoning style.
- Every side effect goes through `Capabilities.require(grant, what)` and every
  budget through the machine. A new stdlib function that touches the host must
  name the grant it needs in its error message; a grant with no consumer is
  documented as *reserved* rather than quietly hooked to something.
- Values cross the boundary only through `rt.HostValues` / `api.Interop`, and
  **refusing an arbitrary object is the security model** — do not "make
  binding easier" by reflecting over a POJO.
- Errors are `MandelaError` (kind + message, catchable in scripts) or
  `LangException` (carries a `Diagnostic`). Do not throw a bare
  `RuntimeException` at script-visible code: the host has nothing to show then.
- A `Diagnostic.rule` id is a host-facing contract, and there are exactly three
  today: `"syntax"` (the grammar cannot read it), `"undefined-name"` (a name with
  no declaration — routine while a buffer is being typed, so an editor marks it
  without stopping the run) and `"param-order"` (a warning). Add an id only where
  a host branches on it, and document the whole set in `lang.Diagnostic` and both
  guides in the same PR.
- Name resolution sees the **declared** class hierarchy: inside
  `class Meter() extends Counter`, a bare `total` or `bump(2)` is the base's
  member, own members win over inherited ones, and `Compiler.seedInherited` is
  where that walk lives. A base the compiler cannot see (a host binding) adds no
  names, so the honest `unknown name` stands and `this.total` is the documented
  escape hatch — do not "fix" that by string lookup at run time.
- Keep the jar's text honest: the javadoc examples are syntax the parser
  accepts. An example using `fn` or a trailing-lambda with an implicit `it` is a
  defect, because a host copies it.
- Warnings are disabled repo-wide and the tree is large; do not reformat
  unrelated files.

## QA

- Everything here is headless and fast: `./gradlew test`.
  Suites by surface — `SyntaxTest` (what parses, and the exact fragment of the
  message a mistake produces), `LanguageTest` (end-to-end semantics),
  `StandardLibraryTest` (every library member), `ValuesTest` + `ValueTypesTest` +
  `IterationTest` (value semantics: names, truth, display, equality, order,
  conversion, the containers, and the cursor a `for` drives), `OperatorRulesTest`
  and `ArithmeticOverflowTest` (what an operator answers and when it promotes),
  `ClosureCaptureTest` (the capture chain), `EmbeddingApiTest` +
  `InteropTest` + `HostBoundaryTest` + `ScriptEngineTest` (the host contract),
  `api/EditorServicesTest` (the editor surface), `CliTest` (the command line),
  `DocumentationTest` (the guide), `ShippedScriptsTest` (the scripts the
  repository ships in `scripts/mandela`).
- **The language guide is a tested artifact.** `DocumentationTest` extracts every
  `` ```mandela `` block from
  [`docs/mandela-language.md`](docs/mandela-language.md), parses it with the
  real parser and compiles it, allowing only the `undefined-name` finding a
  fragment is entitled to (a value the prose introduced). A block that abbreviates
  code carries an elision marker (`…`) and is skipped, and the test fails if too
  few blocks are found, so a broken extractor cannot make it vacuously green.
- **The repository's own automation is tested too.** `ShippedScriptsTest`
  compiles every `.mnd` under
  [`scripts/mandela/`](scripts/mandela/) with **no** finding excused — a
  shipped script is a complete program, unlike a guide fragment — and pins the
  header conventions (shebang, one-line purpose, the `-s` sandbox it must be run
  with) that keep that directory usable. The eight gates that read trees present
  here run in CI as `repositoryChecks` (`docLinksCheck`, `htmlLinksCheck`,
  `releaseCheck`, `mandelaVersionCheck`, `changelogCheck`, `scriptsHygieneCheck`,
  `whatsNewCheck`, `legacyJ3dCheck`), which are intentionally *not* part of
  `check`: they audit the whole tree, so their failures belong to the step that
  ran them, not to this module's build. A further eleven gates inherited from the
  ProjectLookingGlass desktop (start menu, accelerators, i18n, wonderland,
  run-classpath, the coverage/mutation/CVE/exclusion floors, bgconfigs,
  help-topics) stay registered and individually runnable but audit trees absent
  here, so `scripts-hygiene.mnd`'s `DESKTOP_ONLY` set exempts them from the
  aggregate — kept for parity, never deleted. `whatsNewCheck` is the one gate
  that compares **committed generated files** (the `documentation/releases/*.html`
  archive against `CHANGELOG.md`); its generator half is `whatsNewRefresh`,
  which is a plain task and never runs under `check` — a check may not rewrite
  the tree.
- **A grammar change is a two-sided test**: add the accepted form *and* pin the
  construct that must not be swallowed by it. A parse that silently changes
  meaning is worse than one that fails.
- Error-message text is asserted by fragment, so a wording change is a test
  change — say so in the PR.
- Coverage and mutation: the 100% JaCoCo / 0-PIT-mutant targets are **not**
  enforced (report-only). Do not claim untested success; report what
  ran. The campaign is package by package, and `values` is done: **809 of 809
  lines**, with the module at 91.49 % line / 81.86 % branch. A package that
  reaches every line keeps it —
  retire what no script and no host can reach instead of testing it, and say in
  the PR what stayed unreachable and why (the `cli` REPL's terminal handling is
  the current example). Scene-graph rules do not apply — nothing here needs a live
  host or an in-JVM probe; a host that wants one binds the surface under test
  through `api.Interop` and drives it from a script.
- When Gradle is memory-starved locally, `build-gradle/scratch/junit.sh`
  compiles the same sources and runs the suite in one JVM. Its output is build
  scratch and must never be committed.
- Add / maintain the test suite. Unit tests and BDD. Add new scenarios in Cucumber for each new feature, maintain existing ones. Automate manually whenever possible.

## Business Analyst

- The customer is twofold: the user who automates a task in a `.mnd`
  file, and the developer who embeds the language in an application. Both pay
  for the same promise — *fast, secure, light-weight, Java/Kotlin-compatible* —
  and neither pays for a new language feature that a host cannot reach through
  `api`.
- A capability story is a product story: "a page script cannot read your disk"
  is the feature that lets a browser host ship userscripts without a consent
  dialog beyond the existing content-script gate.

## Functional Analyst

- The functional contract is the grammar (§1–§8 of the language guide), the
  standard-library surface (§9), the capability model (§10) and the host API
  (the embedding guide). Behaviour changes are written as *what a script
  observes*: the kind of error, the value of the last expression, the grant named
  in the message.
- Keep the rationale for each rule living with the rule. If a construct is
  refused — no alternation in `match` arms, no alias on `use`, no implicit
  lambda parameter — the guide must say why, so the next author does not
  "restore" it as a polish item.
- If `Capabilities` gains a grant or a profile changes a budget, that is a
  security-relevant change: flag it to the Architect and the PM before code
  lands, and update both guides in the same PR.

## Project Manager

- Scope: a language change is **high-blast-radius, low-frequency** — every
  downstream host and every user script reads it. Schedule grammar work with an
  explicit host-impact review, and keep host-side work in the host's own
  repository, not here.
- Commit scope is `lg3d-mandela` (or `agents` for this file). Follow branch →
  commit → push → PR against `main`; never commit directly to `main`.
- **A Mandela version bump is its own chore PR.** Edit `mandela.version` (and
  `mandela.language` when the grammar changed), `api.Mandela`'s matching
  constant, the guide line under its title and a new header in
  [CHANGELOG.md](CHANGELOG.md) — `mandelaVersionCheck` is red until all four
  agree. The release train (`scripts/release/`) never rewrites the language axis.
- Definition of done: `test` green, `repositoryChecks` green, both guides updated
  in the same PR, and no new dependency in `build.gradle`.

## UI/UX

**Not applicable.** The module renders nothing: no `Component3D`, no
`SwingNode`, no Swing. The one user-visible surface it produces is *vocabulary* —
the keywords, completions and outline entries an editor paints — and that comes
from `api.EditorServices`, in a stable order, so a host can present it
without inventing anything. UI/UX guidance for the surfaces lives in the
ProjectLookingGlass desktop repository, not in this standalone one: its
`lg3d-core/AGENTS.md` (the rulebook), the Espresso text editor's
`lg3d-apps/.../texteditor/AGENTS.md` and the Web Browser's
`lg3d-apps/.../webbrowser/AGENTS.md`.

## Communication & coherence

- Single source of truth: this file governs the module, the build, the exclusions
  and the commit conventions — there is no parent repository above it. If a guide
  and this file conflict, this file wins and the guide gets fixed in the same PR.
- The language guide, the embedding guide and this file quote the same grammar.
  When the grammar changes, all three move in the same PR — a stale guide is a
  bug a user finds first, and `DocumentationTest` now finds it before they do.
- Every PR states: which construct or grant changed, the downstream host impact,
  and the verification run.

## Commit / PR

- Conventional Commit scope: **`lg3d-mandela`** (or `agents` for this file).
  Types: `feat` for a grammar or API capability, `fix` for a mis-parse or a wrong
  message, `docs` for guide-only work, `chore` for a version bump or tooling.
- Subject ≤ 50 chars in the imperative, body wrapped at 72 and explains *why* —
  a language decision without its rationale is a decision that gets reverted.
- Add a `CHANGELOG.md` bullet under `[Unreleased]`; do **not** bump the version
  (that is a separate chore PR).
- Stage only intended paths — never `git add -A` (`build-gradle/`, scratch
  harnesses and screencapture PNGs live in the tree). Sign with the repository
  committer identity (`Signed-off-by:`), branch off `main`, PR via `gh`, and
  wait for approval before merging.
