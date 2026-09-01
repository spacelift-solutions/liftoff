<!-- This page is generated from the error codes in the liftoff source. Do not edit it by hand. -->

# What went wrong: every error code

Every failure `liftoff` reports is one object, and its `code` is the part meant for a machine:

```text
error:
  code: nothing_staged
  message: no staged units to finalize
  remediation: stage a batch first with `liftoff batch stage`
schema_version: 1
```

The `code` is stable, so an agent can branch on it.
The `message` says what happened in this particular case, and the `remediation` says what to do about _this_ one — it is more specific than this page can be, and it is the instruction to follow when the two overlap.
Some errors add an `entity` naming what the failure was about, a `next` list of commands to run, and `details` with the specifics.

This page is the other half: what a code means in general, and what class of problem it puts you in.
Read it when you meet a code you do not recognise, or when you are deciding what to do about a class of them rather than one.
An agent can read it in-band with `liftoff skills errors`.

Codes are grouped by **where the problem is** — which surface reported it.
Where to fix it is often somewhere else, and the "What to do" column says where: a credential the source rejects is reported by the source and fixed in your configuration.

Two things worth knowing before the tables:

- **No error is fatal to the migration.** The store is the source of truth and every step re-runs safely, so a failure means the step did not happen, not that the migration is spoiled.
- **A code of `unset_error_code` is always a bug.** It means an error reached you without one. Report it.

## What the command asked for

The command, its flags, or the entity it named. Nothing has happened yet, and re-running with the invocation corrected is all these need.

| Code | What it means | What to do |
| --- | --- | --- |
| `beta_only` | This feature is in beta and needs explicit consent. | Re-run with `--beta`. |
| `entity_not_found` | No entity with that id is in the local store. | Run `liftoff discover` first, or check the id with `liftoff model list`. |
| `error_finding` | The flag only accepts warning or info findings, but an error finding was selected. | Error findings block generation. Accept them with `liftoff audit --ignore-finding <rule[@kind][:entity]>`, or fix or unstage them. |
| `field_not_settable` | The named field cannot be written. | The error says why; write a field the entity allows, or correct it at the source and re-discover. |
| `invalid_arguments` | The command's positional arguments are not in the form it expects. | The error shows the expected form. Run the command again with arguments in that form. |
| `invalid_flag` | A flag was given a value it does not accept. | The error lists the values the flag takes. |
| `invalid_value` | The value cannot be held by the field it was written to. | Pass a value the field accepts; the error says what is wrong with this one. |
| `malformed_selector` | A selector could not be parsed. | The error gives the form the selector takes and an example. |
| `no_selectors` | No entity was specified for the command. | Specify at least one entity as `<kind>:<id>`, or pass the flag that selects all entities. |
| `no_such_finding` | The selector matches no finding the current audit reports. | Run `liftoff audit` to see current findings. If this one was fixed, remove the flag. |
| `not_addressable` | That kind describes the whole destination account and has no id for an individual record. | List them instead with `liftoff model list --kind <kind>`. |
| `not_migratable` | The named kind is not a unit a batch can hold. | Choose a space, stack, module, or context. Child entities are included with their owner. |
| `nothing_to_approve` | Nothing is waiting on approval under that key. | Run the command that requires approval first. It creates the approval request. |
| `unknown_capability` | No mutation capability with that name exists in this build. | The error lists the available capabilities. |
| `unknown_field` | The entity has no field with that name. | The error lists the available fields. |
| `unknown_kind` | That is not an entity kind. | The error lists the kinds; `liftoff model kinds` lists them too. |
| `unknown_rule` | No audit rule is registered under that id. | The error lists the registered rules. |
| `unknown_source` | No source with that id exists in this build. | `liftoff sources` lists the available sources. |
| `unknown_topic` | No guidance page exists for that topic. | Run `liftoff skills` with no topic to list them. |
| `value_mismatch` | The field does not hold the value the guard expects, so the write was refused. | Read the entity and pass its current value, or remove `--from` to write without checking. |
| `warning_finding` | The flag only accepts error findings, but a warning finding was selected. | Warnings do not block generation. Hide a reviewed warning with `liftoff audit --acknowledge-finding <rule[@kind][:entity]>`. |

