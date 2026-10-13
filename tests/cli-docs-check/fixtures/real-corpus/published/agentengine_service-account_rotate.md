> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine service-account rotate

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Issue a new secret for a service account.

## Synopsis

Issue a new client secret for a service account.

The new secret is shown only once. The previous secret keeps authenticating for up to 7 days, or until it expires if sooner; rotating again ends its grace period immediately.

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

```bash
agentengine service-account rotate <client-id> [flags]
```

## Options

```bash
    --base-url string              Platform base URL
    --context string               Named context to target (see 'agentengine context list')
-h, --help                         help for rotate
    --json                         Output the rotated service account as JSON
    --org-id string                Organization scope for the service account
    --project-id string            Project scope for the service account
    --secret-expires-in duration   Secret lifetime as a whole number of hours, e.g. 720h (default: server default of 2160h)
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

- [agentengine service-account](https://www.mongodb.com/docs/agentengine/cli/agentengine_service-account.md#std-label-agentengine_service-account) - Manage service accounts.
