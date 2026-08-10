# Set up and configure

Steps 1–4 of [the migration walkthrough](start.md): scaffold the workspace, pick a source, set its credentials, and validate the configuration before anything runs.

## Before you start — what you need

liftoff moves an estate onto Spacelift, so it needs credentials for both ends and an account ready to receive the work.
Have these in place before step 1:

- **A Spacelift account, and an API key with root-space admin access.**
  The account is read from the very first step, and a repository and admin stack are created later, so a narrowly scoped key fails partway through.
- **An account on the system you are migrating from, with credentials that can read everything in scope.**
  Each source declares exactly which keys it needs; `liftoff sources` lists them and step 4 proves them.
- **A VCS integration in Spacelift that can reach the repositories your source uses.**
  Generated stacks name the integration they bind to, so one has to exist for every provider in the estate.
- **At least one worker** — a private worker pool with a worker attached, or the public pool.
  Applying the generated code is itself a Spacelift run, so an account with no worker cannot finish a migration.
- **Network access to both APIs** from wherever you run liftoff.
- **A decision about where the generated code will live**: the Spacelift-managed repository, which needs no setup, or [your own git provider](publish-byo-git.md).

liftoff checks the ones it can rather than leaving you to find out later.
`liftoff configure validate` proves both key pairs, and `liftoff audit` reports a repository it cannot bind to an integration, one whose integration is not connected to the account it lives under, an integration Spacelift cannot reach at all, or an account with nothing to run on — all before you generate anything.

## Before you start — install liftoff

