> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine atlas setup

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Check Atlas setup for the current workspace.

## Synopsis

Show the workspace’s current Atlas link state and guide connecting Atlas resources with a service account.

\--yes runs a non-interactive path: it creates the Atlas deployment resources with defaults and uploads the generated secrets without displaying them. Under delegated setup, --yes also authorizes billed cluster creation and the required project-wide Atlas IP access-list changes.

When the Agent Engine project already holds MONGODB\_URI or VOYAGE\_API\_KEY and the local Atlas metadata names no matching resource, delegated setup asks whether to keep each one. --yes keeps them; --force replaces them.

When the local Atlas metadata names a database user or Voyage API key whose platform secret is missing, delegated setup rotates the user’s password or offers a replacement Voyage API key. --yes does both without prompting.

When this workspace has memory off (features.memory is false or absent in agent.yaml), setup skips Voyage API key creation and upload. An existing project VOYAGE\_API\_KEY is left unchanged.

Free and shared-tier Atlas clusters (M0, M2, M5) are not supported for agent deploys: they pause automatically after inactivity, which drops them from platform egress sync, and they cap Atlas Search indexes. The cluster picker hides them and names the ones it hides. Setup and atlas cluster save refuse one, including a saved cluster or one that already holds the cluster name. Use a Flex or dedicated (M10+) cluster.

```bash
agentengine atlas setup [flags]
```

## Options

```bash
    --base-url string       Platform base URL
    --context string        Named context to target (see 'agentengine context list')
    --env string            Atlas environment to use (for example, cloud-dev)
    --force                 Reset the local Atlas link and rerun setup. The platform Atlas link is unchanged until setup completes
-h, --help                  help for setup
    --org-id string         Organization ID
    --profile string        Atlas service account profile to use
    --project-id string     Project ID
    --workspace string      Monorepo: set up Atlas for a specific workspace by name
    --workspace-id string   Workspace ID
-y, --yes                   Accept defaults, upload generated secrets without displaying them, and authorize billed cluster creation and Atlas IP access changes without prompts
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

- [agentengine atlas](https://www.mongodb.com/docs/agentengine/cli/agentengine_atlas.md#std-label-agentengine_atlas) - Atlas workspace setup commands.

- [agentengine atlas setup finalize](https://www.mongodb.com/docs/agentengine/cli/agentengine_atlas_setup_finalize.md#std-label-agentengine_atlas_setup_finalize) - Finalize saved Atlas setup selections for deployment.
