# Model

Read and write the local model — the normalized store every other command works from.

`liftoff model` is not a numbered step in [the migration walkthrough](README.md).
It is the surface you reach for when you need to see exactly what was captured, or correct something the source reported wrongly.
Everything it touches is local: nothing here calls the source or Spacelift.

## The two fixes, and which one you want

There are two ways to change a value, and they are not interchangeable.

- **`liftoff audit --repair` is the estate-wide fix.**
  It applies a config key across every affected entity, and it only ever **fills what is empty**.
  It is declarative: the key lives in your config, so it re-applies on every repair run and survives a re-discover.
- **`liftoff model set` is the single-entity fix.**
  It names the entities itself, and it is the **only thing that can change a value that is already there**.
  It is imperative: it writes those rows once.

Reach for the repair key when the same answer is right for everything it touches.
Reach for `model set` when specific entities are wrong, such as a repository that needs repointing or a namespace left stale by an account rename, or when a value is already populated, which `--repair` will never touch.

> **A later `liftoff discover` writes over anything `model set` wrote.**
> Discover re-reads the source and refreshes each entity, so a local correction is replaced by whatever the source still says.
> A correction that has to survive re-discovery belongs at the source, or in a repair key.

## What can be named

Every kind, and the id vocabulary shared with `batch`:

```text
Kinds (12)
  ┌────────────────────┬───────────┬────────────┐
  │ Kind               │ Stageable │ Selectable │
  ├────────────────────┼───────────┼────────────┤
  │ space              │ ✓         │ ✓          │
  │ stack              │ ✓         │ ✓          │
  │ module             │ ✓         │ ✓          │
  │ module_version     │ –         │ ✓          │
  │ context            │ ✓         │ ✓          │
  │ variable           │ –         │ ✓          │
  │ mounted_file       │ –         │ ✓          │
  │ context_attachment │ –         │ ✓          │
  │ registry_provider  │ ✓         │ ✓          │
  │ spacelift_vcs      │ –         │ –          │
  │ spacelift_pool     │ –         │ –          │
  │ spacelift_worker   │ –         │ –          │
  └────────────────────┴───────────┴────────────┘
```

**Stageable** kinds are the units a batch stages.
Everything else still migrates; a variable is migrated with the stack it belongs to, it just isn't staged on its own.
That is the line between `liftoff model list` and [`liftoff batch list`](batch.md): `batch list` deliberately leaves out variables and mounted files as too numerous, and `model list` reaches them.

**Selectable** kinds can be named as `<kind>:<id>`.
The last three describe your destination Spacelift account rather than the estate being migrated: they carry no source id, so nothing addresses one, and they are **read-only**.
They are facts discover recorded about your account, not part of the migration, so `set` and `unset` cannot name them at all.

## Reading

```bash
liftoff model list --kind stack
```

```text
Kind  stack

Entities (3)
  ┌───────────┬─────────────┬───────────────────┬────────┬────────────────┬────────────────────────────────────────────┐
  │ ID        │ Name        │ Owner             │ Status │ State Captured │ Unresolvable                               │
  ├───────────┼─────────────┼───────────────────┼────────┼────────────────┼────────────────────────────────────────────┤
  │ ws-api    │ api-service │ space:prj-alpha   │ staged │ –              │ the workspace has never been applied, so   │
  │           │             │                   │        │                │ the source holds no state to capture       │
  │ ws-legacy │ legacy      │ space:prj-beta    │ staged │ –              │ the workspace has never been applied, so   │
  │           │             │                   │        │                │ the source holds no state to capture       │
  │ ws-web    │ web         │ space:liftoff-e2e │ staged │ ✓              │                                            │
  └───────────┴─────────────┴───────────────────┴────────┴────────────────┴────────────────────────────────────────────┘
```

`--status` narrows to `unstaged`, `staged`, `skipped`, or `migrated`.
A leaf's status comes from its owner, so `--kind variable --status staged` lists the variables of staged stacks and contexts.

`State Captured` answers a question that otherwise only surfaces at [`finalize state`](finalize.md), by which point it is too late to act on: which staged stacks actually have a Terraform state captured.
`Unresolvable` carries the recorded reason a missing capture is not a gap — here, that the source holds no state for the stack — and stays empty for one whose capture is simply outstanding.
Every entity kind carries the same column with the same meaning; the module version listing uses it for the recorded reason a version's commit SHA can never be recovered.

One entity in full:

```bash
liftoff model get stack:ws-a4R2onDC3LMJ1oWu
```

