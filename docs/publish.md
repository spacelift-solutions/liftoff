# Publish

Step 9 of [the migration walkthrough](README.md): hand the generated roots to Spacelift and apply the admin stacks in dependency order.
Once the stacks stand, [mutate](mutate.md) (step 10) and [finalize](finalize.md) (step 11) close out the batch.

## Step 9 — publish the module and create the admin stack

`liftoff publish` hands the generated code to Spacelift over the API, with no external git required.
For a split layout, it first uploads the reusable admin module inside the main managed repository, creates a private registry module, and waits for its version to become available.
It then commits the admin roots with that exact module version pinned, creates the root admin stack, binds its space-admin role, and shows its plan:

```bash
liftoff publish
```

Before publishing, liftoff checks whether non-root admins need to manage child spaces.
If the account disallows this, it stops before making changes and directs you to `liftoff transform enable-child-spaces`.
That [transform](transform.md#enable-child-space-management) needs human approval because it changes the account-wide permission setting.
Non-root admins can only manage child spaces with `inherit_entities = true`; publish rejects isolated child spaces in those roots.

The result identifies the repo, the current admin stack, the committed revision, and that stack's plan.
`Remaining Stacks` counts the later roots still to visit; `Complete` means the whole revision has finished.
`Registry` identifies the reusable module, its source repository, registry source, required module version, and the selected version pinned in the admin code.

### Reusable admin module

Publish looks for the account's shared `liftoff-admin` registry module using the `spacelift` provider, regardless of your migration's repository or stack names.
If it is missing, publish creates it against your migration repository with `project_root = "modules/admin-stack"`.
The repository and registry module carry `liftoff:managed`; no separate module repository is created.
An existing compatible module keeps its source repository and can be reused by another operator or a fresh local workspace.
When a new release is needed from a different migration repository, publish updates the shared module's source to that repository, retaining its published versions.
That repository must be in the module's existing space.
Publishing a registry version does not apply any admin resources.

The repository-root `.spacelift/config.yml` controls the source release:

```yaml
version: 1
module_version: 2.0.0
tests: []
```

The filename is `config.yml`, not `config.yaml`.
Publish reads `module_version` from this file and passes it to the registry when creating the version.
Generation rewrites the file with the module release bundled in the kit.

Each kit release declares a minimum module version; this kit requires `2.0.0`.
The module's version is independent of the CLI release version, so unrelated CLI changes do not force module releases.
The configured `module_version` must meet that minimum and remain within the same major version.
Publish chooses the newest active, non-withdrawn stable version at or above the configured version within that major, then pins that exact version.
For example, a kit requiring `2.0.0` reuses `2.2.0`, but does not select `1.0.0` or assume `3.0.0` is compatible.
If only older releases exist, it publishes the generated module using the configured version.
If only a newer incompatible major is available, it asks you to upgrade the kit instead of publishing a downgrade.
Failed, pending, prerelease, and withdrawn versions are never selected as ready releases.
If the required version is still being published, the command waits for it; a failed or withdrawn required version stops publication.
Publish refuses an unrelated module or a module with different source settings.
An interrupted publish can be rerun; it checks the existing repository, module, and version before creating anything again.
Changing space resources never republishes an already compatible module.
When changing the shared module implementation, increase `module_version` before publishing; an existing version is immutable.

On a fresh repository, publish first uploads the generated tree with local module calls.
On an existing repository, the first commit updates only `modules/admin-stack/` and `.spacelift/config.yml`, preserving the current admin calls.
Once the module version is available, a second commit updates the admin code with its registry pin.
An existing admin stack therefore keeps its previous module version during registry publication.
Publish cancels queued runs for the intermediate module-source commit, or waits for their plans and discards them, before returning the final revision's plan.
It does not confirm those intermediate runs or cancel runs for unrelated commits.
Publish changes the module sources and adds exact version pins in the uploaded copy of each `liftoff.tf`.
Your local generated files retain relative sources for offline validation and the bring-your-own-Git workflow.
Before planning an admin that calls the reusable module, publish checks whether that admin's space already has access through inheritance or an existing module share.
If necessary, it adds an explicit share while preserving existing shares.
Explicit sharing requires the account's module-sharing capability and sufficient permissions for the publishing key.
If sharing is unavailable for a space with inheritance disabled, publish stops with an access error before planning that admin.
It does not change the space's inheritance setting or grant the child admin permissions over the module's space.

Each parent creates its immediate child spaces and places their admin stacks inside them through the reusable module.
Each child admin receives space-admin over its own space.
The children keep their own states and receive inputs through stack dependencies.

The plan itself streams to your terminal as Spacelift produces it, the same output the run page shows.
Piped or under `--output json` it comes back inside the result object instead (the plan phase only, not the `tofu init` preamble), so stdout stays one parseable object an agent can read.

Each admin stack applies one space directory.
Its code creates that space's contents, its immediate child spaces, and those children's admin stacks; stack dependencies carry inputs between them.
Its own space is owned by the parent state.
No parent calls its child directories as modules.
Its `project_root` is the module root, its provider is `SPACELIFT` (the managed repo), and it manages its own state.

The repositories, registry module, and root admin stack are labelled **`liftoff:managed`** when liftoff creates them, and liftoff only touches what carries that label.
If a repo or stack already exists under the name it wants without the label, it stops and says so rather than reconfiguring something that isn't its own — point it at a different name with `liftoff configure`, or add the label yourself to hand the entity over.
liftoff won't add that label to anything it didn't create; taking ownership of your entities is your call, not the tool's.

Publish is **idempotent and re-runnable**: it commits only the files that changed (all of them the first time), and when nothing has changed since the last publish it's a no-op — `No Op yes`, cheap enough to run any time to check you're current.
If the unchanged revision's last run stopped without finishing, publishing starts a replacement run and returns its new plan and proof token.
Re-generate after new repairs, then `liftoff publish` again to push the delta.

Publish stops at the plan and **applies nothing**.
Admin stacks have autodeploy disabled. In the individual-review flow, each run waits in `UNCONFIRMED` until you confirm its plan. With `--approve-all`, you explicitly authorize future plans and the command confirms them automatically.
Check the resource count against the `Counts` your discover reported.

### Apply the plan you read

In an interactive terminal, review the plan and run `liftoff publish --confirm`.
For agents, publish also prints a **proof token** for that plan.
Agent confirmation takes that token and an explicit `--confirm`:

```bash
liftoff publish --confirm --proof-token <token from the plan>
```

The token covers that one plan — the run, the commit it planned, and the resource counts.
Re-generate, publish again, or let anything else change what would apply, and the old token is refused; you read the new plan and use its new token.
It is the same guarantee as handing `tofu apply` a saved plan file, and the reason an agent cannot apply a plan it never read.
Which means publish's output is the thing you are proving you read: filtering it down to the token leaves you approving a plan you never saw.

Reading the plan is only half of it.
Applying also needs a person to approve it, and that approval is not something an assistant can supply — the refusal names the command to run.
See [the agent rules](README.md#driving-this-as-an-agent) for how that exchange goes.

Each confirmation applies only the stack whose plan you read.
After that apply finishes, the same command automatically triggers or reuses the next outstanding plan and prints it.
A prominent banner names the stack and its position in the sequence, followed by the next confirmation command.
Review that plan, then run `liftoff publish --confirm` again; agents must use the new plan's token and obtain separate approval.
The final apply prints `ALL ADMIN STACKS APPLIED`.
JSON output carries the next plan under `next_plan`, including its log, within one result object.
Parents finish before their children are planned.
The command creates only the root admin stack directly; applying each parent creates the next level of spaces, admin stacks, and their dependencies.
Completed runs for the same revision are reused, so this sequence can resume after an interruption.
Wait until every admin stack has finished before moving on to mutate and finalize.
`status` reports publish as applied only after the last stack finishes.

Applying pushes nothing (a new commit would replan and retire the token).
It confirms the run and streams its apply, then plans the next stack using the same published revision without reading local generated files.
If that next plan fails, the error preserves the successful apply and tells you to run `liftoff publish` to resume.
A failed apply stops the sequence.

### Automatically apply the whole publish

To publish and apply every remaining admin stack without pausing between plans:

```bash
liftoff publish --approve-all
```

This explicitly approves plans that have not been generated yet, including any resources they create, change, or destroy.
The command publishes the code, then plans and applies each stack in dependency order at that revision.
It streams each plan and apply, names the stack being automatically approved, and ends with `ALL ADMIN STACKS APPLIED`.
It stops on the first planning or apply failure, or if the repository revision or state owners change during the operation.
Completed applies remain recorded; rerunning resumes at the first unfinished stack for the same revision.
JSON output contains the ordered plans and applies under `stacks`; failures retain partial progress in the error details.

`--approve-all` and `--confirm` are mutually exclusive.
Use `--confirm` when you want to review and approve each plan separately.

A person running `--approve-all` in their terminal grants this approval through the flag itself.
An agent needs separate, single-use consent covering the account, repository revision, and stack layout:

```bash
liftoff approve publish:approve-all
```

The agent first runs `liftoff publish --approve-all` to prepare the publish and register the approval request.
The person runs the approval command in their own terminal, then the agent repeats the original command.
This mode needs no per-plan proof token: the person has explicitly authorized future plans for the specified publish.
An existing `publish:apply` approval cannot authorize the whole publish.
A failed or interrupted invocation needs fresh consent before an agent can resume; changing the account, revision, or layout invalidates the earlier approval.

### Publish from the browser UI

The Publish screen offers **Plan admin stacks** for individual review and **Approve all admin stacks** for unattended deployment.
After a parent apply, the next child's plan appears with its own confirmation button and stack position.
The screen keeps returned plans and apply logs grouped by admin stack, with links to the matching Spacelift runs.
Publish is complete only when every admin stack for the revision has finished.
A failed bulk apply preserves completed work and failure logs without marking the step complete.
Command results appear when the command finishes; the browser does not stream live run logs.

Approving all stacks opens a confirmation dialog naming the account and explicitly covering future plans, including destructive changes.
When child-space management is disabled, **Review account setting** reads the setting and opens a separate confirmation describing its account-wide scope.
Canceling either dialog makes no change.
Publishing creates the migrated workload stack configurations but does not run those workloads.

### Missed the log? Replay it

Once a plan or apply has scrolled past — a failed apply is the usual case — you don't have to re-run anything to read it again:

```bash
liftoff publish last
```

This refetches the most recent run of the admin stack selected by the last publish from Spacelift and replays its log the way `publish` streamed it.
It reads the run from the destination, so it reflects what actually happened (including a run someone triggered from the UI) and writes nothing to your workspace.
The output names which run it replayed and how that run ended; with no run to replay, it says so.

The next publish reconciles the generated configuration. Changing an already-applied resource's owning space requires an explicit state transfer; generation refuses to pretend that a cross-state move is an ordinary apply.

Because that unconfirmed run holds the stack, a later `liftoff publish` would queue behind it.
Publish handles the common case itself: when its own newer push supersedes a run still waiting for confirmation, it discards that stale run and tells you which (`Discarded Runs`).
It won't touch a run that's still working — it stops and says which one to wait for — and it refuses to show you a plan that isn't the one your module would apply, which happens when something else pushed to the repo after you.

The generated code carries secret _references_ and no state, so the stacks stand up from discover's read-only data alone.
Everything that couldn't travel as code is moved in afterward, in the next steps.

**Prefer your own VCS?**
The managed repo is the paved road, not a requirement — `liftoff` only emits files.
To commit the module to your own GitHub/GitLab/etc.
and wire the admin stack yourself, see [bring your own git](publish-byo-git.md).

## Existing single-state deployments

This layout is for migrations using independent admin states.
Publish refuses to replace an existing single-state deployment with split roots: that would remove child resources from the old configuration before their state was transferred.
Keep the existing deployment on its current configuration until a state split has been performed.
The generated `liftoff-stacks.json` describes the intended state owners and directory layout.
Changing from the earlier child-owned-space layout to parent-owned spaces also requires a state transfer or a reset of a disposable demo.
Publish refuses that ownership change while the old deployment exists; a fresh workspace must match the destination manifest before it can adopt the deployment.
After a disposable deployment has been removed, publish checks that both its repository and every recorded admin stack are absent before accepting a new ownership layout.
The new publish replaces its old publish record while preserving local export and staging data.

## What comes next: steps 10 and 11

The applied module creates the _shapes_.
With the stacks standing, [`liftoff mutate`](mutate.md) (step 10) captures what could not travel as code (secret values and Terraform state), and [`liftoff finalize`](finalize.md) (step 11) pushes it into the live stacks before flipping the batch to migrated.
Each has its own page with the details and the ordering that finalize enforces.
