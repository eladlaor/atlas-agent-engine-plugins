## agentengine service-account list

List service accounts.

### Synopsis

List the service accounts in an organization or project.

Every page is fetched, so the output is the whole inventory; --limit caps the
result.

An organization listing covers only organization-scoped accounts. Accounts
scoped to projects inside that organization are listed per project.

```
agentengine service-account list [flags]
```

### Options

```
      --base-url string     Platform base URL
      --context string      Named context to target (see 'agentengine context list')
  -h, --help                help for list
      --json                Output service accounts as JSON
      --limit int           Maximum accounts to return (0 = all)
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

