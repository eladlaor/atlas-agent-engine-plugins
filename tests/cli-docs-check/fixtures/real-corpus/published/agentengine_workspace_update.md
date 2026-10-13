> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine workspace update

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Update an existing workspace.

```bash
agentengine workspace update <workspace-id> [flags]
```

## Options

```bash
    --agent-card-capabilities strings   Agent card capabilities (comma-separated)
    --agent-card-summary string         Agent card summary
    --base-url string                   Platform base URL
    --context string                    Named context to target (see 'agentengine context list')
    --description string                Workspace description
    --framework string                  Agent framework
    --gitops-branch string              GitOps branch
    --gitops-connection-ref string      GitOps connection reference
    --gitops-manifest-path string       GitOps manifest path
    --gitops-provider string            GitOps provider
    --gitops-repo-url string            GitOps repository URL
    --guardrails                        Enable guardrails
-h, --help                              help for update
    --json                              Output JSON
    --memory                            Enable memory
    --name string                       Workspace display name
    --org-id string                     Organization ID
    --playground                        Enable playground UI
    --project-id string                 Project ID
    --use-custom-parser                 Emit only the agent's custom output-parser events on the invoke stream
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

- [agentengine workspace](https://www.mongodb.com/docs/agentengine/cli/agentengine_workspace.md#std-label-agentengine_workspace) - Manage workspaces on Agent Engine.
