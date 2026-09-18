# Transform

Reshape the current staged batch before it is migrated.

The default walkthrough reproduces the source estate faithfully. A customer can
instead choose a deployment-wide policy while a batch is staged. The existing
admin stack applies that choice through `generate` and `publish`.

## Convert the staged deployment to OpenTofu

`workflow-tool` converts the staged stacks and modules to OpenTofu, including
stacks currently using Terraform FOSS or a custom workflow:

```bash
liftoff configure \
  --set transform.workflow-tool.target=OPEN_TOFU \
  --set transform.workflow-tool.version=1.8.7
```

Choose one OpenTofu version that the whole estate should run. The version is
written to stacks; modules have a workflow-tool setting but no runtime-version
setting.

Preview the complete change:

```bash
liftoff transform workflow-tool --dry-run
```

The report counts eligible, changed, already-conforming, and skipped stacks and
modules. It also reports runner images and custom-workflow scaffolding that
would be removed. The preview does not write the store and needs no approval.

The command transforms only the current staged batch. Previously migrated,
skipped, and unstaged entities stay untouched. If nothing is staged, it refuses
without writing the store.

You can still make the choice at the end of migration. First list the migrated
units, then explicitly re-stage the ones to transform:

```bash
liftoff batch list --status migrated
liftoff batch stage stack:<id> module:<id> --restage-migrated
```

Re-staging is deliberately gated because the next generation rewrites those
units' files. After re-staging, preview and apply the transform normally.

Then apply it locally:

```bash
liftoff transform workflow-tool
```

The transformation:

- writes `OPEN_TOFU` and the configured version to every selected stack;
- clears those stacks' runner images;
- writes `OPEN_TOFU` to every selected module;
- detaches custom-workflow contexts from converted stacks; and
- removes those contexts and mounted workflow files when nothing still uses
  them.

Skipped entities are always left untouched. The command never falls back to
transforming migrated or unstaged entities when no batch is staged.

## Place staged units into an existing destination space

Use this when the stacks should land in spaces that already exist on the
destination account, instead of recreating the source spaces.

List the destination spaces discover recorded:

```bash
liftoff model list --kind spacelift_space
```

`liftoff transform space list` shows the same saved destination-space snapshot
alongside local spaces planned in this workspace. It reads the local model; it
does not make a fresh request to the live account. Use it when choosing a
destination from the placement screen or when an agent needs local-space
metadata:

```bash
liftoff transform space list --output json
```

Map the current staged batch:

```bash
liftoff transform space mv --all-staged --to spacelift_space:<id> --dry-run
liftoff transform space mv --all-staged --to spacelift_space:<id>
```

`--to` also accepts `root` or the raw space id. The command writes a placement
override; it does not change the source space the estate was discovered from.
Source spaces that nothing staged still needs are unstaged.

### Drive placement from an AI agent

An agent can run the same placement workflow through the CLI. Use strict JSON
when another tool needs to inspect a receipt:

```bash
liftoff model list --kind spacelift_space --output json
liftoff batch list --status staged --output json
```

Choose a destination from `entities[].id` in the first receipt (`root` is also
valid), and build selectors as `<kind>:<id>` from `units[]` in the second. A
specific set can be previewed with:

```bash
liftoff transform space mv \
  stack:<id> module:<id> \
  --to spacelift_space:<destination-id> \
  --dry-run --output json
```

Use `--all-staged` instead of selectors when the whole staged placement batch
should move. It cannot be combined with selectors. Read the preview's
`destination`, `changed`, `already_mapped`, and `spaces_unstaged` fields before
applying. Every command also returns a structured `error` on refusal; branch
on `error.code`, and follow its `remediation` and `next` fields.

The write command updates the local model and may return `consent_required` to
an agent. Ask the user to run the exact approval command in `error.next` in
their own terminal, then rerun the original command unchanged. Do not try to
approve from the agent session. After a successful placement, continue with
the normal batch workflow:

```bash
liftoff audit --output json
liftoff generate --output json
liftoff publish --output json
liftoff publish --confirm --proof-token <token from the publish receipt> --output json
liftoff finalize staged --output json
```

The publish confirmation also has a person-only consent gate for an agent;
handle a `consent_required` refusal by following that receipt's `error.next`,
then rerun the confirmation with the same proof token.

If a selector is already `migrated`, explicitly restage it before previewing
the move:

```bash
liftoff batch stage stack:<id> --restage-migrated --output json
```

Restaging can itself return `consent_required`; use its `error.next` approval
command and rerun the same command after the user approves. It allows the next
`generate` to rewrite those units, so the user should review any hand edits.

