# Generate

Step 8 of [the migration walkthrough](README.md): render the audited batch as the OpenTofu module your admin stack applies.

## Step 8 — generate the module

```bash
liftoff generate
```

Renders the batch as a tree of OpenTofu modules — one directory per space — that your Spacelift admin stack applies.
It renders **`staged ∪ migrated`**: your staged batch plus everything already migrated, so the module is additive and each new batch keeps the prior ones (files for already-migrated entities are kept untouched — they're yours now).
Local and instant; run it as often as you like, and the output is deterministic: same store, same flags, byte-identical files.

Generate is gated on the audit.
It re-runs the same rules `liftoff audit` does over the **staged** set (findings are never stored — always recomputed, never stale), and while **error**-level findings remain it refuses, because the output would be invalid or rejected by Spacelift at apply time.
With the demo batch staged `--all` and repaired, three stacks still have no repository:

```text
✗ Audit Errors  generate: 3 error-level audit finding(s) would make the output invalid or rejected at apply time

Remediation
  fix the findings (`liftoff audit` charts the repair path), unstage the offending units (`liftoff batch unstage <kind>:<id>`), or accept each explicitly with --ignore-finding <rule[:entity]> to render it annotated

Findings (3)
  ┌──────────────────────────────┬─────────────┬─────────────────────┬─────────────────────────────────────────────────┐
  │ Rule                         │ Entity Kind │ Entity Id           │ Message                                         │
  ├──────────────────────────────┼─────────────┼─────────────────────┼─────────────────────────────────────────────────┤
  │ stack-missing-vcs-repository │ stack       │ ws-axzQMYTKvuxA9VDQ │ stack "this-is-a-test-workspace" has no VCS     │
  │                              │             │                     │ repository or branch                            │
  │ stack-missing-vcs-repository │ stack       │ ws-jo93LkzmNb6bK6Ga │ stack "test" has no VCS repository or branch    │
  │ stack-missing-vcs-repository │ stack       │ ws-oxRaEDV2f5uMHy5f │ stack "my-amazing-workspace-local-no-vcs" has   │
  │                              │             │                     │ no VCS repository or branch                     │
  └──────────────────────────────┴─────────────┴─────────────────────┴─────────────────────────────────────────────────┘

Next
  $ liftoff audit
```

Warnings never block.
For each error you have four ways forward: repair it ([audit](audit.md) — including per-entity `--set` for gaps like a missing repository), fix it at the source and re-discover, **unstage** the offending unit to leave it out of the batch, or accept it annotated with `--ignore-finding`.
A finding is named by its rule id, optionally narrowed to one entity:

```bash
--ignore-finding stack-missing-vcs-repository                     # every entity with the finding
--ignore-finding stack-missing-vcs-repository:ws-oxRaEDV2f5uMHy5f # just this one
--ignore-finding stack-missing-vcs-repository,raw-git-missing-url # several rules at once
```

`--ignore-finding` accepts a comma-separated list or repeated flags — same shape as `--allow-mutation`.

### `--ignore-finding` — generate it anyway, annotated

The affected entities are included on the understanding that the code needs hand-editing before it works.
Every affected resource gets an annotation so the problem is visible exactly where it lives, and any required argument the source couldn't supply renders as an obvious `"REPLACE_ME"` placeholder — so the module still validates and the edit sites are unmistakable, rather than failing on a missing argument before it ever reaches Spacelift:

```bash
liftoff generate --ignore-finding stack-missing-vcs-repository,raw-git-missing-url
```

```text
Out Dir      /tmp/migration-demo/.liftoff/data/generated
Annotations  4

Ignored (1)
  stack-missing-vcs-repository (error) (3)
    Description  A stack without a VCS repository cannot be created in Spacelift
    Repairable   no
    Remediation  change one with `liftoff model set stack:<id> vcs.repository=…` (vcs.namespace, vcs.branch,
                 vcs.provider the same way); attach the stack to a repository at the source and re-discover, or
                 unstage this stack to leave it out of the batch

    Entities (3)
      this-is-a-test-workspace (id: ws-axzQMYTKvuxA9VDQ)
        Kind  stack
        URL   https://app.terraform.io/app/Apollorion/workspaces/this-is-a-test-workspace

      test (id: ws-jo93LkzmNb6bK6Ga)
        Kind  stack
        URL   https://app.terraform.io/app/Apollorion/workspaces/test

      my-amazing-workspace-local-no-vcs (id: ws-oxRaEDV2f5uMHy5f)
        Kind  stack
        URL   https://app.terraform.io/app/Apollorion/workspaces/my-amazing-workspace-local-no-vcs
```

And in the module, right where the hand-edit belongs:

```hcl
# Generated by liftoff. Source: ws-oxRaEDV2f5uMHy5f.
# ERROR: stack-missing-vcs-repository — stack "my-amazing-workspace-local-no-vcs" has no VCS repository or branch
resource "spacelift_stack" "my-amazing-workspace-local-no-vcs" {
  name                    = "my-amazing-workspace-local-no-vcs"
  space_id                = local.space_id
  repository              = "REPLACE_ME"
  branch                  = "REPLACE_ME"
  autodeploy              = false
  terraform_version       = "1.5.7"
  terraform_workflow_tool = "TERRAFORM_FOSS"
}
```

`--ignore-finding` is the escape hatch for **errors**.
To leave an entity out of the module entirely, don't accept it here — `unstage` it ([batch](batch.md)).
Staging is the single exclusion axis, so there's no `--skip-finding`.
Naming a finding that doesn't exist or a warning-level finding is a structured error — a mistaken flag never silently no-ops.

**Warning findings never need `--ignore-finding`** — they generate working code and get the same in-place treatment (`# WARNING: ...`) automatically, e.g. a sensitive variable whose value wasn't captured.
The generated module doubles as the migration's review document; those comments stay greppable even after you acknowledge the finding in the audit listing.

### `--acknowledge-finding` — quiet a reviewed warning in the listing

Account-global warnings (teams, policies, run tasks, …) re-surface on every audit and generate listing for the rest of the migration.
Once you've handled them, acknowledge so they stop being listing noise — the acknowledgement is persisted in the store and applies on later runs without repeating the flag:

```bash
liftoff audit --acknowledge-finding stack-secret-missing-value
# or at generate time:
liftoff generate --acknowledge-finding stack-secret-missing-value
```

Acknowledged findings leave the active audit list but still appear under `acknowledged`, and they still render as `# WARNING:` / `# INFO:` comments in the generated module.
Only `warning` and `info` can be acknowledged; errors still need `--ignore-finding`.
A rule-wide selector expands to the entities that currently match — a newly discovered entity of the same rule still surfaces until you acknowledge it too.

### Every annotation is greppable

Annotations aren't just for reading top-to-bottom — every ignored error, every warning, and every uncaptured sensitive value is left in the tree as a comment, so the whole outstanding list is one `grep` away.
It's the fastest way to enumerate what still needs a human before this batch is done:

```bash
grep -rn '# \(ERROR\|WARNING\|sensitive\): ' .liftoff/data/generated
```

Each hit names the rule (or the sensitive value) and points at the exact file and line.
The `"REPLACE_ME"` placeholders an ignored error leaves behind are the companion grep — the edit sites that must be filled before the code will work:

```bash
grep -rn 'REPLACE_ME' .liftoff/data/generated
```

When both come back empty, nothing in the tree is waiting on you.

### Additive across batches; migrated files are yours

Generate renders `staged ∪ migrated`, so re-running after you stage the next batch **adds** its files — the module always describes everything migrated so far, and a new batch's apply never destroys a prior one.
And once an entity is `migrated` ([finalize](finalize.md)), its file is the customer's: generate **never overwrites it** (only regenerates it if it's missing).
The database, not git, is the authority on what's migrated.