```text
Kind  stack
ID    ws-a4R2onDC3LMJ1oWu

Entity
  Space ID    prj-platform
  Name        billing-api
  Slug        billing-api
  Autodeploy  yes

  Provenance
    Source ID         ws-a4R2onDC3LMJ1oWu
    Source JSON       {}
    Migration Status  staged

  Labels (1)
    - team:payments

  Hooks

  Terraform
    Version        1.8.5
    Workflow Tool  OPEN_TOFU

  VCS
    Branch                main
    Namespace             Apollorion
    Repository            billing-api
    Project Root          infra
    Provider              GITHUB
    Integration ID        github-default
    Integration Name      GitHub
    Integration Provider  GITHUB

State
  Captured           yes
  Serial             42
  Terraform Version  1.8.5
```

**A field's name for writing is its position in this output, lowercased with underscores and joined by dots.**
`Branch` under `VCS` is `vcs.branch`.
`Workflow Tool` under `Terraform` is `terraform.workflow_tool`.
`Source ID` under `Provenance` is `provenance.source_id`.
`--output json` prints those names verbatim if you would rather read them directly, and a misspelling lists every field the entity carries.

A captured sensitive value reads as `(redacted)`; an uncaptured one stays empty, so "hidden" never looks the same as "never captured".
`--allow-printing-secrets` prints it, and asks an agent for approval first, because a printed secret stays in a transcript for good.

Your destination account's own records are listable the same way, which is how you check what an integration can reach before an audit finding tells you it couldn't:

```bash
liftoff model list --kind spacelift_vcs
```

```text
Kind  spacelift_vcs

Entities (1)
  ┌────────────────┬────────┬──────────┬──────────────────────┬───────────┐
  │ ID             │ Name   │ Provider │ Serves               │ Unhealthy │
  ├────────────────┼────────┼──────────┼──────────────────────┼───────────┤
  │ github-default │ GitHub │ GITHUB   │ TheOutdoorProgrammer │ –         │
  └────────────────┴────────┴──────────┴──────────────────────┴───────────┘
```

## Writing

```bash
liftoff model set stack:ws-jo93LkzmNb6bK6Ga runner_image=ghcr.io/acme/tofu:1.8.4
```

```text
Entities (1)
  ws-jo93LkzmNb6bK6Ga
    Kind  stack

    Changes (1)
      ┌──────────────┬─────────────────────────┐
      │ Field        │ New                     │
      ├──────────────┼─────────────────────────┤
      │ runner_image │ ghcr.io/acme/tofu:1.8.4 │
      └──────────────┴─────────────────────────┘

Next
  $ liftoff audit --rule custom-workflow-missing-runner-image
  $ liftoff generate
```

The receipt reports the old value alongside the new one whenever it replaced something.
`Next` names the rules that actually judge the fields you wrote, so the check that would have flagged the value is the one you re-run.

Several fields land in one command, which is what a whole VCS attachment usually needs:

```bash
liftoff model set stack:ws-oxRaEDV2f5uMHy5f \
  vcs.repository=sandbox \
  vcs.namespace=TheOutdoorProgrammer \
  vcs.branch=main \
  vcs.provider=GITHUB
```

### Several entities at once

Name as many as you like, and mix kinds freely:

```bash
liftoff model set stack:ws-jo93LkzmNb6bK6Ga module:mod-7Kq1vTbN vcs.project_root=infra
```

```text
Entities (2)
  ws-jo93LkzmNb6bK6Ga
    Kind  stack

    Changes (1)
      ┌──────────────────┬───────┐
      │ Field            │ New   │
      ├──────────────────┼───────┤
      │ vcs.project_root │ infra │
      └──────────────────┴───────┘

  mod-7Kq1vTbN
    Kind  module

    Changes (1)
      ┌──────────────────┬───────┐
      │ Field            │ New   │
      ├──────────────────┼───────┤
      │ vcs.project_root │ infra │
      └──────────────────┴───────┘

Next
  $ liftoff audit
  $ liftoff generate
```

This is the shape most corrections actually take.
An account rename leaves the same wrong namespace on every stack and module that pointed at it, and repointing them one command at a time means one approval each.

**Every entity named must carry every field named.**
`value` exists on a variable and not on a stack, so naming both refuses the whole command rather than writing it where it happens to fit:

```text
✗ Unknown Field  stack:ws-oxRaEDV2f5uMHy5f — no field value on this entity
  entity: stack:ws-oxRaEDV2f5uMHy5f
```

Nothing is written when that happens, not even to the entities that would have accepted it.
The same is true of every other refusal below: the whole write is checked before any of it is stored.

### Changing a populated field asks first

Filling an empty field is what a repair already does, so it is not gated.
Changing or clearing one that already has a value is, and an agent is refused until a person approves it:

