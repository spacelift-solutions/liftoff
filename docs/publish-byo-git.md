# Publish with your own git

[`liftoff publish`](publish.md) is the paved road: it commits the generated module to a **Spacelift-managed repo** and stands up the admin stack for you, over the API, with no external VCS to wire.
It is **optional**.
`liftoff` only ever _emits files_ — `tofu` is the apply engine either way — so you can keep the module in your own GitHub/GitLab/Bitbucket/etc.
and wire the admin stack yourself.
This page is that path, end to end.

Reach for it when you want the migration's IaC to live in your own VCS from day one — under your review, your branch protection, your CI — rather than in a Spacelift-hosted repo.

## Where the code is

`liftoff generate` writes the module under your workspace:

```text
.liftoff/data/generated/
```

That directory contains independent OpenTofu roots, one per space. Each has its own `providers.tf`, `versions.tf`, and `liftoff.tf`. The `liftoff-stacks.json` file records the admin stack IDs, project roots, and parents.
Commit the whole tree, preserving its layout — it's plain OpenTofu.

```bash
cd .liftoff/data/generated
git init -b main
git add .
git commit -m "Initial Spacelift migration module"
git remote add origin <your-repo-url>
git push -u origin main
```

Re-run `liftoff generate` after new repairs and commit again the same way; the module is deterministic, so the diff is exactly what changed.

## What to create on the Spacelift side

The generated child admin stack definitions target a Spacelift-managed repo by default.
Before using external VCS, adapt the shared child admin module in `modules/admin-stack/main.tf`: replace `spacelift_repo {}` with your VCS integration settings and set the branch.
Set the repository and prefix project roots in each `liftoff.tf` module call if the generated tree lives below your repo root.
Generation rewrites these wiring files, so reapply those adaptations after regenerating.
Keep the generated admin stack IDs and dependency references consistent with the manifest.

Wire the **root admin stack** pointing at your repo, using the root stack ID recorded in the manifest.
In the Spacelift UI (or via the `spacelift_stack` Terraform resource / a Blueprint):

1. **Connect the repo.**
   Use your existing VCS integration (the GitHub app, GitLab, etc.); add one if you haven't.
2. **Create the stack** on that repo and branch, with:
   - **Project root** = the module root (the directory you committed — `.`
     if the module is the repo root).
   - **Workflow tool** = OpenTofu (the generated module is OpenTofu).
   - **Managed state** on — the admin stack keeps its own state.
3. **Grant it space-admin.**
   Attach the **space-admin role** to the stack on the space it manages (the root space, unless you scoped the migration elsewhere).
   The old "administrative" checkbox is retired — admin is a role binding now.

Set `TF_VAR_liftoff_space_admin_role_id` on the root admin stack to your account's built-in space-admin role ID. The dependency chain passes that ID to the child stacks.

## Applying, and what stays the same

Trigger the admin stack.
Review and apply its plan, then review and apply each child admin stack in dependency order. Each stack creates its own space contents, immediate child spaces, and admin stacks inside those child spaces. Autodeploy stays disabled. Finish the whole tree before finalizing.
Moving an applied resource between spaces requires transferring its state between admin stacks.

Everything downstream is **identical to the managed-repo path**.
The module carries secret _references_ and no state, so the stacks stand up from discover's read-only data alone, and the [finalize](finalize.md) steps (`sensitive`/`state`/`modules`) work exactly the same — they resolve entities by name, not by how the repo is hosted.
The only difference is who owns the commit and the stack: you do.
