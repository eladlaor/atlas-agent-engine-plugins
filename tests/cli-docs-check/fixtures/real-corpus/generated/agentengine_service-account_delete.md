## agentengine service-account delete

Deactivate a service account.

### Synopsis

Deactivate a service account.

Deactivation takes effect on the next request: existing access tokens are
rejected and the credential can no longer mint new ones. No command reactivates
an account; create a replacement instead.

```
agentengine service-account delete <client-id> [flags]
```

### Options

```
      --base-url string     Platform base URL
      --context string      Named context to target (see 'agentengine context list')
  -h, --help                help for delete
      --json                Output the delete result as JSON
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

