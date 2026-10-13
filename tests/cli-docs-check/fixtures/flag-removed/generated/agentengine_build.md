## agentengine build

Package and build the agent image on the platform.

### Synopsis

Create a source archive from the current directory, upload it, and trigger
a CodeBuild build that produces an ECR image.

The command needs a local agent directory because it uploads the source archive;
--workspace-id alone does not replace it. To rebuild a release with no local
source, use 'agentengine build --version <version> --workspace-id <id>'. The
workspace ID otherwise comes from .agentengine/state.json, written by
'agentengine init'.

--upload-build-secrets is opt-in. It reads each agent.yaml
artifact_repositories[].secret from the same-named environment variable,
uploads it at the declared scope before the build starts, and never reads an
environment variable agent.yaml does not declare. Without it, store the
credential once with 'agentengine secret set <NAME>'. Uploading a project-scoped
secret requires PROJECT_OWNER or ORG_ADMIN; a workspace-scoped secret requires
PROJECT_OWNER or AGENT_DEVELOPER.

  export ARTIFACT_REPO_CORPS_PYPI_TOKEN="$(aws codeartifact get-authorization-token ...)"
  agentengine build --upload-build-secrets

```
agentengine build [flags]
```

### Options

```
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

### Options inherited from parent commands

```
      --log-file string    override log file path
      --log-level string   file log verbosity (error|warn|info|debug) (default "info")
      --no-log             disable file logging
  -q, --quiet              silence stderr below error
```

### SEE ALSO

* [agentengine](agentengine.md)	 - Agent Engine local development CLI.
* [agentengine build cancel](agentengine_build_cancel.md)	 - Cancel a running or queued build.
* [agentengine build list](agentengine_build_list.md)	 - List builds for a workspace.
* [agentengine build logs](agentengine_build_logs.md)	 - Stream build logs to stdout.
* [agentengine build promote](agentengine_build_promote.md)	 - Promote a succeeded build into another workspace.

### Further reading

* [Artifact registry validation](artifact-registry-validate.md)

