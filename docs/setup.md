# Set up and configure

Steps 1–4 of [the migration walkthrough](start.md): scaffold the workspace,
pick a source, set its credentials, and validate the configuration before
anything runs.

## Before you start — install liftoff

```bash
brew install spacelift-solutions/tap/liftoff
```

Without Homebrew:

```bash
curl -fsSL https://raw.githubusercontent.com/spacelift-solutions/liftoff/main/install.sh | sh
```

On Windows, download the zip from the
[releases page](https://github.com/spacelift-solutions/liftoff/releases/latest)
and put `liftoff.exe` on your PATH.

Either way you get one binary and nothing else — no runtime, no container, no
services. Check it answers before going further:

```bash
liftoff --version
```

To upgrade later, `brew upgrade liftoff`, or re-run the install script.

### Release candidates

`brew install spacelift-solutions/tap/liftoff` is always the current stable
release — a candidate can never arrive there by surprise. Candidates are a
separate cask you have to ask for by name:

```bash
brew install spacelift-solutions/tap/liftoff-rc
```

Both provide the same `liftoff` command, so Homebrew will not let you have
both at once. Switch back with:

```bash
brew uninstall liftoff-rc && brew install spacelift-solutions/tap/liftoff
```

### Installing a specific version

Homebrew carries the newest build of each line and nothing older, so an exact
version comes from the install script:

```bash
VERSION=v1.3.0 curl -fsSL https://raw.githubusercontent.com/spacelift-solutions/liftoff/main/install.sh | sh
```

Pinning is what you want in CI, where "whatever is newest" is not a build you
can reproduce. The tags are on the
[releases page](https://github.com/spacelift-solutions/liftoff/releases).

`INSTALL_DIR` puts the binary somewhere other than `/usr/local/bin` — reach for
it when that directory needs root:

```bash
INSTALL_DIR="$HOME/.local/bin" curl -fsSL https://raw.githubusercontent.com/spacelift-solutions/liftoff/main/install.sh | sh
```

## Step 1 — initialize the workspace

```bash
liftoff init
```

Creates `./.liftoff/` in the current directory with an empty `config.yaml`
and the SQLite store.

```text
Config Created  yes
Config Dir      /tmp/migration-demo/.liftoff
Config Path     /tmp/migration-demo/.liftoff/config.yaml
Db Path         /tmp/migration-demo/.liftoff/liftoff.db

Next
  $ liftoff sources
  $ liftoff configure --source <id> --set source.<key>=value
```

Running `init` again on an existing workspace reports `Config Created  no`
and changes nothing, so it is safe to repeat. On a workspace created by an
older binary it migrates the store schema forward.

The only decision here is where to stand. The workspace goes under the
current directory, one directory per migration. `--config-dir` or
`LIFTOFF_CONFIG_DIR` relocates it, but every later command needs the same
value.

One warning: `config.yaml` will hold your source API token after step 3, and
the store holds everything discover pulls, variable values included. If
you are running inside a git repository, ignore the workspace now:

```bash
echo '.liftoff/' >> .gitignore
```

Next up, `liftoff sources` to see what you can migrate from.

## Step 2 — pick a source

```bash
liftoff sources
```

Lists every source this binary can migrate from, with the settings each one
takes. Read-only; run it as often as you like.

```text
Sources (1)
  Terraform Cloud / Enterprise (id: terraform)
    Config Keys (used in `liftoff discover`) (4)
      ┌────────────────────┬───────────────────────┬──────────┬─────────────────────┬─────────────────────┬────────────┐
      │ Label              │ Key                   │ Required │ Default             │ Help                │ When Unset │
      ├────────────────────┼───────────────────────┼──────────┼─────────────────────┼─────────────────────┼────────────┤
      │ API endpoint       │ api_endpoint          │ –        │ https://app.terrafo │ Base URL of the     │            │
      │                    │                       │          │ rm.io               │ Terraform API; set  │            │
      │                    │                       │          │                     │ it to reach a self- │            │
      │                    │                       │          │                     │ hosted Terraform    │            │
      │                    │                       │          │                     │ Enterprise          │            │
      │ API token          │ api_token             │ ✓        │                     │ Token used to       │            │
      │                    │                       │          │                     │ authenticate with   │            │
      │                    │                       │          │                     │ the Terraform API — │            │
      │                    │                       │          │                     │ must be a user      │            │
      │                    │                       │          │                     │ token from an admin │            │
      │                    │                       │          │                     │ user (team and      │            │
      │                    │                       │          │                     │ organization tokens │            │
      │                    │                       │          │                     │ do not work)        │            │
      │ Requests per       │ requests_per_second   │ –        │ 30                  │ Per-source API rate │            │
      │ second             │                       │          │                     │ limit               │            │
      │ Workspace          │ workspace_concurrency │ –        │ 8                   │ How many workspaces │            │
      │ concurrency        │                       │          │                     │ are enriched at     │            │
      │                    │                       │          │                     │ once                │            │
      └────────────────────┴───────────────────────┴──────────┴─────────────────────┴─────────────────────┴────────────┘

    Repair Keys (used in `liftoff audit --repair`) (2)
      ┌──────────────────────┬──────────────────────┬──────────┬─────────┬──────────────────────┬──────────────────────┐
      │ Label                │ Key                  │ Required │ Default │ Help                 │ When Unset           │
      ├──────────────────────┼──────────────────────┼──────────┼─────────┼──────────────────────┼──────────────────────┤
      │ Module workflow tool │ module_workflow_tool │ –        │         │ What to write for    │ empty module         │
      │                      │                      │          │         │ modules exported     │ workflow tools stay  │
      │                      │                      │          │         │ with an empty        │ unrepaired until     │
      │                      │                      │          │         │ workflow tool:       │ this is set          │
      │                      │                      │          │         │ `TERRAFORM_FOSS`,    │                      │
      │                      │                      │          │         │ `OPEN_TOFU`, or      │                      │
      │                      │                      │          │         │ `CUSTOM`             │                      │
      │ Default branch       │ default_branch       │ –        │ main    │ What to write for    │                      │
      │                      │                      │          │         │ stacks and modules   │                      │
      │                      │                      │          │         │ exported with no     │                      │
      │                      │                      │          │         │ branch (they track   │                      │
      │                      │                      │          │         │ their repo's         │                      │
      │                      │                      │          │         │ default)             │                      │
      └──────────────────────┴──────────────────────┴──────────┴─────────┴──────────────────────┴──────────────────────┘

    Mutations (1)
      ┌─────────┬──────────────────────────────────────────────────┬───────────────────────────────────────────────────┐
      │ Name    │ Description                                      │ When Unset                                        │
      ├─────────┼──────────────────────────────────────────────────┼───────────────────────────────────────────────────┤
      │ secrets │ capture sensitive variable values via a          │ sensitive variable values come over empty; stage  │
      │         │ temporary agent — mutates the source, always     │ the workspaces and run `liftoff mutate --allow-   │
      │         │ reverted                                         │ mutation secrets` to capture them, or set them in │
      │         │                                                  │ Spacelift after the migration                     │
      └─────────┴──────────────────────────────────────────────────┴───────────────────────────────────────────────────┘

Next
  $ liftoff configure --source <id> --set source.<key>=value
```

What to take from this screen:

- **The id in the title is what you pass to `configure --source`.** Here that
  is `terraform`, which covers both Terraform Cloud and self-hosted Terraform
  Enterprise.
- **Config Keys is your settings checklist.** Only the checked `Required`
  keys must be set (`api_token` here). Everything else has a `Default` you
  can live with, or a `When Unset` telling you what not setting it means. On
  Terraform Enterprise you will also need `api_endpoint` pointed at your
  install.
- **Repair Keys are not for discover.** They feed `liftoff audit --repair` in
  step 7 and only come into play when an audit has findings to fix. You can
  set them now with everything else, and change them later by re-running
  configure.
- **Mutations preview a later, opt-in step.** Discover never changes the
  source; the one step that does — `liftoff mutate` — is opt-in and per run,
  so you pass `--allow-mutation <name>` on every `mutate` that should use it,
  which is why mutations are not config keys. The `secrets` mutation here is
  the one worth planning for: without it, sensitive variable values come over
  empty and you re-enter them in Spacelift afterwards; with it, `mutate`
  captures them through a temporary agent and reverts the source when done.
  Nothing to do now — the [mutate](mutate.md) step shows the flag.

The decision at this step is which source you are migrating from and, if it
is self-hosted, what its API endpoint is. Note the id and move on.

## Step 3 — configure the source

```bash
liftoff configure --source terraform --set source.api_token='${TFC_TOKEN}'
```

Records the source and its settings in `config.yaml`. Values can reference
environment variables: single-quote the reference so your shell doesn't
expand it, and `config.yaml` stores the literal `${TFC_TOKEN}` — the value is
resolved when a command runs, so the token itself never has to be written to
disk. A reference that doesn't resolve is an error, not an empty string.
Pasting the raw token works too; it just lives in `config.yaml` (and your
shell history) instead.

`--set` repeats, and configure is incremental — later runs merge into what's
already saved:

```bash
liftoff configure --set source.api_endpoint=https://tfe.example.com --set source.workspace_concurrency=4
```

If a required setting is still missing, configure saves your progress and
errors with exactly what's left — the specimen in
[when something goes wrong](start.md#when-something-goes-wrong) is this very
case. With the token set:

```text
Source  terraform

Set Keys (1)
  - api_token

Next
  $ liftoff configure validate
```

Values are never echoed back, only key names.

## Step 4 — validate before running anything

```bash
liftoff configure validate
```

The verdict on your configuration: what every key resolves to right now and
what the run will mean, and — once the config is complete — it authenticates
the token against the source and reports the account it resolves to. Read-only
(it never writes), so run it as often as you like.

```text
Source  terraform

Auth
  User  apollorion
  Role  user

Config Keys (used in `liftoff discover`) (4)
  ┌───────────────────────┬─────┬──────────┬────────┬─────────────────────────────────────────────────────────┐
  │ Key                   │ Set │ Required │ Secret │ Effect                                                  │
  ├───────────────────────┼─────┼──────────┼────────┼─────────────────────────────────────────────────────────┤
  │ api_endpoint          │ –   │ –        │ –      │ connects to https://app.terraform.io                    │
  │ api_token             │ ✓   │ ✓        │ ✓      │ uses the configured value                               │
  │ requests_per_second   │ –   │ –        │ –      │ the Terraform API is called at up to 30 requests/second │
  │ workspace_concurrency │ –   │ –        │ –      │ up to 8 workspaces are enriched concurrently            │
  └───────────────────────┴─────┴──────────┴────────┴─────────────────────────────────────────────────────────┘

Repair Keys (used in `liftoff audit --repair`) (2)
  ┌──────────────────────┬─────┬──────────┬────────┬───────────────────────────────────────────────────────────────┐
  │ Key                  │ Set │ Required │ Secret │ Effect                                                        │
  ├──────────────────────┼─────┼──────────┼────────┼───────────────────────────────────────────────────────────────┤
  │ module_workflow_tool │ –   │ –        │ –      │ empty module workflow tools stay unrepaired until this is set │
  │ default_branch       │ –   │ –        │ –      │ missing branches will default to: main                        │
  └──────────────────────┴─────┴──────────┴────────┴───────────────────────────────────────────────────────────────┘

Mutations (1)
  ┌─────────┬────────────────────────────────────────────────────────────────┬─────────────────────────────────────────┐
  │ Name    │ Effect                                                         │ Enable With                             │
  ├─────────┼────────────────────────────────────────────────────────────────┼─────────────────────────────────────────┤
  │ secrets │ sensitive variable values come over empty; stage the           │ liftoff mutate --allow-mutation secrets │
  │         │ workspaces and run `liftoff mutate --allow-mutation secrets`   │                                         │
  │         │ to capture them, or set them in Spacelift after the migration  │                                         │
  └─────────┴────────────────────────────────────────────────────────────────┴─────────────────────────────────────────┘

Next
  $ liftoff discover
```

Where `liftoff sources` showed templates, this shows results: every `Effect`
is rendered with the value the run will actually use. Two more sections
appear only when something needs attention: `Missing Required` (required keys
with no value) and `Unknown Keys` (settings in `config.yaml` the source
doesn't recognize — usually a typo'd `--set`).

Read the `Effect` column top to bottom and check it against your intent.
Worth deciding now:

- **Rate and concurrency** (`requests_per_second`, `workspace_concurrency`) —
  the defaults are safe for Terraform Cloud; a self-hosted TFE may want them
  lowered.
- **The repair keys** (`module_workflow_tool`, `default_branch`) — what
  `liftoff audit --repair` writes in step 6. They change nothing until an
  audit has findings to fix, and you can re-run configure to adjust them
  whenever.
- **The mutations** — opt-ins for the later `mutate` step, `secrets` here
  being one example. A mutation is never remembered: you pass
  `--allow-mutation <name>` on every `mutate` that should use it, which is why
  they aren't config keys. Decide whether sensitive variable values should be
  captured (the [mutate](mutate.md) step shows the flag) or re-entered in
  Spacelift after the migration.

When the effects read the way you intend and the token authenticated, you are
ready for [discover](discover.md).
