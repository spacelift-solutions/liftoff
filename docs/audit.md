# Audit

Step 7 of [the migration walkthrough](README.md): run the rules over the **staged batch**, decide what each finding means, and let `--repair` fix what it can.

## Step 7 — audit the staged set

```bash
liftoff audit
```

Runs every rule over the staged set — what you're about to migrate, not the whole estate — and reports what needs attention before generation.
Findings are recomputed on every run and never persisted, so the report is always current.
A plain audit is read-only; `--repair` changes the local model, and finding acceptance flags change the local acceptance ledger.
(The example below stages `--all`; a smaller batch shows fewer findings.)

```text
Findings (6)
  context-secret-missing-value (warning) (3)
    Description  A sensitive context variable with no captured value migrates as an empty secret
    Repairable   no
    Remediation  stage the context and run `liftoff mutate` with a capability that captures context values (`liftoff
                 sources` lists them), or set it in Spacelift after the migration

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
    Remediation  set `liftoff configure --set source.default_branch=…` and run `liftoff audit --repair` to fill
                 every affected stack, or change one with `liftoff model set stack:<id> vcs.branch=…`
    Result       main

    Entities (6)
      mod-AJu96tYoVyzKPEjw
        Kind  module
        URL   https://app.terraform.io/app/Apollorion/registry/modules/private/Apollorion/module/mimetype

      ws-RjHgP1J9E5vrpwSP
        Kind  stack
        URL   https://app.terraform.io/app/Apollorion/workspaces/terraform-1-8-5-test

      …

  module-missing-workflow-tool (error) (1)
    Description  A module needs a workflow tool; the source carries none per module
    Repairable   yes
    Remediation  set `liftoff configure --set source.module_workflow_tool=…` and run `liftoff audit --repair` to
                 fill every affected module, or change one with `liftoff model set module:<id> workflow_tool=…`
    Result       nothing — `module_workflow_tool` is unset or invalid

    Entities (1)
      mod-AJu96tYoVyzKPEjw
        Kind  module
        URL   https://app.terraform.io/app/Apollorion/registry/modules/private/Apollorion/module/mimetype

  stack-missing-vcs-repository (error) (3)
    Description  A stack without a VCS repository cannot be created in Spacelift
    Repairable   yes
    Repair keys  repository_map
    Remediation  set `liftoff configure --set source.repository_map=…` and run `liftoff audit --repair` to fill every
                 affected stack, or change one with `liftoff model set stack:<id> vcs.repository=…` (vcs.namespace,
                 vcs.branch, vcs.provider the same way); attach the stack to a repository at the source and
                 re-discover, or unstage this stack to leave it out of the batch

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

  stack-secret-missing-value (warning) (19)
    Description  A sensitive stack variable with no captured value migrates as an empty secret
    Repairable   no
    Remediation  stage the stack and run `liftoff mutate` with a capability that captures stack values (`liftoff
                 sources` lists them), or set them in Spacelift after the migration

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
      ┌──────────┬────────────────────────────────────────┬────────────────┐
      │ Kind     │ Id                                     │ Name           │
      ├──────────┼────────────────────────────────────────┼────────────────┤
      │ variable │ var-…/varset-…                         │ TF_VAR_region  │
      └──────────┴────────────────────────────────────────┴────────────────┘

Counts
  Error    10
  Warning  23

Next
  $ liftoff configure --set source.repository_map=…
  $ liftoff configure --set source.default_branch=…
  $ liftoff configure --set source.module_workflow_tool=…
  $ liftoff audit
  $ liftoff audit --repair
  $ liftoff model set stack:ws-axzQMYTKvuxA9VDQ vcs.repository=…
  $ liftoff model set stack:ws-jo93LkzmNb6bK6Ga vcs.repository=…
  $ liftoff model set stack:ws-oxRaEDV2f5uMHy5f vcs.repository=…
```

Findings group by rule.
Each group reads top to bottom: what the finding means, whether `--repair` can fix it, what the fix does, `Result` (the exact value a repair would write right now, resolved against your config), and the entities affected.
When each entity would get a different value, `Result` moves onto the entity rows.
Errors block a clean generation; warnings are things to handle after the migration.

**The decisions at this step:**