## The workspace's configuration

A key in `config.yaml` is missing, unparsable, or wrong. `liftoff configure validate` reports all of these before a step has to.

| Code | What it means | What to do |
| --- | --- | --- |
| `invalid_config` | A configured value cannot be used. | Set a valid value with `liftoff configure --set <key>=<value>`. |
| `malformed_config` | The configuration file exists but cannot be parsed. | Fix the YAML manually, or run `liftoff configure` again. |
| `missing_config` | A configuration key this step needs is not set. | Set each key the error names with `liftoff configure --set <key>=<value>`. |
| `no_config_file` | The workspace has no configuration file. | Run `liftoff init` to scaffold the workspace, then `liftoff configure`. |
| `no_source_configured` | No source is selected in the workspace configuration. | Run `liftoff configure --source <id>`; `liftoff sources` lists them. |
| `unresolved_env` | The configuration references environment variables that are not set. | Export the variables the error names, then retry. |
| `validate_failed` | Configuration validation failed. | Review the per-key report, fix the marked settings, and run `liftoff configure validate` again. |

## Where the migration has got to

The step is fine, but the migration is not at the point it needs — nothing is staged, an approval has not been given, a page has not been read. The order the walkthrough runs in is what satisfies these.

| Code | What it means | What to do |
| --- | --- | --- |
| `approval_needs_a_person` | Approving a source-mutating step is a person's decision, and the caller looks like an agent. | Ask the user to run the approval in their own terminal. Running it from an agent session is also rejected. |
| `audit_errors` | Error-level audit findings would make the generated output invalid or rejected at apply time. | Fix the findings, unstage the units they belong to, or accept each explicitly with `liftoff audit --ignore-finding <rule[@kind][:entity]>`. |
| `comprehension_required` | The step expects its guidance page to have been read first. | Run the command the error names, read the page, and pass the token it prints as `--proof-token`. |
| `comprehension_stale` | The guidance page changed after the proof token was minted. | Read the page again and pass the new token. |
| `consent_required` | The step needs a person's recorded approval before it runs. | Ask the user to run the approval command the error names in their own terminal; it prints what it is approving. |
| `nothing_published` | No publish is recorded for the repository this step would act on. | Run `liftoff publish` first, then confirm the plan it shows. |
| `nothing_staged` | No units are staged, so the step has nothing to act on. | Stage a batch first with `liftoff batch stage`. |
| `nothing_to_publish` | There is no generated module to publish. | Run `liftoff generate` first. |
| `unpushed_data` | The staged batch holds captured secret values or state that have not reached Spacelift yet. | Run `liftoff finalize sensitive` and `liftoff finalize state` first. |

## The system being migrated from

The source refused a request, could not be reached, or answered with something unusable. Only discover and mutate talk to it, so these never appear once the estate is in the local store.

| Code | What it means | What to do |
| --- | --- | --- |
| `agent_protocol_error` | The source's run-agent endpoint answered outside its own protocol. | Confirm the configured endpoint speaks the agent protocol, then retry. |
| `agent_register_failed` | The temporary run agent a capture needs could not be registered. | Confirm the endpoint speaks the agent protocol and that the configured credential may manage agents. |
| `invalid_credentials` | The source rejected the configured credential. | Check the credential is valid and has access, then re-run `liftoff configure`. |
| `malformed_response` | The source answered with something that is not the document its API promises. | Confirm the configured endpoint is the source's API, then retry. |
| `not_user_token` | The configured source credential is not the kind of token an export can run with. | Create a credential that identifies a person and set it with `liftoff configure`. |
| `rate_limited` | The source is rate limiting the kit's requests. | The kit backs off and retries automatically. If the error continues, lower the source's requests-per-second and run the command again. |
| `source_rejected` | The source refused the request outright, and retrying will not change that. | Check that the configured credential can act on this entity. |
| `source_unavailable` | The source failed in a way that is usually transient. | The kit retries read requests automatically. Run the command again if the error continues. |
| `source_unreachable` | The source could not be reached at all. | Check the configured endpoint and network connectivity, then retry. |

## The git provider

Resolving a module's versions reads its repository over git. These report what the provider said.

