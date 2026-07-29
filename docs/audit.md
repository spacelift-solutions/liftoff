# Audit

Step 7 of [the migration walkthrough](start.md): run the rules over the
**staged batch**, decide what each finding means, and let `--repair` fix what
it can.

## Step 7 — audit the staged set

```bash
liftoff audit
```

Runs every rule over the staged set — what you're about to migrate, not the
whole estate — and reports what needs attention before generation. Read-only and
recomputed on every run — findings are never persisted, so re-running is always
safe and always current. (The example below stages `--all`; a smaller batch
shows fewer findings.)

```text
Findings (6)
  context-secret-missing-value (warning) (3)
    Description  A sensitive context variable with no captured value migrates as an empty secret
    Repairable   no
    Remediation  set the values in Spacelift after the migration — variable-set secrets can't be captured

    Entities (3)
      ┌──────────┬──────────────────────┬─────────────────────────────────────────┐
      │ Kind     │ Id                   │ Name                                    │
      ├──────────┼──────────────────────┼─────────────────────────────────────────┤
      │ variable │ var-4yLu8icofbvNRyFN │ sensitive                               │
      │ variable │ var-VmTyoL2sYHuxpLWy │ TF_VAR_sensitive_from_test_variable_set │
      │ variable │ var-XtdrzLmJAUCbkzUR │ TF_VAR_sensitive_from_directly_attached │
      └──────────┴──────────────────────┴─────────────────────────────────────────┘

  missing-vcs-branch (error) (6)
    Description  A stack or module tracking its repo's default branch needs an explicit one in Spacelift
    Repairable   yes
    Remediation  writes the `default_branch` repair key, or `main` when unset
    Result       main

    Entities (6)
      ┌────────┬──────────────────────┐
      │ Kind   │ Id                   │
      ├────────┼──────────────────────┤
      │ module │ mod-AJu96tYoVyzKPEjw │
      │ stack  │ ws-RjHgP1J9E5vrpwSP  │
      │ …      │ …                    │
      └────────┴──────────────────────┘

  module-missing-workflow-tool (error) (1)
    Description  A module needs a workflow tool; the source carries none per module
    Repairable   yes
    Remediation  writes the `module_workflow_tool` repair key: `TERRAFORM_FOSS`, `OPEN_TOFU`, or `CUSTOM`
    Result       nothing — `module_workflow_tool` is unset or invalid

    Entities (1)
      ┌────────┬──────────────────────┐
      │ Kind   │ Id                   │
      ├────────┼──────────────────────┤
      │ module │ mod-AJu96tYoVyzKPEjw │
      └────────┴──────────────────────┘

  stack-missing-vcs-repository (error) (3)
    Description  A stack without a VCS repository cannot be created in Spacelift
    Repairable   no
    Remediation  attach the source workspace to a repository and re-discover, or unstage this stack to leave it out of
                 the batch

    Entities (3)
      ┌───────┬─────────────────────┬───────────────────────────────────┐
      │ Kind  │ Id                  │ Name                              │
      ├───────┼─────────────────────┼───────────────────────────────────┤
      │ stack │ ws-axzQMYTKvuxA9VDQ │ this-is-a-test-workspace          │
      │ stack │ ws-jo93LkzmNb6bK6Ga │ test                              │
      │ stack │ ws-oxRaEDV2f5uMHy5f │ my-amazing-workspace-local-no-vcs │
      └───────┴─────────────────────┴───────────────────────────────────┘

  stack-secret-missing-value (warning) (19)
    Description  A sensitive stack variable with no captured value migrates as an empty secret
    Repairable   no
    Remediation  stage the stack and run `liftoff mutate --allow-mutation secrets` to capture the values, or set them in
                 Spacelift after the migration

    Entities (19)
      ┌──────────┬──────────────────────┬────────────────────────────────────┐
      │ Kind     │ Id                   │ Name                               │
      ├──────────┼──────────────────────┼────────────────────────────────────┤
      │ variable │ var-8hywiqX7eahW5Tgp │ TF_VAR_test_variable_sensitive_three │
      │ …        │ …                    │ …                                  │
      └──────────┴──────────────────────┴────────────────────────────────────┘

  stack-variable-shadows-context (info) (1)
    Description  A stack variable also defined by an attached context resolves to the stack's value in Spacelift,
                 whatever the source resolved
    Repairable   no
    Remediation  confirm the stack's value is the one your source resolved; if the context's was, remove or align the
                 stack variable after migration

    Entities (1)
      ┌───────┬─────────────────────┬──────────────┐
      │ Kind  │ Id                  │ Name         │
      ├───────┼─────────────────────┼──────────────┤
      │ stack │ ws-7YopKPAktoDmhFXW │ with-var-set │
      └───────┴─────────────────────┴──────────────┘

Counts
  Error    10
  Warning  23

Next
  $ liftoff configure --set source.default_branch=…
  $ liftoff configure --set source.module_workflow_tool=…
  $ liftoff audit
  $ liftoff audit --repair
```