- **Repairable findings** want a value from you.
  `Result` shows what you get if you repair now; to change it, set the repair key the `Next` commands name and re-run `liftoff audit` — `Result` updates before anything is written.
  Here, leaving `default_branch` unset writes `main`, and the module tool repairs nothing until `module_workflow_tool` is set.
  `custom-workflow-missing-runner-image` works the same way: stacks that migrate onto the CUSTOM workflow tool run the tool from their runner image, so they need `custom_runner_image` set — the repair tags it with each stack's version, unless you tagged the image yourself, in which case that one image runs every CUSTOM stack ([setup](setup.md), [generate](generate.md)).
  `Result` is the reference it would write, so you can see which you're getting before repairing.
  A stack whose version is a constraint (or anything else that cannot be an image tag) is **not** `repairable` while the key is an untagged image — `--repair` cannot invent a tag for it.
  Point the key at an image you have tagged yourself, or pin a plain version on the source and re-discover.
  `stacks-default-public-worker-pool` is a warning on the same pattern: when the account has private worker pools, stacks without a pool set will generate onto the public one — set `worker_pool_id` to a recorded private pool id and `--repair` writes it ([setup](setup.md), [generate](generate.md)).
  On an account with no public pool it is an error instead, since an unbound stack would have nothing to run on.
  `stack-missing-vcs-repository` repairs via `repository_map`. `config.yaml` stores a path (or a one-line `k=v` list) — not a nested map:

  ```yaml
  source:
    repository_map: "@repos.yaml"
  ```

  ```yaml
  # repos.yaml
  "space:Core Infra": acme/core-infra
  "dev-*":
    namespace: acme
    repository: dev-repo
    branch: main
    provider: GITHUB
  ws-special: acme/special-repo
  ```

  Then `liftoff configure --set source.repository_map=@repos.yaml` and `--repair` writes them.
  A string value is `namespace/repository`; the object form also fills branch and provider.
  Quote keys that contain a colon or a glob.
  JSON (`@repos.json`) is the same shape.
- **Per-entity fixes** use [`liftoff model set`](model.md), which names the entities itself.
  Reach for it when changing a value that is **already there**, which `--repair` never touches: a stale namespace after an account rename is corrected here, not by a repair key.
  Name several entities in one command when the same correction applies to all of them, and add `vcs.namespace` / `vcs.branch` / `vcs.provider` as companions when you know them.
  Invalid VCS providers, missing raw-git URLs, invalid module providers, unsupported stack versions, unreachable VCS namespaces, and unpullable runner images all declare the fields that correct them, so audit names the exact `model set` command.
  For `stack-version-unsupported-syntax`, exact versions and constraints both carry over — `1.5.7`, `1.5`, `>= 1.0.0`, `~> 1.5.0` are all fine — but `latest`, a version with a fourth segment, and anything that is neither are rejected.
  Set `terraform.version` locally, or pin one Spacelift accepts at the source and re-discover.
  Stacks on the CUSTOM workflow tool are exempt: Spacelift has no version selector for them, so no version is rendered and there is nothing to reject ([generate](generate.md)).
- **Manual repair exceptions** stay errors when the generated code cannot safely run but Liftoff cannot choose or perform the fix.
  Every such finding says what action to take instead.
  These exceptions cover source or account changes (`vcs-integration-unhealthy`, `no-worker-available`, and stale wrapped variable captures), batch decisions (duplicate ids and unstaged dependencies), and attachment placement.
  Fix the named problem, accept it with `--ignore-finding` when you intend to hand-edit the generated code, or unstage the affected unit ([generate](generate.md), [batch](batch.md)).
- **`vcs-integration-unbound`** is an error, and it is about your Spacelift account rather than the source.
  A generated stack names the integration it binds to, so that a repository reaches the connection you intend rather than whichever one the account happens to treat as default.
  This fires when nothing was bound: either the account has no integration that can serve the repository — create one and re-run discover — or it has several and none of them is the obvious answer.
  In the second case, set the source's VCS integration key to an integration id already recorded by discovery, then run `liftoff audit --repair`.
  The repair fills every compatible unbound stack and module from that integration's recorded name and provider, plus its id when the integration is not the built-in GitHub App.
  An id that discovery did not record writes nothing, as does one whose provider cannot serve the repository.
  The same setting also applies during the next discover.
  `liftoff configure validate` lists the key.
- **`no-worker-available`** is an error, and also about the account.
  Applying the generated code is itself a Spacelift run, so a migration cannot finish without a worker.
  Having worker pools is not enough — the check looks for a private pool with a worker attached that is not drained, or the public pool (assumed runnable without inspecting workers).
  Attach a worker and re-run discover.
