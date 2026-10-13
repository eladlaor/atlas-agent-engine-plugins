> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine atlas profile save

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Save the Atlas profile and project selected for this workspace.

## Synopsis

Save the Atlas profile and project selected for this workspace.

Run without --input in an interactive terminal to configure the profile with prompts: profile name, service account client ID, masked client secret, then the Atlas organization and project to bind. Stored credentials are reused without re-prompting. With --json, prompts go to stderr and stdout stays machine-readable.

For automation, pass --json and --input (- for stdin, or a file path). Outside an interactive terminal, --json is required.

```bash
agentengine atlas profile save [flags]
```

## Options

```bash
    --base-url string       Platform base URL
    --context string        Named context to target (see 'agentengine context list')
-h, --help                  help for save
    --input string          Project binding request JSON. Prefer --input - for stdin (required on macOS and Windows). On Linux, path files must be temporary, owner-only, untracked, deleted after use, and rotated if exposed
    --json                  Output saved project binding as JSON
    --org-id string         Organization ID
    --project-id string     Project ID
    --workspace string      Monorepo: save Atlas project access for a specific workspace by name
    --workspace-id string   Workspace ID
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

- [agentengine atlas profile](https://www.mongodb.com/docs/agentengine/cli/agentengine_atlas_profile.md#std-label-agentengine_atlas_profile) - Manage Atlas service account profile selections.