```text
✗ Consent Required  change stack ws-oxRaEDV2f5uMHy5f vcs.namespace from "TheOutdoorProgrammer" to "theoutdoorprogrammer" needs a person to approve it
  entity: model:overwrite

Remediation
  ask the user to run the command below in their own terminal; it refuses to run from an agent, and it prints what it is approving

Next
  $ liftoff approve model:overwrite
```

**One approval covers exactly one command, once.**
The prompt names every entity and both values, and the approval is bound to that exact wording, so:

- a second command, with different entities, fields, or values, needs its own approval;
- re-running the _same_ command after it succeeded needs a fresh approval, because an approval is spent when it is used;
- consent to set a field to one value can never be redeemed for a different one.

Naming several entities in one command is therefore also how you approve a batch of corrections once instead of a dozen times.

A sensitive value is redacted in the prompt as well as in the receipt: a gate that echoed the secret it was guarding would have leaked it already.

`--from` guards the write further, refusing unless the field holds the value you believed was there:

```bash
liftoff model set stack:ws-a4R2onDC3LMJ1oWu vcs.namespace=TheOutdoorProgrammer --from Apollorion
```

Use it whenever you are correcting something you read a moment ago; it turns a blind overwrite into one that fails loudly if the store moved underneath you.
With several entities named it must hold on all of them, and it guards a single field, so pass one `field=value` alongside it.

### Clearing a value so it can be re-derived

`--repair` only fills what is empty, so clearing a wrong value is how you hand a field back to the rules rather than working out the right answer yourself:

```bash
liftoff model unset stack:ws-jo93LkzmNb6bK6Ga runner_image
liftoff audit --repair --rule custom-workflow-missing-runner-image
```

### What refuses a write

Some fields are not yours to change, and say why:

```text
✗ Field Not Settable  space_id cannot be written
  entity: space_id

Remediation
  an entity's space decides which space module renders it, so changing it here would destroy and recreate the resource
```

The rule behind it: you can change what an entity **is**, never what **identifies** it or what it **hangs off**.
That covers `provenance.source_id` and `provenance.source_json` (identity and the raw capture), `provenance.migration_status` (staging owns it, so use [`liftoff batch`](batch.md)), `space_id` and `parent_space_id` (placement), and a leaf's owner links.
Those are moves rather than edits: they rewrite the rows pointing at the entity and re-render it into a different file.

Values are checked against the model, so a field with a fixed set of values needs no separate table to look up:

```text
✗ Invalid Value  vcs.provider cannot hold "SOURCEFORGE" — it is not one of GITHUB, GITHUB_ENTERPRISE, GITLAB, AZURE_DEVOPS, BITBUCKET_CLOUD, BITBUCKET_DATACENTER, RAW_GIT
  entity: vcs.provider

Remediation
  pass a value the field accepts
```

What is **not** checked here is whether a free-text value is the _right_ one.
`vcs.namespace=theoutdoorprogrammer` is a valid string, and `model set` writes it.
A namespace's spelling is only wrong relative to what your Spacelift integrations actually serve, and that cross-reference is [`liftoff audit`](audit.md)'s job, which is why `Next` points straight at the rule that makes it:

```bash
liftoff model set stack:ws-a4R2onDC3LMJ1oWu vcs.namespace=theoutdoorprogrammer
liftoff audit --rule vcs-namespace-unreachable
```

That rule names the namespace the entity now claims and lists the ones each integration serves, which catches the wrong case, the wrong account, and a typo alike.
Keeping the check in audit rather than in the write is deliberate: an integration that reports no namespaces at all, as Spacelift's built-in GitHub App does, cannot be checked, and a write that guessed would reject namespaces that are perfectly fine.

And a misspelled field lists what the entity does carry:

```text
✗ Unknown Field  no field vcs.repostiory on this entity
  entity: vcs.repostiory

Remediation
  name a field it carries: name, autodeploy, description, labels, hooks.before_init, hooks.after_init, hooks.before_plan, hooks.after_plan, hooks.before_apply, hooks.after_apply, hooks.before_perform, hooks.after_perform, hooks.before_destroy, hooks.after_destroy, hooks.after_run, terraform.version, terraform.workflow_tool, runner_image, worker_pool_id, vcs.branch, vcs.namespace, vcs.repository, vcs.project_root, vcs.provider, vcs.url, vcs.integration_id, vcs.integration_name, vcs.integration_provider
```

## Where to go next

After a write, re-run [`liftoff audit`](audit.md) to confirm the finding cleared, then [`liftoff generate`](generate.md).
