> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine build

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Package and build the agent image on the platform.

## Synopsis

Create a source archive from the current directory, upload it, and trigger a CodeBuild build that produces an ECR image.

The command needs a local agent directory because it uploads the source archive; --workspace-id alone does not replace it. To rebuild a release with no local source, use `agentengine build --version <version> --workspace-id <id>`. The workspace ID otherwise comes from .agentengine/state.json, written by `agentengine init`.

`--upload-build-secrets` is opt-in. It reads each agent.yaml artifact\_repositories\[].secret from the same-named environment variable, uploads it at the declared scope before the build starts, and never reads an environment variable agent.yaml does not declare. Without it, store the credential once with `agentengine secret set <NAME>`. Uploading a project-scoped secret requires PROJECT\_OWNER or ORG\_ADMIN; a workspace-scoped secret requires PROJECT\_OWNER or AGENT\_DEVELOPER.

```bash
export ARTIFACT_REPO_CORPS_PYPI_TOKEN="$(aws codeartifact get-authorization-token ...)"
agentengine build --upload-build-secrets
```

```bash
agentengine build [flags]
```

## Options

```bash
    --all                    Monorepo: build all workspaces sequentially
    --base-url string        Platform base URL
    --context string         Named context to target (see 'agentengine context list')
-h, --help                   help for build
    --json                   Output build result as JSON
    --label string           Human-readable build label (default: git branch@sha12)
    --no-wait                Return immediately after starting the build without polling
    --org-id string          Organization ID
    --project-id string      Project ID
    --release                Mark this build as a release of the version declared in agent.yaml, addressable by 'agentengine deploy --version'
    --upload-build-secrets   Optional: before building, upload each agent.yaml artifact_repositories[].secret from the same-named environment variable
-v, --verbose                Print every file added to the source archive
    --version string         Always start a new build of the release for this declared agent.yaml version, at its pinned commit and skipping archive upload (mutually exclusive with --workspace/--all)
    --workspace string       Monorepo: build a specific workspace by name (from root agent.yaml)
    --workspace-id string    Workspace ID
```

## Options inherited from parent commands

```bash
    --log-file string    override log file path
    --log-level string   file log verbosity (error|warn|info|debug) (default "info")
    --no-log             disable file logging
-q, --quiet              silence stderr below error
```

## SEE ALSO

- [agentengine](https://www.mongodb.com/docs/agentengine/cli/agentengine.md#std-label-agentengine) - Agent Engine local development CLI.

- [agentengine build cancel](https://www.mongodb.com/docs/agentengine/cli/agentengine_build_cancel.md#std-label-agentengine_build_cancel) - Cancel a running or queued build.

- [agentengine build list](https://www.mongodb.com/docs/agentengine/cli/agentengine_build_list.md#std-label-agentengine_build_list) - List builds for a workspace.

- [agentengine build logs](https://www.mongodb.com/docs/agentengine/cli/agentengine_build_logs.md#std-label-agentengine_build_logs) - Stream build logs to stdout.

- [agentengine build promote](https://www.mongodb.com/docs/agentengine/cli/agentengine_build_promote.md#std-label-agentengine_build_promote) - Promote a succeeded build into another workspace.

## Further reading

- [Artifact registry validation](https://www.mongodb.com/docs/agentengine/cli/artifact-registry-validate.md#std-label-artifact-registry-validate)