| Code | What it means | What to do |
| --- | --- | --- |
| `vcs_auth_failed` | The git provider rejected the configured token. | Check the token has read access to the module repositories. |
| `vcs_host_required` | The git host is unknown, or the destination account cannot reach the host named by the source. The kit will not send a token to an unconfirmed host. | Set the VCS host with `liftoff configure --set vcs.host=<host>`. |
| `vcs_http_error` | The git provider answered with an HTTP status the kit cannot use. | Run the command again. If the error continues, check the repository shown in the error. |
| `vcs_incomplete` | The module has no repository connection to resolve versions from. | It was published without a repository, so its versions cannot be resolved. Create them manually in Spacelift if needed. |
| `vcs_provider_unsupported` | Module versions cannot be resolved automatically for that git provider. | Create the module versions manually in Spacelift, pointing each one to its tag's commit. |
| `vcs_repo_not_found` | The git provider has no repository at the configured address. It returned 404 or advertised no refs. | Confirm the repository still exists, and that the host in the message is the right one. |
| `vcs_unreachable` | The git provider could not be reached. | Check network connectivity and the repository address, then retry. |

## Spacelift

The destination refused a call or could not be reached. Every one of these carries Spacelift's own message, the operation that failed, and the entity it was about.

| Code | What it means | What to do |
| --- | --- | --- |
| `admin_run_failed` | The admin stack's run ended without applying the module. | Read the run's log, fix what it reports, then re-run `liftoff generate` and `liftoff publish`. |
| `admin_run_in_flight` | An earlier admin-stack run is still working, so this one cannot plan yet. | Let that run finish, then re-run `liftoff publish`. |
| `admin_run_superseded` | A newer admin-stack run has replaced the one this step was following. | Another commit was pushed to the admin stack's repository. Run `liftoff publish` again to plan the current revision. |
| `no_admin_run` | The admin stack has no run for the revision this step needs. | Re-run `liftoff publish` to plan the current module, then confirm the plan it shows. |
| `repo_not_managed_by_liftoff` | A repository with the configured name exists but is not labelled as the kit's. | Point the kit at a different name, or add the label the error names to hand the existing one over. |
| `run_not_awaiting_confirmation` | The admin stack run is not waiting for plan confirmation. | Re-run `liftoff publish` for a fresh plan and token. |
| `spacelift_api_error` | Spacelift refused the call, and its answer does not say which kind of refusal it is. | Review Spacelift's message in the error. Run again with `-vv` to log the request. |
| `spacelift_auth_failed` | Spacelift rejected the configured API key. | Check the key id and secret, and that the key is enabled in the account. |
| `spacelift_conflict` | Spacelift already holds the entity the kit tried to create. | Delete it in Spacelift to have the kit recreate it, or label it so the kit adopts it. |
| `spacelift_forbidden` | The API key is valid, but its role does not permit this. | Give the key admin on the space the entity belongs to, or configure a key that has it. |
| `spacelift_http_error` | Spacelift answered with an HTTP status the kit cannot use. | Run the command again. If the error continues, check the endpoint shown in the error. |
| `spacelift_malformed_response` | Spacelift's answer was not a usable GraphQL response. | Confirm the configured endpoint points at the account API, then retry. |
| `spacelift_not_found` | Spacelift has no such entity, or the API key cannot see it. | Confirm it exists in the account and that the key's role covers the space it belongs to. |
| `spacelift_rejected` | Spacelift rejected a value the kit sent. | The value comes from the local store: correct it with `liftoff audit --repair` or `liftoff model set`, then re-run. |
| `spacelift_role_missing` | The account has no space-admin role for the kit to bind the admin stack to. | Confirm the account has the built-in space-admin role. |
| `spacelift_state_upload_failed` | A captured state blob could not be uploaded to Spacelift's storage. | Retry; the upload is resumable and no state was lost locally. |
| `spacelift_unreachable` | Spacelift could not be reached at all. | Check the configured endpoint and network connectivity. |
| `stack_not_managed_by_liftoff` | A stack with the configured name exists but is not labelled as the kit's. | Point the kit at a different name, or add the label the error names to hand the existing one over. |

## Capturing from the source, and undoing it