"Migrated files are yours" covers **entity files** — the one-file-per-stack/module/context/space output — and not the **wiring** that connects them.
`liftoff.tf` and `space.tf` carry no entity state; they're deterministic, additive wiring, and generate **always rewrites them**, migrated or not.
A migrated space's `liftoff.tf` is regenerated on the next `generate` the same as a staged one, because staging a later batch legitimately grows it — a new batch's contexts, for instance, extend the root `liftoff.tf`'s `inherited_contexts` map, and that root file belongs to no single batch.
So hand-edit an entity file freely once it's migrated, but never hand-edit the wiring: those edits are lost with no warning, whatever the entity's status.

**So hand-editing the generated files is fine, and it's supported.**
Fill a `REPLACE_ME`, fix a repository, adjust a resource — the module is yours to edit.
An edit to a file whose entity is already `migrated` is permanent: generate never touches that file again, so you don't have to re-check it after every regenerate.
An edit to a file that's still only `staged` is the thing to be careful with — the next `generate` re-renders it from the store and your change is gone, so push those upstream instead (re-discover, `audit --repair`, or `space mv`) and let generate carry them.
In short: finalize a unit, then hand-edit it freely; while it's staged, change the store, not the file.

**What protects an edit is the entity's migration status, not the edit.**
liftoff does not detect edits.
It has no checksum, hash, or modification-time check anywhere in it, so it cannot tell a file you changed from one nobody has touched.
It decides from two things: whether the entity is `migrated`, and whether the file is on disk.

