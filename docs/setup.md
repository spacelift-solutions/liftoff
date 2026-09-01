# Set up and configure

Steps 1–4 of [the migration walkthrough](README.md): scaffold the workspace, pick a source, set its credentials, and validate the configuration before anything runs.

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
`config.yaml` may hold source credentials after step 3 (unless you keep them in env references), and the store — `liftoff.db`, a **plain, unencrypted SQLite file** — holds everything discover pulls, variable values included, and later any sensitive values and stack state that capabilities capture.
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

<!-- liftoff:skill terraform -->
The capture below shows the Terraform source included in this release.

Use the source id `terraform` for both Terraform Cloud and self-hosted Terraform Enterprise.
A Terraform Enterprise migration also needs `source.api_endpoint` set to that installation's API endpoint.

The source's `secrets` capability covers workspace variables.
`context-secrets` covers variable-set variables and creates a temporary workspace to read them.
Both restore every source-side change before finishing.

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
<!-- liftoff:skill /terraform -->

What to take from this screen:

- **The id in the title is what you pass to `configure --source`.**
- **Config Keys is your settings checklist.**
  Only the checked `Required` keys must be set.
  Everything else has a `Default` you can live with, or a `When Unset` telling you what not setting it means.
- **Repair Keys are not for discover.**
  They feed `liftoff audit --repair` in step 7 and only come into play when an audit has findings to fix.
  You can set them now with everything else, and change them later by re-running configure.
- **Mutations preview a later, opt-in step.**
  Discover never changes the source; the one step that does — `liftoff mutate` — is opt-in and per run, so you pass `--allow-mutation <name>` on every `mutate` that should use it, which is why mutations are not config keys.
  Nothing to do now — the [mutate](mutate.md) step shows the flags.

The decision at this step is which source you are migrating from and which of its optional settings your environment needs.
Note the id and move on.

## Step 3 — configure the source

```bash
liftoff configure --source <id> --set source.<required-key>='${SOURCE_VALUE}'
```

Records the source and its settings in `config.yaml`.
Use the id and required keys reported by `liftoff sources`.
Values can reference environment variables: single-quote the reference so your shell doesn't expand it, and `config.yaml` stores the literal `${SOURCE_VALUE}` — the value is resolved when a command runs, so the secret itself never has to be written to disk.
A reference that doesn't resolve is an error, not an empty string.
Pasting a raw secret works too; it just lives in `config.yaml` (and your shell history) instead.

<!-- liftoff:skill terraform -->
Configure the Terraform source with an admin user token:

```bash
liftoff configure --source terraform --set source.api_token='${TFC_TOKEN}'
```

Set `source.api_endpoint` as well for Terraform Enterprise.
`source.workspace_concurrency` controls how many workspaces are processed at once, while `source.requests_per_second` caps API requests.
<!-- liftoff:skill /terraform -->

`--set` repeats, and configure is incremental — later runs merge into what's already saved.
A later `--set` of a key that is already in `config.yaml` replaces that value (it does not keep the first write):

```bash
liftoff configure --set source.<key>=value --set source.<another-key>=value
```

Settings for a deployment transform use one more level: the transform subcommand
owns the keys below it. For example:

```bash
liftoff configure --set transform.workflow-tool.target=OPEN_TOFU --set transform.workflow-tool.version=1.8.7
```

These settings do nothing during discovery. They are consumed only when you run
[`liftoff transform workflow-tool`](transform.md) for the current staged batch.

### When you need to write config.yaml by hand

`liftoff configure --set` is the normal path: it preserves the rest of the file, checks section names, and keeps secret values out of the report.
Writing `.liftoff/config.yaml` directly is the escape hatch for pre-seeding a workspace from automation, reviewing the whole configuration, or repairing malformed YAML.

The file has four core top-level entries:

- `exporter` is the source id from `liftoff sources`.
- `source` holds settings declared by that source.
- `spacelift` holds the destination account and API key.
- `vcs` holds repository credentials used by capabilities that read from git.

