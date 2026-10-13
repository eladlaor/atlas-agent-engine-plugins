## agentengine atlas profile verify

Verify an Atlas service account profile and list accessible projects.

```
agentengine atlas profile verify [flags]
```

### Options

```
  -h, --help           help for verify
      --input string   Service account profile JSON. Prefer --input - for stdin (required on macOS and Windows). On Linux, path files must be temporary, owner-only, untracked, deleted after use, and rotated if exposed
      --json           Output project access as JSON
```

### Options inherited from parent commands

```
      --log-file string    override log file path
      --log-level string   file log verbosity (error|warn|info|debug) (default "info")
      --no-log             disable file logging
  -q, --quiet              silence stderr below error
  -v, --verbose count      raise stderr verbosity (-v info, -vv debug)
```

### SEE ALSO

* [agentengine atlas profile](agentengine_atlas_profile.md)	 - Manage Atlas service account profile selections.

