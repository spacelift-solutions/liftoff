# Publish with your own git

[`liftoff publish`](deploy.md) is the paved road: it commits the generated module to a **Spacelift-managed repo** and stands up the admin stack for you, over the API, with no external VCS to wire.
It is **optional**.
`liftoff` only ever *emits files* — `tofu` is the apply engine either way — so you can keep the module in your own GitHub/GitLab/Bitbucket/etc.
and wire the admin stack yourself.
This page is that path, end to end.

Reach for it when you want the migration's IaC to live in your own VCS from day one — under your review, your branch protection, your CI — rather than in a Spacelift-hosted repo.

## Where the code is

`liftoff generate` writes the module under your workspace:

```text
.liftoff/data/generated/
```

That directory **is** the module: a root module (`providers.tf`, `versions.tf`, and a `liftoff.tf` that calls one module per space) plus a nested directory per space.
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

Wire an **admin stack** pointing at your repo.
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

That's the same shape `liftoff publish` builds; you're just doing it by hand against your repo instead of a managed one.

## Applying, and what stays the same

Trigger the admin stack.
Its run does a `tofu init` and applies the module, creating every space, context, stack, and module — review the plan like any other run; the resource count should line up with the `Counts` your discover reported.
Push a change to the module and its next run reconciles Spacelift to match, moves in place.

Everything downstream is **identical to the managed-repo path**.
The module carries secret *references* and no state, so the stacks stand up from discover's read-only data alone, and the [finalize](finalize.md) steps (`sensitive`/`state`/`modules`) work exactly the same — they resolve entities by name, not by how the repo is hosted.
The only difference is who owns the commit and the stack: you do.
