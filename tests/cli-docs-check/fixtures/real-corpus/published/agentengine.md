> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Agent Engine local development CLI.

## Options

```bash
-h, --help               help for agentengine
    --log-file string    override log file path
    --log-level string   file log verbosity (error|warn|info|debug) (default "info")
    --no-log             disable file logging
-q, --quiet              silence stderr below error
-v, --verbose count      raise stderr verbosity (-v info, -vv debug)
```

## SEE ALSO

- [agentengine agent](https://www.mongodb.com/docs/agentengine/cli/agentengine_agent.md#std-label-agentengine_agent) - Inspect and edit agent configuration.

- [agentengine atlas](https://www.mongodb.com/docs/agentengine/cli/agentengine_atlas.md#std-label-agentengine_atlas) - Atlas workspace setup commands.

- [agentengine auth](https://www.mongodb.com/docs/agentengine/cli/agentengine_auth.md#std-label-agentengine_auth) - Authentication commands.

- [agentengine build](https://www.mongodb.com/docs/agentengine/cli/agentengine_build.md#std-label-agentengine_build) - Package and build the agent image on the platform.

- [agentengine completion](https://www.mongodb.com/docs/agentengine/cli/agentengine_completion.md#std-label-agentengine_completion) - Generate the autocompletion script for the specified shell

- [agentengine context](https://www.mongodb.com/docs/agentengine/cli/agentengine_context.md#std-label-agentengine_context) - Manage named platform targets.

- [agentengine create](https://www.mongodb.com/docs/agentengine/cli/agentengine_create.md#std-label-agentengine_create) - Scaffold a new agent from a starter template.

- [agentengine create-tool](https://www.mongodb.com/docs/agentengine/cli/agentengine_create-tool.md#std-label-agentengine_create-tool) - \[Experimental] Generate connector authoring files from an OpenAPI document or an existing catalog.

- [agentengine debug](https://www.mongodb.com/docs/agentengine/cli/agentengine_debug.md#std-label-agentengine_debug) - CLI debug logs.

- [agentengine deploy](https://www.mongodb.com/docs/agentengine/cli/agentengine_deploy.md#std-label-agentengine_deploy) - Deploy the last successful build to the platform.

- [agentengine dev](https://www.mongodb.com/docs/agentengine/cli/agentengine_dev.md#std-label-agentengine_dev) - Local dev environment commands.

- [agentengine docs](https://www.mongodb.com/docs/agentengine/cli/agentengine_docs.md#std-label-agentengine_docs) - Generate documentation for the CLI.

- [agentengine egress](https://www.mongodb.com/docs/agentengine/cli/agentengine_egress.md#std-label-agentengine_egress) - Show the deployed egress policy.

- [agentengine init](https://www.mongodb.com/docs/agentengine/cli/agentengine_init.md#std-label-agentengine_init) - Bootstrap org, project, and workspace for this agent repo.

- [agentengine invoke](https://www.mongodb.com/docs/agentengine/cli/agentengine_invoke.md#std-label-agentengine_invoke) - Invoke the deployed agent for the current workspace.

- [agentengine logs](https://www.mongodb.com/docs/agentengine/cli/agentengine_logs.md#std-label-agentengine_logs) - Stream agent runtime logs.

- [agentengine memory](https://www.mongodb.com/docs/agentengine/cli/agentengine_memory.md#std-label-agentengine_memory) - Memory server configuration commands.

- [agentengine migrate](https://www.mongodb.com/docs/agentengine/cli/agentengine_migrate.md#std-label-agentengine_migrate) - Migration tooling for agent configuration and SDK surfaces.

- [agentengine organization](https://www.mongodb.com/docs/agentengine/cli/agentengine_organization.md#std-label-agentengine_organization) - List and view organizations.

- [agentengine project](https://www.mongodb.com/docs/agentengine/cli/agentengine_project.md#std-label-agentengine_project) - List and view projects.

- [agentengine secret](https://www.mongodb.com/docs/agentengine/cli/agentengine_secret.md#std-label-agentengine_secret) - Secret management commands.

- [agentengine self-update](https://www.mongodb.com/docs/agentengine/cli/agentengine_self-update.md#std-label-agentengine_self-update) - Update this binary to the latest version.

- [agentengine service-account](https://www.mongodb.com/docs/agentengine/cli/agentengine_service-account.md#std-label-agentengine_service-account) - Manage service accounts.

- [agentengine status](https://www.mongodb.com/docs/agentengine/cli/agentengine_status.md#std-label-agentengine_status) - Show the current deployed status for the workspace.

- [agentengine version](https://www.mongodb.com/docs/agentengine/cli/agentengine_version.md#std-label-agentengine_version) - Print the agentengine CLI version.

- [agentengine workspace](https://www.mongodb.com/docs/agentengine/cli/agentengine_workspace.md#std-label-agentengine_workspace) - Manage workspaces on Agent Engine.

## Further reading

- [Environment variables](https://www.mongodb.com/docs/agentengine/cli/environment-variables.md#std-label-environment-variables)

- [Artifact registry validation](https://www.mongodb.com/docs/agentengine/cli/artifact-registry-validate.md#std-label-artifact-registry-validate)

- [Custom artifact source (AP\_SOURCE=custom)](https://www.mongodb.com/docs/agentengine/cli/custom-artifact-source.md#std-label-custom-artifact-source)
