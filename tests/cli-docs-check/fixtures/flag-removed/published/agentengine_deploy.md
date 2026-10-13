> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine deploy

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Deploy the last successful build to the platform.

## Synopsis

Deploy the last successful build in the workspace.

Pass --build-id or --version to deploy a specific build; both skip the setup check.

Without either, deploy checks login, workspace binding, a declared network egress policy, local .env entries, the last successful build, and Atlas setup. Every populated .env key must exist as a project or workspace secret (platform-reserved names are skipped). Blank entries are ignored. The check compares key names only, and infers nothing from env.example or a missing .env. An unreadable .env or a failed secret listing must be resolved first.

On an interactive terminal, deploy offers to store each missing .env value with `agentengine secret set` after confirmation, and leaves existing secrets unchanged. It runs `agentengine init` when no workspace is bound, runs the combined build-and-deploy path when the workspace has no successful image, and runs `agentengine atlas setup` for an unlinked Atlas setup after syncing local entries. A MONGODB\_URI that does not match a live cluster in the linked Atlas project is reported with instructions to provide a URI or create one.

Non-interactive deploy, redirected stdout, --json, and --all never prompt, run init, start a build, or provision Atlas. They print the missing setup and the commands to fix it. --no-wait never starts a build. --workspace and --all print `agentengine build` when no image exists. --yes accepts billed Flex defaults and Atlas IP access-list changes during atlas setup, and is not implied by a TTY.

\--auto builds and tails in one step and is single-agent only. It rejects --build-id, --version, --no-wait, --workspace, and --all.

The workspace ID comes from .agentengine/state.json, written by `agentengine init`. Run from an agent directory, or pass --workspace-id to deploy to an existing workspace with no agent directory. With no local agent directory, --workspace-id cannot start a source build: the hint is `agentengine deploy --auto` from an agent directory.

```bash
agentengine deploy [flags]
```

## Options

```bash
    --all                   Monorepo: deploy all workspaces sequentially
    --auto                  Build the agent and tail the auto-triggered deployment in one step
    --base-url string       Platform base URL
    --build-id string       Build ID to deploy (default: last successful build)
    --context string        Named context to target (see 'agentengine context list')
-h, --help                  help for deploy
    --no-wait               Return immediately after triggering without polling for status
    --org-id string         Organization ID
    --project-id string     Project ID
    --timeout duration      Maximum time to wait per deployment (total time = timeout x number of agents for --all) (default 30m0s)
    --version string        Deploy the release build for this declared agent.yaml version (mutually exclusive with --build-id)
    --workspace string      Monorepo: deploy a specific workspace by name (from root agent.yaml)
    --workspace-id string   Workspace ID
-y, --yes                   Accept billed Flex defaults and Atlas IP access-list changes when deploy runs atlas setup
```

## Options inherited from parent commands

```bash
    --log-file string    override log file path
    --log-level string   file log verbosity (error|warn|info|debug) (default "info")
    --no-log             disable file logging
-q, --quiet              silence stderr below error
-v, --verbose count      raise stderr verbosity (-v info, -vv debug)
```

## SEE ALSO

- [agentengine](https://www.mongodb.com/docs/agentengine/cli/agentengine.md#std-label-agentengine) - Agent Engine local development CLI.

- [agentengine deploy cancel](https://www.mongodb.com/docs/agentengine/cli/agentengine_deploy_cancel.md#std-label-agentengine_deploy_cancel) - Cancel an in-flight deployment.

- [agentengine deploy get](https://www.mongodb.com/docs/agentengine/cli/agentengine_deploy_get.md#std-label-agentengine_deploy_get) - Get details of a deployment.

- [agentengine deploy list](https://www.mongodb.com/docs/agentengine/cli/agentengine_deploy_list.md#std-label-agentengine_deploy_list) - List deployments for a workspace.

- [agentengine deploy logs](https://www.mongodb.com/docs/agentengine/cli/agentengine_deploy_logs.md#std-label-agentengine_deploy_logs) - Show the event log for a deployment.