An optional `transform` entry holds settings for commands such as `liftoff transform workflow-tool`.

<!-- liftoff:skill terraform -->
Here is a complete Terraform source example:

```yaml
exporter: terraform
source:
  api_endpoint: https://app.terraform.io
  api_token: ${TFC_TOKEN}

spacelift:
  endpoint: https://example.app.spacelift.io
  api_key_id: ${SPACELIFT_KEY_ID}
  api_key_secret: ${SPACELIFT_KEY_SECRET}
  repo_name: liftoff
  admin_stack_name: liftoff-admin
  space: root

vcs:
  token: ${VCS_TOKEN}

transform:
  workflow-tool:
    target: OPEN_TOFU
    version: 1.8.7
```
<!-- liftoff:skill /terraform -->

Environment references stay exactly as written on disk.
The command that uses a value resolves it from the environment, so export each referenced variable before validating or running the migration.
After any hand edit, run `liftoff configure validate`.
It reports missing and unknown keys, validates transform settings, and authenticates against both configured systems when the required credentials are available.

If a required setting is still missing, configure saves your progress and errors with exactly what's left — the specimen in [when something goes wrong](README.md#when-something-goes-wrong) is this very case.
<!-- liftoff:skill terraform -->
With the Terraform source's token set, the current capture reads:

```text
Source  terraform

Set Keys (1)
  - api_token

Next
  $ liftoff configure validate
```
<!-- liftoff:skill /terraform -->

Values are never echoed back, only key names.

## Step 4 — validate before running anything

```bash
liftoff configure validate
```

The verdict on your configuration: what every key resolves to right now and what the run will mean, and — once the config is complete — it authenticates both key pairs and names who each resolved to.
Read-only (it never writes), so run it as often as you like.
This is the moment to catch a Spacelift endpoint pointed at the wrong account.

<!-- liftoff:skill terraform -->
The capture below validates the Terraform source shown in step 2.

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
<!-- liftoff:skill /terraform -->

Where `liftoff sources` showed templates, this shows results: every `Effect` is rendered with the value the run will actually use.
Two more sections appear only when something needs attention: `Missing Required` (required keys with no value) and `Unknown Keys` (settings in `config.yaml` the source doesn't recognize — usually a typo'd `--set`).

Read the `Effect` column top to bottom and check it against your intent.
Worth deciding now:

- **Rate and concurrency** — use the source's reported keys to keep discovery within its API limits.
- **Repair keys** — they change nothing until `liftoff audit --repair` has a matching finding, and you can re-run configure to adjust them whenever.
- **The mutations** — opt-ins for the later `mutate` step.
  A mutation is never remembered: you pass `--allow-mutation <name>` on every `mutate` that should use it, which is why they aren't config keys.
  Decide which capabilities the configured source should run; the [mutate](mutate.md) step shows the flag.

<!-- liftoff:skill terraform -->
The default request rate and workspace concurrency are safe for Terraform Cloud; lower them when a Terraform Enterprise installation needs a gentler load.

The repair keys are `module_workflow_tool`, `default_branch`, `custom_runner_image`, `worker_pool_id`, and `repository_map`.
They change nothing during discovery.
`liftoff audit --repair` reads them only when the matching finding is present.

`custom_runner_image` applies to workspaces whose Terraform version requires the CUSTOM workflow tool.
Give it an untagged image name; repair adds each stack's Terraform version as the tag.
The image must contain that Terraform binary.
A private image requires a private worker pool.
<!-- liftoff:skill /terraform -->

<!-- liftoff:skill terraform -->
### Terraform Cloud / Enterprise: building the runner image for CUSTOM stacks

If a Terraform workspace runs a version newer than Spacelift bundles, its stack migrates onto the CUSTOM workflow tool and runs the binary **your** image carries.
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
<!-- liftoff:skill /terraform -->

When the effects read the way you intend and the source credentials authenticated, you are ready for [discover](discover.md).