| you hand-edit… | what the next `generate` does |
|---|---|
| a file for a **migrated** entity | leaves it alone |
| a file for a **staged** entity | overwrites it, with no warning |
| a **wiring** file (`liftoff.tf`, `space.tf`) | overwrites it, with no warning — always, migrated or not |
| a file you added yourself (no `# Generated by liftoff` header) | leaves it alone, whatever the model says |

So ordering is what actually saves an edit: finalize the unit before anything regenerates.
An edit to a staged file lasts until the next `generate` and no longer.
Deleting a migrated file is not an escape hatch either, because generate treats a missing file as one to write again.

Substituting a `REPLACE_ME` is the edit that behaves most predictably, because the shape of the module doesn't change: a value was missing and you supplied it.
Structural edits are the ones to keep track of.
Renaming a file, moving an entity to another space, or reshaping a resource can all drift from what a later generation produces, so liftoff can't promise a regenerate reproduces them.
Make them anyway if you need them, and keep the table above in mind: on a staged entity they go away on the next `generate` and you re-apply them, and on a migrated one they stay.

## The module

The output is a **tree of modules — one directory per space**, mirroring your Spacelift space hierarchy:

```text
<root>/
  versions.tf      provider requirements — one per module (not inherited)
  providers.tf     the spacelift provider (SPACELIFT_API_KEY_*) — root only, inherited
  liftoff.tf       wiring: this module's inputs, its space_id local, and child-space module calls
  <kind>_<slug>.tf one file per stack, module, context, or provider in the root space
  <space>/         a space — its own nested module directory
    versions.tf
    space.tf       the spacelift_space resource for this space
    liftoff.tf
    <kind>_<slug>.tf
    <child-space>/ nested, arbitrarily deep
```

There's no `backend.tf` — state belongs to the Spacelift runner.
`providers.tf` sits at the root and is inherited by every child module; `versions.tf` repeats in each module because provider *requirements* aren't inherited across a module boundary.

Each space is its own module directory.
Its `space.tf` holds the space resource, parented through a module input rather than a hard-coded reference, so the parent module owns the link:

```hcl
# apollorion/space.tf — Generated by liftoff. Source: Apollorion.
resource "spacelift_space" "this" {
  name             = "Apollorion"
  parent_space_id  = var.parent_space_id
  inherit_entities = true
}
```

`liftoff.tf` is the wiring: it declares the module inputs (`parent_space_id`, `ancestor_space_ids`, `inherited_contexts`), sets `local.space_id` to this space (`spacelift_space.this.id`, or `"root"` at the top), and calls each child space as a module, passing scope down the tree:

