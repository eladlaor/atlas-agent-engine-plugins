## agentengine service-account get

Show service account details.

### Synopsis

Show the metadata for one service account.

A read never returns the secret; rotate the account to issue a new one.

```
agentengine service-account get <client-id> [flags]
```

### Options

```
      --base-url string     Platform base URL
      --context string      Named context to target (see 'agentengine context list')
  -h, --help                help for get
      --json                Output the service account as JSON
      --org-id string       Organization scope for the service account
      --project-id string   Project scope for the service account
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

* [agentengine service-account](agentengine_service-account.md)	 - Manage service accounts.

