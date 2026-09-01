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
```

Each additional transformation gets its own `liftoff transform <name>`
subcommand and matching `transform.<name>.*` settings. One transform never
widens another command's behavior.