- **`runner-image-not-pullable`** is an error, and it is the other half of the worker-pool question: not which pool a stack lands on, but whether that pool can obtain the image the stack needs.
  A stack landing on the public pool can only run a public image, from one of the registries Spacelift accepts there ([setup](setup.md) lists them): that pool caches images across accounts, so a private image is private-pool only.
  The finding names the registry host rather than the whole reference, because the host is the thing that has to change; a tag or a digest makes no difference to whether the image can be pulled.
  Point `runner_image` at a registry on that list, or take the stack off the public pool with `worker_pool_id`.
  Both go through [`liftoff model set`](model.md), since each value is already populated and `--repair` never overwrites one.
  On an account that has private pools, setting `worker_pool_id` as a repair key and re-running `liftoff audit --repair` moves every unassigned stack at once.
  A stack with no runner image at all belongs to `custom-workflow-missing-runner-image` instead, so the two never report the same stack.
- **`raw-git-missing-url`** is an error on stacks and modules tracking a raw git repository with no URL recorded.
  Raw git names its repository outright instead of going through an integration, so without the URL there is nothing to clone and the generated block renders `REPLACE_ME`.
  Set `vcs.url` with `liftoff model set`, correct it at the source and re-discover, or accept the finding to let the placeholder through for a hand edit.
- **`module-invalid-provider`** is an error, one per staged module whose provider Spacelift will not accept.
  A module is addressed by its registry address (`terraform-<provider>-<name>`), so the provider is part of its identity rather than a label on it, and only letters, digits and underscores are allowed there.
  A provider carrying anything else (a dash or a dot, say) is rejected when the admin stack applies, long after generate, which is why it is caught here instead.
  Rename it at the source and re-discover, or change one with `liftoff model set`.
  A module with no provider recorded is fine: the argument is omitted and Spacelift substitutes its own default.