```hcl
# apollorion/liftoff.tf — variable blocks elided
locals {
  space_id = spacelift_space.this.id
}

module "apollorion-project" {
  source             = "./apollorion-project"
  parent_space_id    = local.space_id
  ancestor_space_ids = concat(var.ancestor_space_ids, [local.space_id])
  inherited_contexts = var.inherited_contexts
}
```

Each stack (and module) gets its own `<kind>_<slug>.tf` in its space's directory: the resource, its variables, and its context attachments.
Placement is a single `local.space_id` — the space is the directory the file lives in, so re-spacing a stack is a matter of moving its file (which `liftoff space mv` does, emitting a `moved` block so Spacelift re-parents it in place):

```hcl
# apollorion-project/stack_demo.tf — Generated by liftoff. Source: ws-UcrBnzxbcMzmERxL.
resource "spacelift_stack" "demo" {
  name                    = "demo"
  space_id                = local.space_id
  repository              = "demo"
  branch                  = "main"
  autodeploy              = false
  terraform_workflow_tool = "CUSTOM"
  runner_image            = "public.ecr.aws/mycorp/runner-terraform:1.14.3"
  worker_pool_id          = "01G1KTZ4BA86RBN3XNN3YK9EWT"
  before_init             = ["tofu fmt -check"]
}

resource "spacelift_environment_variable" "tf_var_region" {
  stack_id   = spacelift_stack.demo.id
  name       = "TF_VAR_region"
  value      = "us-east-1"
  write_only = false
}

resource "spacelift_context_attachment" "org-a-terraform-workflow-tool_demo" {
  context_id = var.inherited_contexts["org-a-terraform-workflow-tool"]
  stack_id   = spacelift_stack.demo.id
  priority   = 1
}
```

`demo` runs the **CUSTOM** workflow tool, which covers a tool Spacelift's runner doesn't provide — Terraform over 1.5.7 here, other tools in other sources.
Those stacks run on an image you supply: set `custom_runner_image` ([setup](setup.md)) and `audit --repair` writes it into `runner_image`, tagged with the stack's version.
Generate also attaches each one to a context carrying the workflow commands, so the stack is runnable as generated.
Until the image is set it is an error finding ([audit](audit.md)) — the stack would land unable to run.

`worker_pool_id` is optional the same way: omit it and the stack uses the public pool; set `worker_pool_id` ([setup](setup.md)) and `audit --repair` writes a recorded private pool id when the account has private pools ([audit](audit.md)).
On an account with no public pool the attribute stops being optional — a stack without it has nothing to run on, which audit flags as an error.

Notice there is no `terraform_version`.
Spacelift offers no version selector for CUSTOM — the image provides the tool — so pinning one would say nothing, and it isn't rendered.
`runner_image` is what decides the version that runs, which is why the repair tags it: left untagged, `custom_runner_image` picks up each stack's own version, as `1.14.3` did above.
Tag it yourself and that one image runs every CUSTOM stack, whatever version it happens to carry — do that only if you mean to standardize them all.

A registry module is the same shape — its own `module_<slug>.tf`, `space_id = local.space_id`, and its mounted files below the resource:

```hcl
# apollorion-project/module_vpc.tf — Generated by liftoff. Source: mod-vpc.
resource "spacelift_module" "vpc" {
  name               = "vpc"
  space_id           = local.space_id
  repository         = "terraform-aws-vpc"
  branch             = "main"
  public             = true
  description        = "Shared VPC module"
  labels             = ["team:network"]
  terraform_provider = "aws"
  workflow_tool      = "TERRAFORM_FOSS"

  gitlab {
    namespace = "my-org"
  }
}

# sensitive: module/signing.pem — set via liftoff finalize sensitive

resource "spacelift_mounted_file" "module-defaults-json" {
  module_id     = spacelift_module.vpc.id
  relative_path = "module/defaults.json"
  content       = "eyJjaWRyIjoiMTAuMC4wLjAvMTYifQ=="
  write_only    = false
}
```