Findings group by rule. Each group reads top to bottom: what the finding
means, whether `--repair` can fix it, what the fix does, `Result` — the exact
value a repair would write right now, resolved against your config — and the
entities affected. Errors block a clean generation; warnings are things to
handle after the migration.

**The decisions at this step:**

- **Repairable findings** want a value from you. `Result` shows what you get
  if you repair now; to change it, set the repair key the `Next` commands
  name and re-run `liftoff audit` — `Result` updates before anything is
  written. Here, leaving `default_branch` unset writes `main`, and the module
  tool repairs nothing until `module_workflow_tool` is set.
- **Unrepairable errors** are fix-at-the-source problems: attach the
  workspace to a repository and re-discover, accept them explicitly at
  generate time with `--ignore-finding` (renders the stacks annotated for
  hand-editing), or `unstage` the offending units to leave them out of the
  batch ([generate](generate.md), [batch](batch.md)).
- **Warnings** (the empty secrets) carry over as-is; you set those values in
  Spacelift afterwards.
- **`team-not-migrated`** is informational (a warning for the Owners team and
  any team holding org-level `manage-*`, otherwise info). TFC teams don't map
  1:1 onto Spacelift's space-scoped, IdP-group-bound access, so the kit lists
  each team and its access instead of generating a grant it can't get right —
  you recreate access in Spacelift by mapping each team to an IdP group and
  attaching a role. It has no repair and re-surfaces every run (it's
  account-global, not part of the batch); accept it with `--ignore-finding
  team-not-migrated` once you've handled RBAC.

When the results read right, apply:

```bash
liftoff configure --set source.module_workflow_tool=OPEN_TOFU
liftoff audit --repair
```

`--repair` writes each rule's fix to the local store — never the source — and
returns receipts. Findings always show what *remains*:

```text
Findings (4)
  stack-missing-vcs-repository (error) (3)
    Description  A stack without a VCS repository cannot be created in Spacelift
    Repairable   no
    Remediation  attach the source workspace to a repository and re-discover, or unstage this stack to leave it out of
                 the batch

    Entities (3)
      ┌───────┬─────────────────────┬───────────────────────────────────┐
      │ Kind  │ Id                  │ Name                              │
      ├───────┼─────────────────────┼───────────────────────────────────┤
      │ stack │ ws-axzQMYTKvuxA9VDQ │ this-is-a-test-workspace          │
      │ stack │ ws-jo93LkzmNb6bK6Ga │ test                              │
      │ stack │ ws-oxRaEDV2f5uMHy5f │ my-amazing-workspace-local-no-vcs │
      └───────┴─────────────────────┴───────────────────────────────────┘

  … the three warning groups (context and stack secrets, the priority-context
  shadow) print above, unchanged — repair only touches repairable findings.

Counts
  Error    3
  Warning  23

Repaired (7)
  ┌──────────────────────────────┬─────────────┬──────────────────────┬───────────────┬───────────┐
  │ Rule                         │ Entity Kind │ Entity Id            │ Field         │ New       │
  ├──────────────────────────────┼─────────────┼──────────────────────┼───────────────┼───────────┤
  │ missing-vcs-branch           │ module      │ mod-AJu96tYoVyzKPEjw │ vcs.branch    │ main      │
  │ missing-vcs-branch           │ stack       │ ws-RjHgP1J9E5vrpwSP  │ vcs.branch    │ main      │
  │ …                            │ …           │ …                    │ …             │ …         │
  │ module-missing-workflow-tool │ module      │ mod-AJu96tYoVyzKPEjw │ workflow_tool │ OPEN_TOFU │
  └──────────────────────────────┴─────────────┴──────────────────────┴───────────────┴───────────┘

Next
  $ liftoff generate --ignore-finding stack-missing-vcs-repository
```

The three stacks with no repository can't migrate as-is: fix them at the source
and re-discover, `unstage` them to leave them out of this batch, or accept them
annotated with `--ignore-finding`. Everything else — the repaired branches and
module tool, the warnings — is ready to render.

Worth knowing:

- **Repair is idempotent and local.** Re-running `--repair` writes nothing
  new, and a re-discover overwrites repairs — just repair again after.
- **`--rule` scopes a run** to named rules (repeatable):
  `liftoff audit --repair --rule missing-vcs-branch`.
- **Remaining errors block generation.** `liftoff generate` re-runs these
  same rules over the staged set and refuses while error findings remain —
  each one must be fixed, accepted with `--ignore-finding` (rendered
  annotated), or removed by unstaging it. Warnings never block; they annotate
  the generated code.

When what remains is what you've accepted, the estate is ready to render —
name each accepted error on the generate command: [generate](generate.md).
