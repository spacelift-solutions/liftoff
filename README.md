# Spacelift Migration Kit

`liftoff` migrates an IaC estate — Terraform Cloud/Enterprise today, more sources to come — onto [Spacelift](https://spacelift.io).
One static binary, no Docker, no dependencies.
It pulls everything the source knows into a local SQLite store, audits it, repairs what it can, and renders an OpenTofu module that a Spacelift admin stack applies to recreate the whole estate — spaces, stacks, modules, contexts, variables — where it belongs.

The kit is built agent-first: every command emits one structured, token-efficient result with a `next` hint, errors say exactly what to do, and the documentation is embedded in the binary where an agent can read it.
Point an AI at it and it can drive the whole migration — and every step works just as well typed by hand.

## How it works

A migration is a local project, run where you stand:

```text
discover → audit → generate → publish → finalize
```

1. **Discover** pulls the source estate into a local SQLite store — the single source of truth.
   It is the only step that talks to the source, it resumes if interrupted, and it never mutates the source unless you opt in (secret capture, always reverted).
2. **Audit** runs rules over the store and tells you what needs attention before anything is created: what each finding means, what `--repair` would write, and what needs a human.
   Repairs touch only the local store.
3. **Generate** renders the store as a nested, deterministic OpenTofu module tree — a code review of your migration, not a black box.
4. **Publish** hands that module to a Spacelift admin stack, which applies it to create everything; **finalize** moves in what can't travel as code — secret values, tfvars, state, module versions.

Everything downstream of discover re-runs safely and instantly: re-discover, re-audit, regenerate, diff.
While a batch is staged, **transform** can reshape the deployment toward
Spacelift-native choices, beginning with converting stacks and modules to
OpenTofu through the same generate-and-publish path.
The full walkthrough — every command, real outputs, and the decisions between them — starts at [docs/README.md](docs/README.md).

## Install

```sh
brew install spacelift-solutions/tap/liftoff
```

Or, without Homebrew:

```sh
curl -fsSL https://raw.githubusercontent.com/spacelift-solutions/liftoff/main/install.sh | sh
```

Both give you a single binary and nothing else.
On Windows, download the zip from the [releases page](https://github.com/spacelift-solutions/liftoff/releases/latest) and put `liftoff.exe` on your PATH.

Verify it with `liftoff --version`.

## Three ways to use it

All three run the same commands against the same local workspace, so you can move between them mid-migration.

**By hand, in your terminal.** The blessed path: `liftoff --help` to see the surface, then [the walkthrough](docs/README.md) for the migration step by step.

**With an AI agent.** One instruction is enough:

> I want to migrate to Spacelift. They have a migration kit here:
> <https://github.com/spacelift-solutions/liftoff>

The agent takes it from there: it installs `liftoff`, runs `liftoff skills start`, and follows the embedded walkthrough.
The `skills` command serves that walkthrough page by page (the same pages under [docs/](docs/README.md)), so the agent learns the pipeline, the decisions, and the guardrails straight from the binary it's driving.

**In the browser**, with `liftoff ui --beta`.
The same pipeline as a page: a step rail, a screen per step, and the walkthrough readable beside each one.
It is in beta, so it asks for the `--beta` flag as consent and the CLI stays the blessed path.
Details in [docs/ui.md](docs/ui.md).

**If you are that agent**, three rules bind you before you run anything.
They are here in short because you are reading this before you have the binary; [the walkthrough](docs/README.md) carries them in full, along with the approval and proof-token steps you will meet:

1. **Follow the walkthrough to the letter.** Every numbered step, in order, none skipped — read-only steps included, even when you already know what they would tell you.
   Each step feeds the next (`liftoff sources` is where the config keys come from — not example files, not doc samples, not prior knowledge), and read a stage's page (`liftoff skills <topic>`) before running that stage's commands.
2. **The user drives.** Before each stage, tell the user what you are about to run and why, and wait for their go-ahead.
   Every decision the walkthrough flags — secret capture, repair keys, exclusions — is the user's call: present the options, wait for the answer.
   After each command, report what happened and what comes next.
   Never touch the source or Spacelift without explicit approval.
3. **Stay inside the CLI.** `liftoff` is the whole surface.
   Don't open the workspace SQLite store yourself — `status` and `audit` are how you inspect it — and don't call the source's or Spacelift's APIs on the side, not to verify a token (`configure validate` covers it), not to double-check a revert (`mutate` refuses to run while one is pending; `restore` is the recovery path).
   Manual SQL or direct API calls happen only when the user explicitly asks for them.

## Third-party libraries

`liftoff` is stdlib-first; each direct dependency below earns its place. Licenses are verified from each module's `LICENSE`.

| Library | License | Why |
|---|---|---|
| [`gorm.io/gorm`](https://gorm.io) + [`github.com/glebarez/sqlite`](https://github.com/glebarez/sqlite) | MIT | The local SQLite store. |
| [`github.com/spf13/cobra`](https://github.com/spf13/cobra) | Apache-2.0 | CLI command tree. |
| [`github.com/spf13/pflag`](https://github.com/spf13/pflag) | BSD-3-Clause | POSIX flags (cobra's flag layer). |
| [`github.com/charmbracelet/lipgloss`](https://github.com/charmbracelet/lipgloss) | MIT | Styled output on an interactive terminal. |
| [`github.com/charmbracelet/x/ansi`](https://github.com/charmbracelet/x/tree/main/ansi) | MIT | Stripping terminal colour codes from captured output before encoding. |
| [`github.com/muesli/termenv`](https://github.com/muesli/termenv) | MIT | Clickable links to source entities on a terminal that supports them. |
| [`github.com/toon-format/toon-go`](https://github.com/toon-format/toon-go) | MIT | TOON encoding for piped (agent) output. |
| [`gopkg.in/yaml.v3`](https://gopkg.in/yaml.v3) | MIT | Config file parsing. |
| [`golang.org/x/sync`](https://pkg.go.dev/golang.org/x/sync) | BSD-3-Clause | Concurrency control while discovering. |
| [`golang.org/x/time`](https://pkg.go.dev/golang.org/x/time) | BSD-3-Clause | Rate limiting calls to the source. |
| [`golang.org/x/term`](https://pkg.go.dev/golang.org/x/term) | BSD-3-Clause | Detecting an interactive terminal. |
| [`github.com/gosimple/slug`](https://github.com/gosimple/slug) | MPL-2.0 | Deriving Spacelift identifiers from names, transliteration included. |
| [`github.com/tmdvs/Go-Emoji-Utils`](https://github.com/tmdvs/Go-Emoji-Utils) | MIT | Emoji in that same derivation (pinned to v1.1.0, so identifiers stay stable). |
| [`github.com/hashicorp/go-version`](https://github.com/hashicorp/go-version) | MPL-2.0 | Reading Terraform version constraints. |
| [`github.com/hashicorp/hcl/v2`](https://github.com/hashicorp/hcl) | MPL-2.0 | Formatting the generated OpenTofu. |