A private-registry provider generates as `spacelift_terraform_provider` in its own `registry_provider_<slug>.tf`, `space_id = local.space_id`, `type` taken from the provider's name.
Only the **definition** is generated — the published version binaries are signed artifacts your source's API never hands out, so generate never renders a version.
The `registry-provider-versions-not-migrated` warning ([audit](audit.md)) fires for each staged provider and annotates the file in place, so the gap is visible right where it lives; publish the versions to Spacelift from the release pipeline that builds them:

```hcl
# apollorion-project/registry_provider_datadog.tf — Generated by liftoff. Source: prov-datadog.
# WARNING: registry-provider-versions-not-migrated — provider datadog migrates as a definition only — its published versions are not migrated
resource "spacelift_terraform_provider" "datadog" {
  type        = "datadog"
  space_id    = local.space_id
  public      = false
  description = "Our fork of the Datadog provider"
  labels      = ["fork"]
}
```

A context — a named collection of variables, mounted files, and hooks shared across stacks — is the same shape again: its own `context_<slug>.tf`, `space_id = local.space_id`, the `spacelift_context` with any hooks, then its variables and mounted files.
A context in the root space reads `local.space_id = "root"`:

```hcl
# context_org-a-shared.tf — Generated by liftoff. Source: ctx-1.
resource "spacelift_context" "org-a-shared" {
  name         = "org-a-Shared"
  space_id     = local.space_id
  description  = "Shared credentials"
  before_init  = ["export CA_BUNDLE=\"$(cat /mnt/workspace/liftoff/ctx-1/CA_BUNDLE)\""]
  before_apply = ["export CA_BUNDLE=\"$(cat /mnt/workspace/liftoff/ctx-1/CA_BUNDLE)\""]
}

# sensitive: SHARED_TOKEN — set via liftoff finalize sensitive

resource "spacelift_environment_variable" "endpoint" {
  context_id = spacelift_context.org-a-shared.id
  name       = "ENDPOINT"
  value      = "https://api.example.com"
  write_only = false
}
```

Each stack the context attaches to gets an explicit attachment in its **own** file.
How it references the context depends on where the context lives: a context in the stack's own space is a direct reference, while a context inherited from an ancestor space — the common case, since shared contexts live at the root — comes through the `inherited_contexts` map the module received.
`priority` carries the precedence it held at the source: a context whose source counterpart overrode stack-level variables attaches at `0`, any other at `1` — Spacelift resolves conflicting context variables lowest-priority-first, so the higher-precedence context still wins:

```hcl
# apollorion-project/stack_api.tf — api attaches a context inherited from root
resource "spacelift_context_attachment" "org-a-shared_api" {
  context_id = var.inherited_contexts["org-a-shared"]
  stack_id   = spacelift_stack.api.id
  priority   = 0
}
```

Sensitive values are never inlined — a sensitive variable or mounted file leaves only a `# sensitive: <name> — set via liftoff finalize sensitive` comment, and the captured value stays in the local store until `liftoff finalize sensitive` pushes it to Spacelift, where it lives write-only.

Everything that *does* render carries `write_only = false`, so it stays readable in Spacelift exactly as it was at the source.
That is deliberate rather than decorative: the provider defaults `write_only` to `true`, so a variable that omitted it would arrive marked secret and its value could never be read back — including the plainly non-secret ones.
The only values that end up write-only are the sensitive ones, which get there through `finalize sensitive`.

**This output is a code review, not a black box.**
Everything you decided upstream is visible in it: the repaired branches read `branch = "main"`, the module tool you configured is on the module, and every accepted risk is annotated in place — an ignored error sits as an `# ERROR:` comment directly above the resource that needs hand-editing.
Read the diff like a PR before applying it.

If anything upstream changes — a re-discover, another repair, a moved stack — regenerate and diff; the store is the source of truth and the module is always just a render of it.
When the code reads right, move on to [publish and finalize](publish.md).