- **`vcs-namespace-unreachable`** is an error, one per stack or module, and it is the check that catches a repository your integration cannot actually see.
  Being bound to an integration of the right kind only proves such an integration exists — not that it is connected to the account your code lives under.
  A GitHub App is installed on specific accounts, and an Azure DevOps connection can be limited to specific projects, so a stack under an account the integration was never installed on fails when the admin stack applies, long after generate.
  The finding names the namespace the stack lives under and lists the ones the integration does serve, which is usually enough to see that the repository was never the one you meant.
  Install the integration on that account (or grant the project) and re-run discover, or name a different integration with the source's VCS integration key.
  discover already prefers an integration that serves your namespace when the account has more than one candidate, so seeing this means none of them did.
  One limitation worth knowing: a repository on Spacelift's built-in GitHub App cannot be checked this way, because that integration does not report which accounts it is installed on.
  Nothing is claimed when an integration reports nothing — an unchecked namespace is never reported as a reachable one.

  <!-- liftoff:skill terraform -->
  For Azure DevOps, `vcs.namespace` is the **project**, not the organization.
  Terraform Cloud records a repository as `<organization>/<project>/_git/<repository>`, so `acme/Platform/_git/infra` becomes `vcs.namespace=Platform` and `vcs.repository=infra`.
  The organization comes from the Spacelift Azure DevOps integration; module tag resolution also uses the organization in [`vcs.host`](mutate.md#terraform-cloud--enterprise-resolving-module-versions-commit-shas).

  A local correction for that example is:

  ```bash
  liftoff model set stack:ws-abc \
    vcs.namespace=Platform \
    vcs.repository=infra \
    vcs.provider=AZURE_DEVOPS
  ```

  Do not set `vcs.namespace=acme`.
  When the finding lists what the integration serves, those values are Azure DevOps project names.
  <!-- liftoff:skill /terraform -->
- **`vcs-integration-unhealthy`** is an error, one per integration rather than per stack, because everything bound to it is affected and it is a single thing to fix.
  It fires when Spacelift could not reach the integration at all when discover last looked — the app was deleted, its credentials no longer work, or a VCS agent pool it routes through is unreachable.
  The finding names the status Spacelift reported, which is the clue to which repair is needed.
  Repair the integration in Spacelift and re-run discover.
  This is independent of the namespace check, so an integration that is both broken _and_ connected to the wrong account reports both — they need different fixes.
- **Warnings** (the empty secrets) carry over as-is; you set those values in Spacelift afterwards.
- **`team-not-migrated`** is informational (a warning for the Owners team and any team holding org-level `manage-*`, otherwise info).
  TFC teams don't map 1:1 onto Spacelift's space-scoped, IdP-group-bound access, so the kit lists each team and its access instead of generating a grant it can't get right — you recreate access in Spacelift by mapping each team to an IdP group and attaching a role.
  It has no repair and re-surfaces every run (it's account-global, not part of the batch); quiet it with `--acknowledge-finding team-not-migrated` once you've handled RBAC.
- **`agent-pool-not-migrated`** is informational.
  A TFC agent pool isn't migrated — the Spacelift equivalent is a worker pool, which you stand up separately (install workers, register the pool), then assign with the `worker_pool_id` repair key (`liftoff configure` / `liftoff audit --repair`) on the stacks that used the agent pool.
  Like the team finding it's account-global and re-surfaces every run; `--acknowledge-finding agent-pool-not-migrated` once you've provisioned worker pools.
- **`stacks-default-public-worker-pool`** is a warning when the account has private worker pools and a staged stack has none set.
  Generated code omits `worker_pool_id` in that case, so the stack lands on the public pool.
  Set `worker_pool_id` to a pool id discover recorded and `--repair` writes it; leave it unset if the public default is what you want.
  When the account has no public pool there is no default to fall back on — an unbound stack could never run — so the finding is an error there, and blocks generation until the pool is set (or the finding is explicitly accepted).
- **`policy-not-migrated`** and **`policy-set-not-migrated`** are informational.
  Each surfaces a TFC policy (naming its kind and enforcement level) or policy set (naming its scope and how many policies/workspaces it covers).
  Policy bodies are Sentinel or OPA, and Spacelift policies are Rego, so the kit lists them instead of generating rules it can't translate — you rewrite each in Rego as a `spacelift_policy` of the matching type and attach it with `spacelift_policy_attachment` (a global policy set becomes root-space attachments).
  Like the team finding they're account-global, have no repair, and re-surface every run; `--acknowledge-finding policy-not-migrated` (and `policy-set-not-migrated`) once you've recreated governance.
- **`run-task-not-migrated`** is informational.
  A TFC run task calls an external service around a run; Spacelift has no 1:1 equivalent, so you reconnect the callout as a separately provisioned integration (a Flow or webhook pointing at the same service) and wire it to the stacks that used the run task.
  The finding names each run task and how many workspaces used it.
  Like the team and agent-pool findings it's account-global, has no repair, and re-surfaces every run; `--acknowledge-finding run-task-not-migrated` once you've reconnected them.
- **`module-version-unmigratable`** is informational, one per published module version whose commit SHA could not be recovered.
  The module still migrates, but `liftoff finalize modules` skips that version.
  Create the missing version in Spacelift by hand, pointing it at the correct commit, and acknowledge the finding once it is handled.
- **`registry-provider-versions-not-migrated`** is a warning, one per staged provider.
  Unlike the findings above, a private-registry provider _does_ generate — as a `spacelift_terraform_provider` definition.
  What doesn't carry over are its published versions: those are built, signed binaries the source's API never returns, so the kit migrates the definition and leaves the versions to you.
  Re-publish them to Spacelift from the release pipeline that builds them (point your existing provider-release flow at Spacelift).
  Warnings never block; they annotate the generated provider file in place (acknowledgement only quiets the audit listing).

When the results read right, apply:

```bash
liftoff configure --set source.module_workflow_tool=OPEN_TOFU
liftoff configure --set source.repository_map=@repos.yaml
liftoff audit --repair
liftoff model set stack:ws-oxRaEDV2f5uMHy5f \
  vcs.repository=my-repo \
  vcs.namespace=acme \
  vcs.branch=main \
  vcs.provider=GITHUB
```

`--repair` writes each rule's fix to the local store — never the source — and returns receipts.
Findings that were advertised `repairable` but could not be applied land in `skips[]` with a per-entity reason (the same shape `finalize state` uses), so a silent pass never looks like success.
Findings always show what _remains_:

```text
Findings (5)
  stack-missing-vcs-repository (error) (2)
    Description  A stack without a VCS repository cannot be created in Spacelift
    Repairable   no
    Remediation  change one with `liftoff model set stack:<id> vcs.repository=…` (vcs.namespace, vcs.branch,
                 vcs.provider the same way); attach the stack to a repository at the source and re-discover, or
                 unstage this stack to leave it out of the batch

    Entities (2)
      this-is-a-test-workspace (id: ws-axzQMYTKvuxA9VDQ)
        Kind  stack
        URL   https://app.terraform.io/app/Apollorion/workspaces/this-is-a-test-workspace

      test (id: ws-jo93LkzmNb6bK6Ga)
        Kind  stack
        URL   https://app.terraform.io/app/Apollorion/workspaces/test

  … the three warning groups (context and stack secrets, the priority-context
  shadow) print above, unchanged — repair only touches repairable findings.

Counts
  Error    2
  Warning  23

Repaired (10)
  ┌──────────────────────────────┬─────────────┬──────────────────────┬────────────────┬───────────┐
  │ Rule                         │ Entity Kind │ Entity Id            │ Field          │ New       │
  ├──────────────────────────────┼─────────────┼──────────────────────┼────────────────┼───────────┤
  │ missing-vcs-branch           │ module      │ mod-AJu96tYoVyzKPEjw │ vcs.branch     │ main      │
  │ missing-vcs-branch           │ stack       │ ws-RjHgP1J9E5vrpwSP  │ vcs.branch     │ main      │
  │ …                            │ …           │ …                    │ …              │ …         │
  │ module-missing-workflow-tool │ module      │ mod-AJu96tYoVyzKPEjw │ workflow_tool  │ OPEN_TOFU │
  │ …                            │ …           │ …                    │ …              │ …         │
  └──────────────────────────────┴─────────────┴──────────────────────┴────────────────┴───────────┘

Next
  $ liftoff model set stack:ws-axzQMYTKvuxA9VDQ vcs.repository=…
  $ liftoff model set stack:ws-jo93LkzmNb6bK6Ga vcs.repository=…
```

The third VCS-less stack was fixed with `liftoff model set` before this run; the other two still need one, a fix at the source and re-discover, `unstage`, or `audit --ignore-finding`.
Everything else — the repaired branches and module tool, the warnings — is ready to render.

Worth knowing:

- **Repair is idempotent and local.**
  Re-running `--repair` writes nothing new, and a re-discover overwrites repairs — just repair again after.
- **`--rule` scopes a run** to named rules (repeatable): `liftoff audit --repair --rule missing-vcs-branch`.
- **One entity at a time is [`liftoff model set`](model.md), not a flag here.**
  `audit --repair` is the estate-wide fix: it applies a config key everywhere it fits and only ever fills what is empty.
  `model set` names the entities and is the only thing that can change a value that is already populated.
  The `Next` commands after an audit name whichever of the two each finding needs.
- **Finding acceptance belongs to audit and persists in the store.**
  Use `--ignore-finding rule@entity-kind:entity-id` for an error, or `--acknowledge-finding rule@entity-kind:entity-id` for a reviewed warning or info finding; repeat either flag to make several exact decisions in one run.
  The entity kind distinguishes findings when two entity types share a source id.
  A bare rule accepts every current finding of the severity that flag handles.
  Ignored errors leave the active list and appear under `ignored`; acknowledged warnings and info appear under `acknowledged`.
  Both still render as `# ERROR:`, `# WARNING:`, or `# INFO:` comments, so acceptance never hides the issue from the generated code.
  If a finding changes to a severity that its saved decision does not accept, it becomes active again.
  The browser UI asks for confirmation before ignoring any error: ignoring unblocks generation but does not fix the code, so publish may fail until every `# ERROR` annotation is corrected.
  Undo a saved decision with `--revoke-finding rule@entity-kind:entity-id`; the finding returns to the active list immediately.
  Acceptance, revocation, and selector validation happen as one transaction, so a bad selector leaves the ledger unchanged.
  Run repair separately: acceptance flags cannot be combined with `--repair`, because decisions must apply to the findings after repair recomputes them.
- **Remaining errors block generation.**
  `liftoff generate` re-runs these same rules over the staged set and reads the saved decisions; it refuses while active error findings remain.
  Each one must be fixed, accepted here with `--ignore-finding` (rendered annotated), or removed by unstaging it.
  Warnings never block; they always annotate the generated code (acknowledgement only quiets the listing).

When no active error remains, the estate is ready to render: [generate](generate.md).
