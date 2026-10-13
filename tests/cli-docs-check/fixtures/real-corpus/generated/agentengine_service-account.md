## agentengine service-account

Manage service accounts.

### Synopsis

Manage service accounts, the programmatic identities that call the platform.

A service account is scoped to an organization or a project and is identified
by a client ID and secret.

Exchange the client ID and secret for a 1-hour access token at
POST /api/v1/oauth/token. Send that token only to endpoints explicitly
enabled for service-account authentication and that the assigned role allows:

  curl --fail-with-body --silent --show-error \
    --user '<client-id>' \
    --data grant_type=client_credentials \
    '<base-url>/api/v1/oauth/token' | \
  jq -er '"Authorization: Bearer " + .access_token' | \
  curl --fail-with-body --silent --show-error \
    --header @- \
    '<base-url>/api/v1/<service-account-enabled-resource>'

The create and rotate commands print safe curl examples for both steps.

### Options

```
  -h, --help   help for service-account
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

* [agentengine](agentengine.md)	 - Agent Engine local development CLI.
* [agentengine service-account create](agentengine_service-account_create.md)	 - Create a service account.
* [agentengine service-account delete](agentengine_service-account_delete.md)	 - Deactivate a service account.
* [agentengine service-account get](agentengine_service-account_get.md)	 - Show service account details.
* [agentengine service-account list](agentengine_service-account_list.md)	 - List service accounts.
* [agentengine service-account rotate](agentengine_service-account_rotate.md)	 - Issue a new secret for a service account.

