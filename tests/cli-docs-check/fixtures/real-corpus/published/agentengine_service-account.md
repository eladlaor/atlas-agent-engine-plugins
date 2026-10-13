> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine service-account

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Manage service accounts.

## Synopsis

Manage service accounts, the programmatic identities that call the platform.

A service account is scoped to an organization or a project and is identified by a client ID and secret.

Exchange the client ID and secret for a 1-hour access token at POST /api/v1/oauth/token. Send that token only to endpoints explicitly enabled for service-account authentication and that the assigned role allows:

```bash
curl --fail-with-body --silent --show-error \
  --user '<client-id>' \
  --data grant_type=client_credentials \
  '<base-url>/api/v1/oauth/token' | \
jq -er '"Authorization: Bearer " + .access_token' | \
curl --fail-with-body --silent --show-error \
  --header @- \
  '<base-url>/api/v1/<service-account-enabled-resource>'
```

The create and rotate commands print safe curl examples for both steps.

## Options

```bash
-h, --help   help for service-account
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

- [agentengine](https://www.mongodb.com/docs/agentengine/cli/agentengine.md#std-label-agentengine) - Agent Engine local development CLI.

- [agentengine service-account create](https://www.mongodb.com/docs/agentengine/cli/agentengine_service-account_create.md#std-label-agentengine_service-account_create) - Create a service account.

- [agentengine service-account delete](https://www.mongodb.com/docs/agentengine/cli/agentengine_service-account_delete.md#std-label-agentengine_service-account_delete) - Deactivate a service account.

- [agentengine service-account get](https://www.mongodb.com/docs/agentengine/cli/agentengine_service-account_get.md#std-label-agentengine_service-account_get) - Show service account details.

- [agentengine service-account list](https://www.mongodb.com/docs/agentengine/cli/agentengine_service-account_list.md#std-label-agentengine_service-account_list) - List service accounts.

- [agentengine service-account rotate](https://www.mongodb.com/docs/agentengine/cli/agentengine_service-account_rotate.md#std-label-agentengine_service-account_rotate) - Issue a new secret for a service account.