**First, know which version you're meant to run.**
Most operators want the current stable release, installed just below.
But if you were pointed at a **release candidate** — anything ending `-rc`, or a specific pre-release version — **stop here and jump to [Release candidates](#release-candidates)**.
The stable `brew install` below and the RC cask both provide the same `liftoff` command, so running the stable one now would replace an RC you'd already installed, quietly and with no warning from Homebrew.
Confirm the target first; install second.

If stable is what you want, install it:

```bash
brew install spacelift-solutions/tap/liftoff
```

Without Homebrew:

```bash
curl -fsSL https://raw.githubusercontent.com/spacelift-solutions/liftoff/main/install.sh | sh
```

On Windows, download the zip from the [releases page](https://github.com/spacelift-solutions/liftoff/releases/latest) and put `liftoff.exe` on your PATH.

Either way you get one binary and nothing else — no runtime, no container, no services.
Check it answers **and prints the version you meant to install** before going further — if you were sent to a release candidate, this is where you catch having landed on stable instead:

```bash
liftoff --version
```

To upgrade later, `brew upgrade liftoff`, or re-run the install script.

### Release candidates

`brew install spacelift-solutions/tap/liftoff` is always the current stable release — a candidate can never arrive there by surprise.
Candidates are a separate cask you have to ask for by name:

```bash
brew install spacelift-solutions/tap/liftoff-rc
```

Both provide the same `liftoff` command, so Homebrew will not let you have both at once.
Switch back with:

```bash
brew uninstall liftoff-rc && brew install spacelift-solutions/tap/liftoff
```

### Installing a specific version

Homebrew carries the newest build of each line and nothing older, so an exact version comes from the install script:

```bash
curl -fsSL https://raw.githubusercontent.com/spacelift-solutions/liftoff/main/install.sh | VERSION=v1.3.0 sh
```

The setting goes on `sh`, not in front of `curl` — in front of `curl` it reaches the download and not the script that reads it.

Pinning is what you want in CI, where "whatever is newest" is not a build you can reproduce.
The tags are on the [releases page](https://github.com/spacelift-solutions/liftoff/releases).

`INSTALL_DIR` puts the binary somewhere other than `/usr/local/bin` — reach for it when that directory needs root:

```bash
curl -fsSL https://raw.githubusercontent.com/spacelift-solutions/liftoff/main/install.sh | INSTALL_DIR="$HOME/.local/bin" sh
```

## Step 1 — initialize the workspace

```bash
liftoff init
```

Creates `./.liftoff/` in the current directory with an empty `config.yaml` and the SQLite store.

```text
Config Created  yes
Config Dir      /tmp/migration-demo/.liftoff
Config Path     /tmp/migration-demo/.liftoff/config.yaml
Db Path         /tmp/migration-demo/.liftoff/liftoff.db

Next
  $ liftoff sources
  $ liftoff configure --source <id> --set source.<key>=value
```

Running `init` again on an existing workspace reports `Config Created  no` and changes nothing, so it is safe to repeat.
On a workspace created by an older binary it migrates the store schema forward.

The only decision here is where to stand.
`init` creates `./.liftoff` under the current directory, one directory per migration.
Later commands walk up from `$PWD` to find that folder, so you can run them from a subdirectory without re-passing the path.
`--config-dir` or `LIFTOFF_CONFIG_DIR` still override the walk when you need a workspace somewhere else.

One warning, and it grows over the migration: `./.liftoff/` becomes the most sensitive thing on this machine.
`config.yaml` holds your source API token after step 3 (unless you kept it in an env reference), and the store — `liftoff.db`, a **plain, unencrypted SQLite file** — holds everything discover pulls, variable values included, and later the captured secret values and full Terraform **state blobs** the finalize steps push.
Treat the directory accordingly.
If you are running inside a git repository, ignore the workspace now:

```bash
echo '.liftoff/' >> .gitignore
```

That `.gitignore` line is necessary but not the whole story — it keeps the workspace out of git, not off backups, syncs, or a shared machine, and it does nothing once the migration is done and the directory should simply be gone.
What the directory contains and how to dispose of it safely is covered at the end of the walkthrough, in [finalize](finalize.md#dispose-of-the-workspace-when-youre-done).

Next up, `liftoff sources` to see what you can migrate from.

## Step 2 — pick a source

```bash
liftoff sources
```

Lists every source this binary can migrate from, with the settings each one takes.
Read-only; run it as often as you like.

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

    Repair Keys (used in `liftoff audit --repair`) (4)
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
      │ Custom runner image  │ custom_runner_image  │ –        │         │ Untagged Docker      │ CUSTOM-workflow      │
      │                      │                      │          │         │ image carrying the   │ stacks stay          │
      │                      │                      │          │         │ Terraform binaries   │ unrunnable and       │
      │                      │                      │          │         │ for CUSTOM-workflow  │ `liftoff audit`      │
      │                      │                      │          │         │ stacks; the repair   │ flags each until     │
      │                      │                      │          │         │ tags it with each    │ this is set          │
      │                      │                      │          │         │ stack's version      │                      │
      │ Worker pool          │ worker_pool_id       │ –        │         │ Spacelift private    │ generated stacks run │
      │                      │                      │          │         │ worker pool id to    │ on the public pool   │
      │                      │                      │          │         │ assign to generated  │ when the account has │
      │                      │                      │          │         │ stacks; must match a │ one; `liftoff audit` │
      │                      │                      │          │         │ pool discover        │ flags each while     │
      │                      │                      │          │         │ recorded on the      │ private pools exist  │
      │                      │                      │          │         │ account              │                      │
      └──────────────────────┴──────────────────────┴──────────┴─────────┴──────────────────────┴──────────────────────┘

    Mutations (4)
      ┌─────────────────────┬────────────────────────────────────────────┬─────────────────────────────────────────────┐
      │ Name                │ Description                                │ When Unset                                  │
      ├─────────────────────┼────────────────────────────────────────────┼─────────────────────────────────────────────┤
      │ secrets             │ capture sensitive variable values via a    │ sensitive variable values come over empty;  │
      │                     │ temporary agent — mutates the source,      │ stage the workspaces and run `liftoff       │
      │                     │ always reverted                            │ mutate --allow-mutation secrets` to capture │
      │                     │                                            │ them, or set them in Spacelift after the    │
      │                     │                                            │ migration                                   │
      │ context-secrets     │ capture sensitive variable-set values via  │ sensitive variable-set values come over     │
      │                     │ a temporary agent — creates and deletes    │ empty; run `liftoff mutate --allow-mutation │
      │                     │ one throwaway workspace per organization,  │ context-secrets` to capture them, or set    │
      │                     │ briefly attaches each variable set to it,  │ them on the migrated contexts in Spacelift  │
      │                     │ always reverted                            │ afterwards                                  │
      │ state               │ capture each staged workspace's Terraform  │ no Terraform state is captured, so `liftoff │
      │                     │ state — reads the source, changes nothing  │ finalize state` has nothing to push and the │
      │                     │                                            │ migrated stacks start empty                 │
      │ module-git-versions │ resolve each published module version's    │ module versions keep no commit SHA, so      │
      │                     │ commit SHA from its VCS — reads the        │ `liftoff finalize modules` skips them and   │
      │                     │ repository, changes nothing                │ the private registry migrates without its   │
      │                     │                                            │ published versions                          │
      └─────────────────────┴────────────────────────────────────────────┴─────────────────────────────────────────────┘

Next
  $ liftoff configure --source <id> --set source.<key>=value
```

What to take from this screen:

- **The id in the title is what you pass to `configure --source`.**
  Here that is `terraform`, which covers both Terraform Cloud and self-hosted Terraform Enterprise.
- **Config Keys is your settings checklist.**
  Only the checked `Required` keys must be set (`api_token` here).
  Everything else has a `Default` you can live with, or a `When Unset` telling you what not setting it means.
  On Terraform Enterprise you will also need `api_endpoint` pointed at your install.
- **Repair Keys are not for discover.**
  They feed `liftoff audit --repair` in step 7 and only come into play when an audit has findings to fix.
  You can set them now with everything else, and change them later by re-running configure.
- **Mutations preview a later, opt-in step.**
  Discover never changes the source; the one step that does — `liftoff mutate` — is opt-in and per run, so you pass `--allow-mutation <name>` on every `mutate` that should use it, which is why mutations are not config keys.
  The two secret mutations are the ones worth planning for: without them, sensitive values come over empty and you re-enter them in Spacelift afterwards.
  `secrets` covers values set on a workspace.
  `context-secrets` covers values set on a variable set, and is separate because it makes a larger change — it creates a throwaway workspace to read them through, then deletes it.
  Both revert the source when done.
  Nothing to do now — the [mutate](mutate.md) step shows the flags.

The decision at this step is which source you are migrating from and, if it is self-hosted, what its API endpoint is.
Note the id and move on.

## Step 3 — configure the source

```bash
liftoff configure --source terraform --set source.api_token='${TFC_TOKEN}'
```

Records the source and its settings in `config.yaml`.
Values can reference environment variables: single-quote the reference so your shell doesn't expand it, and `config.yaml` stores the literal `${TFC_TOKEN}` — the value is resolved when a command runs, so the token itself never has to be written to disk.
A reference that doesn't resolve is an error, not an empty string.
Pasting the raw token works too; it just lives in `config.yaml` (and your shell history) instead.

`--set` repeats, and configure is incremental — later runs merge into what's already saved:

```bash
liftoff configure --set source.api_endpoint=https://tfe.example.com --set source.workspace_concurrency=4
```

If a required setting is still missing, configure saves your progress and errors with exactly what's left — the specimen in [when something goes wrong](start.md#when-something-goes-wrong) is this very case.
With the token set:

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

The verdict on your configuration: what every key resolves to right now and what the run will mean, and — once the config is complete — it authenticates both key pairs and names who each resolved to.
Read-only (it never writes), so run it as often as you like.
This is the moment to catch a Spacelift endpoint pointed at the wrong account.

```text
Source  terraform

Auth
  User  apollorion
  Role  user

Spacelift Auth
  Endpoint  https://apps-tfc-migration-apollorion.app.spacelift.io
  Account   apps-tfc-migration-apollorion
  User      migration-key
  Role      admin

Config Keys (used in `liftoff discover`) (4)
  ┌───────────────────────┬─────┬──────────┬────────┬─────────────────────────────────────────────────────────┐
  │ Key                   │ Set │ Required │ Secret │ Effect                                                  │
  ├───────────────────────┼─────┼──────────┼────────┼─────────────────────────────────────────────────────────┤
  │ api_endpoint          │ –   │ –        │ –      │ connects to https://app.terraform.io                    │
  │ api_token             │ ✓   │ ✓        │ ✓      │ uses the configured value                               │
  │ requests_per_second   │ –   │ –        │ –      │ the Terraform API is called at up to 30 requests/second │
  │ workspace_concurrency │ –   │ –        │ –      │ up to 8 workspaces are enriched concurrently            │
  └───────────────────────┴─────┴──────────┴────────┴─────────────────────────────────────────────────────────┘

Repair Keys (used in `liftoff audit --repair`) (4)
  ┌──────────────────────┬─────┬──────────┬────────┬───────────────────────────────────────────────────────────────┐
  │ Key                  │ Set │ Required │ Secret │ Effect                                                        │
  ├──────────────────────┼─────┼──────────┼────────┼───────────────────────────────────────────────────────────────┤
  │ module_workflow_tool │ –   │ –        │ –      │ empty module workflow tools stay unrepaired until this is set │
  │ default_branch       │ –   │ –        │ –      │ missing branches will default to: main                        │
  │ custom_runner_image  │ –   │ –        │ –      │ CUSTOM-workflow stacks stay unrunnable and `liftoff audit`    │
  │                      │     │          │        │ flags each until this is set                                  │
  │ worker_pool_id       │ –   │ –        │ –      │ generated stacks run on the public pool when the account has  │
  │                      │     │          │        │ one; `liftoff audit` flags each while private pools exist     │
  └──────────────────────┴─────┴──────────┴────────┴───────────────────────────────────────────────────────────────┘

Mutations (4)
  ┌─────────────────────┬──────────────────────────────────────────────┬───────────────────────────────────────────────┐
  │ Name                │ Effect                                       │ Enable With                                   │
  ├─────────────────────┼──────────────────────────────────────────────┼───────────────────────────────────────────────┤
  │ secrets             │ sensitive variable values come over empty;   │ liftoff mutate --allow-mutation secrets       │
  │                     │ stage the workspaces and run `liftoff mutate │                                               │
  │                     │ --allow-mutation secrets` to capture them,   │                                               │
  │                     │ or set them in Spacelift after the migration │                                               │
  │ context-secrets     │ sensitive variable-set values come over      │ liftoff mutate --allow-mutation context-      │
  │                     │ empty; run `liftoff mutate --allow-mutation  │ secrets                                       │
  │                     │ context-secrets` to capture them, or set     │                                               │
  │                     │ them on the migrated contexts in Spacelift   │                                               │
  │                     │ afterwards                                   │                                               │
  │ state               │ no Terraform state is captured, so `liftoff  │ liftoff mutate --allow-mutation state         │
  │                     │ finalize state` has nothing to push and the  │                                               │
  │                     │ migrated stacks start empty                  │                                               │
  │ module-git-versions │ module versions keep no commit SHA, so       │ liftoff mutate --allow-mutation module-git-   │
  │                     │ `liftoff finalize modules` skips them and    │ versions                                      │
  │                     │ the private registry migrates without its    │                                               │
  │                     │ published versions                           │                                               │
  └─────────────────────┴──────────────────────────────────────────────┴───────────────────────────────────────────────┘

Next
  $ liftoff discover
```

Where `liftoff sources` showed templates, this shows results: every `Effect` is rendered with the value the run will actually use.
Two more sections appear only when something needs attention: `Missing Required` (required keys with no value) and `Unknown Keys` (settings in `config.yaml` the source doesn't recognize — usually a typo'd `--set`).

Read the `Effect` column top to bottom and check it against your intent.
Worth deciding now:

- **Rate and concurrency** (`requests_per_second`, `workspace_concurrency`) — the defaults are safe for Terraform Cloud; a self-hosted TFE may want them lowered.
- **The repair keys** (`module_workflow_tool`, `default_branch`, `custom_runner_image`, `worker_pool_id`) — what `liftoff audit --repair` writes in step 6. They change nothing until an audit has findings to fix, and you can re-run configure to adjust them whenever.
  `custom_runner_image` matters if any workspace runs a Terraform version Spacelift's runner doesn't include: those stacks migrate onto the CUSTOM workflow tool and run the tool from that image, tagged with each stack's version ([generate](generate.md)).
  **The image has to carry the tool.**
  Spacelift downloads nothing for a CUSTOM stack — it runs the commands in the mounted `workflow.yml`, so a missing binary surfaces as `sh: terraform: not found` and the run stops in `INITIALIZING`.
  Spacelift's own `runner-terraform` image does not satisfy this; build on it and install the versions you need.
  **Give it no tag.**
  An untagged image is what lets the repair tag each stack with the version its workspace ran, so every stack keeps its own.
  If you tag it yourself — `…/runner-terraform:latest`, say — that exact image is written to every CUSTOM stack, so whatever tool version it carries is the one they all run.
  `liftoff audit` prints the reference it would write per stack, so you can check before repairing.
  `worker_pool_id` matters when your Spacelift account has private worker pools: generated stacks omit the attribute (and land on the public pool — an audit error instead when the account has none) unless you set this to a pool id discover recorded, then `audit --repair` writes it.
- **The mutations** — opt-ins for the later `mutate` step, `secrets` here being one example.
  A mutation is never remembered: you pass `--allow-mutation <name>` on every `mutate` that should use it, which is why they aren't config keys.
  Decide whether sensitive variable values should be captured (the [mutate](mutate.md) step shows the flag) or re-entered in Spacelift after the migration.

### Building the runner image for CUSTOM stacks

If any workspace runs a Terraform newer than Spacelift bundles, its stack migrates onto the CUSTOM workflow tool and runs the binary **your** image carries.
Spacelift downloads nothing for it — you hold the licence for those versions, so you build the image.

You need one tag per version in the batch.
`liftoff audit` names the version in each finding, so the audit output is the list:

```text
custom-workflow-missing-runner-image (error) (2)
  stack ws-abc123 runs version 1.9.0 on the CUSTOM workflow tool and has no runner image
  stack ws-def456 runs version 1.10.3 on the CUSTOM workflow tool and has no runner image
```

A Dockerfile that adds one version on top of Spacelift's runner image.
Build on that image rather than a bare Alpine or `hashicorp/terraform`: the worker calls `ps` to watch the container, and the image has to carry the `spacelift` user (UID 1983) that jobs run as.
The fetch stage keeps the build from depending on which archive tools the base image ships:

```dockerfile
ARG TERRAFORM_VERSION

FROM alpine:3 AS fetch
ARG TERRAFORM_VERSION
RUN apk add --no-cache curl unzip \
 && curl -sSLo /tmp/tf.zip \
      "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
 && unzip /tmp/tf.zip -d /out

FROM public.ecr.aws/spacelift/runner-terraform:latest
USER root
COPY --from=fetch /out/terraform /usr/local/bin/terraform
RUN chmod 0755 /usr/local/bin/terraform
USER spacelift
```

Build and push one tag per version, **tagging each with the version itself** — that is what the repair writes:

```bash
for v in 1.9.0 1.10.3; do
  docker build --build-arg "TERRAFORM_VERSION=$v" -t "$REGISTRY/liftoff-runner:$v" .
  docker push "$REGISTRY/liftoff-runner:$v"
done
```

Where you push matters.
On Spacelift's **public** worker pool the image must be public, and only these registries are accepted: `public.ecr.aws`, `dkr.ecr.<region>.amazonaws.com`, `docker.io`, `registry.hub.docker.com`, `ghcr.io`, `gcr.io`, `docker.pkg.dev`, `azurecr.io`, `quay.io`, `registry.gitlab.com`.
A **private** image requires a private worker pool: the public pool caches images across accounts, so it only ever pulls public ones.
`liftoff audit` checks this rather than leaving you to find out from a run that never starts: a stack heading for the public pool with an image from anywhere else is an error, `runner-image-not-pullable` ([audit](audit.md)).

Then point the setting at the **untagged** name and repair:

```bash
liftoff configure --set source.custom_runner_image=$REGISTRY/liftoff-runner
liftoff audit --repair
```

Each CUSTOM stack gets `$REGISTRY/liftoff-runner:<its own version>`.
Build for linux/amd64 — that is what Spacelift workers run.
A missing or non-executable binary shows up as `sh: terraform: not found`, with the run stopping in `INITIALIZING`.

When the effects read the way you intend and the token authenticated, you are ready for [discover](discover.md).