Source mutations record a restore point first and revert afterward. These codes report that process; run `liftoff restore` to finish an interrupted mutation.

| Code | What it means | What to do |
| --- | --- | --- |
| `backup_failed` | The restore point that must exist before the source is touched could not be written or verified. | Check the workspace directory is writable and has space, then retry; nothing at the source was changed. |
| `extraction_timeout` | No capture job arrived for an entity within the time allowed. | Run the command again. If the error continues, the source may not permit the runs required for capture. |
| `invalid_restore_point` | A recorded restore point is unrecognized or has no payload, so it cannot be reverted automatically. | Report it; the entity may need to be cleaned up manually at the source. |
| `pending_restore_points` | An earlier source-mutating run did not finish reverting. | Run `liftoff restore` to put the source back, then retry. |
| `restore_incomplete` | Some mutations were reverted and others are still pending. | Run the restore again. If errors continue, the listed entities may need to be cleaned up manually at the source. |
| `revert_failed` | A temporary change made for a capture could not be undone. | Run `liftoff restore` to finish reverting the source. |

## The local workspace

The store and the generated module on your own disk.

| Code | What it means | What to do |
| --- | --- | --- |
| `corrupt_store` | A row in the local store could not be decoded into the model. | Re-run `liftoff discover --clobber` to rebuild the store. |
| `generate_failed` | The generated module could not be written to disk. | Check the output directory is writable, then re-run `liftoff generate`. |
| `schema_too_new` | The workspace store was written by a newer build of the kit than this one. | Upgrade the kit, or point `--config-dir` at a workspace this build wrote. |
| `store_migrate_failed` | The workspace store cannot be brought up to this build's schema in place. | Keep it and run the build that wrote it, or start a separate workspace with `--config-dir`. |
| `unreadable_module` | The generated module directory holds something the kit cannot read. | The directory must hold only the generated module: remove anything else, or re-render it with `liftoff generate`. |
| `workspace_not_initialized` | There is no workspace store to read. | Run `liftoff init`, or point `--config-dir` at an initialized workspace. |

## What was discovered

The estate in the store cannot be migrated because it contains a missing reference, a cycle, or entities that would collide. Run `liftoff audit` for specific fixes.

| Code | What it means | What to do |
| --- | --- | --- |
| `ambiguous_spacelift_id` | Two entities in the batch resolve to the same Spacelift id, so one would overwrite the other. | Run `liftoff audit` to see the clash, then rename one at the source and re-discover, or unstage all but one. |
| `dangling_attachment` | An attachment points at an entity the store does not hold. | Re-run `liftoff discover` so related entities are captured together, or `--clobber` for a clean slate. |
| `dangling_space` | An entity references a space the store does not hold. | Re-run `liftoff discover --clobber` so every referenced space is present. |
| `invalid_space` | A space's parent chain forms a cycle, so it has no place in the tree. | A space cannot be its own ancestor: re-discover spaces with `liftoff discover --clobber`. |
| `unrepresentable_entity` | A discovered row cannot be represented in the migration model. | Run `liftoff discover` again to recapture it. If the error continues, report it; the row cannot be migrated. |

## The browser UI

`liftoff ui` only. The CLI is unaffected by these errors.

| Code | What it means | What to do |
| --- | --- | --- |
| `ui_cannot_nest` | A browser UI session cannot start another browser UI session. | Run the command from a separate terminal. |
| `ui_listen_failed` | The browser UI could not listen on the requested port. | Pass `--port 0`, or another free port. |
| `ui_needs_a_person` | The browser UI must be opened by a person, but the caller looks like an agent. | Agents should run commands directly. A person can open the UI from their own terminal. |
| `ui_server_failed` | The browser UI stopped with an error. | Run it again. If the error continues, use the commands directly. |

## Bugs in liftoff

These should never reach you. Each one means the kit used itself incorrectly, and the error asks you to report it. Nothing at the source is changed by one.

| Code | What it means | What to do |
| --- | --- | --- |
| `internal_error` | The kit reached an internal state that should be impossible. | This is a bug: report it with the message above. Nothing at the source was changed. |
| `not_implemented` | This command or feature is not implemented in this build. | The error identifies where the planned behavior is documented. |