The browser placement screen keeps unsubmitted moves in its local session
draft; `batch list` reports only applied model state. In **Review changes**,
open **Use these moves with an AI agent or CLI** and choose **Copy agent plan**
to share the exact inspection, preview, and apply argument arrays. An agent
should run them in the same liftoff workspace and review fresh dry-run receipts.
Browser agents can also use the labeled unit checkboxes and destination move
buttons; unit rows and destination rows expose stable `data-unit-key` and
`data-destination-id` attributes. Copying a plan makes no model changes.

### Arrange and review in the browser

In **Arrange**, drag units from the available list on the left onto a space in
the destination tree on the right. Dropping changes the space's unit count and
nothing else; choose the count to open a scrolling window of the units inside.
Lists show 50 rows per page. The account root is a destination too, and a unit
already in root can be moved to another space later. Attached contexts appear
with the stack that carries them. **+ New space** and the **+** on a row plan
local spaces from the same screen; **Delete** on a planned space removes it
from the plan while it is still empty.

Select **Review changes** for phase two. Review groups moves by destination and
shows conflicts before any write. Apply first stages unstaged units and their
dependencies; re-staging a migrated unit requires the person's explicit
consent. It then runs a dry run for each `transform space mv` group before
applying the local placement changes. The browser does not apply anything to
the live account by itself.

### Plan local destination spaces

Local spaces are workspace entries in the saved model. They are useful as
planned destinations while the migration is being built and are distinct from
spaces recorded from the destination account. Create and inspect them with:

```bash
liftoff transform space create --name payments-dev --parent root
liftoff transform space list
```

Use the exact `space:local:<id>` selector for a local space returned by
`transform space list`:

```bash
liftoff transform space mv stack:<id> --to space:local:<id> --dry-run
liftoff transform space mv stack:<id> --to space:local:<id>
```

`transform space rm space:local:<id>` only removes an empty staged local space
from the local plan (run it with `--dry-run` first). It does not delete a live
destination-account space.

`transform space mv` requires a staged batch. To remap after the resources are live,
restage them first, then transform, generate, publish, and finalize:

```bash
liftoff batch stage stack:<id> --restage-migrated
liftoff transform space mv stack:<id> --to spacelift_space:<id>
liftoff generate
liftoff publish
liftoff publish --confirm --proof-token <token from the publish plan>
liftoff finalize staged
```

Generate writes `moved.tf` so the next apply is a state move, not a destroy.
Units that were already migrated on an older build get that recorded prefix the
next time any command opens the store, so a remap of that batch still emits
moved blocks.
Read the plan from `publish` and use its proof token with `publish --confirm` to
apply it before finalizing the batch.
`finalize staged` records the new module prefix so a later remap can move again.

Re-run after `liftoff discover --clobber` only if you need to place again;
clobber rebuilds the store, including placement.

## Add labels to staged stacks

Labels stay on the stack through generate, which is how
`autoattach:<label>` policies on the destination account pick the new stacks
up. Configure the labels to add, then apply them to the staged batch:

```bash
liftoff configure --set transform.stack-labels.add=team:payments,env:prod
liftoff transform stack-labels --dry-run
liftoff transform stack-labels
```

Existing labels from the source are kept. The configured list is appended, and
duplicates are skipped. Re-run after `liftoff discover` because discover
restores the source labels.

To label only some staged stacks, or to use a list without changing the
configured key, name them and pass the labels for this run:

```bash
liftoff transform stack-labels stack:<id> stack:<id> --add team:payments,env:dev
```

Labels often follow the destination: one set for the payments team's dev
stacks, another for its prod stacks. Run the scoped form once per space.

The batch screen's **Labels** button runs the whole-batch form: it writes the
same config key, previews with the same dry run, and applies with the same
consent. The tag on a space row runs the scoped form for the staged stacks in
that space.

## Apply the result to Spacelift

`transform` writes SQLite only. Continue through the batch's normal audit,
generation, publication, and finalization:

```bash
liftoff audit
liftoff generate
liftoff publish
liftoff finalize staged
```

If you re-staged already-migrated units, review and preserve any hand edits
before generating: staged files follow the normal generation path and are
rewritten. Unrelated migrated files remain protected.

The command is idempotent. Re-running it with the same configuration reports
the estate as already conforming. If you later run `discover --clobber`, the
source-reported workflow tools return with the rebuilt store; re-run the
configured transform before generating and publishing again.

## Configuration shape

The settings are kept under the subcommand they control:

```yaml
transform:
  workflow-tool:
    target: OPEN_TOFU
    version: 1.8.7
  stack-labels:
    add: team:payments,env:prod
```

Each additional transformation gets its own `liftoff transform <name>`
subcommand. Settings that apply across the estate live under matching
`transform.<name>.*` keys. `transform space mv` is argument-driven (`--to`)
instead of configuration: the destination is chosen per run. One transform
never widens another command's behavior.
