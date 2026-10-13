> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine service-account create

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Create a service account.

## Synopsis

Create a service account and issue its first client secret.

The secret is shown only once; save it immediately.

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

Project roles are PROJECT\_OWNER, PROJECT\_READ\_ONLY, or AGENT\_DEVELOPER; organization roles are ORG\_GROUP\_CREATOR or ORG\_READ\_ONLY. List and get display the stored Agent Engine role: PROJECT\_READ\_ONLY stores as PROJECT\_MEMBER, and ORG\_GROUP\_CREATOR stores as ORG\_ADMIN and pairs as Atlas Organization Project Creator. AGENT\_DEVELOPER has no Atlas equivalent; it can invoke, build, and deploy agents. Legacy names PROJECT\_MEMBER, ORG\_ADMIN, and ORG\_MEMBER are accepted and print a deprecation warning.

Examples:

```bash
agentengine service-account create ci-pipeline --role AGENT_DEVELOPER
agentengine service-account create audit-reader --org-id <org-id> --role ORG_READ_ONLY
```

```bash
agentengine service-account create <name> --role <role> [flags]
```

## Options

```bash
    --base-url string              Platform base URL
    --context string               Named context to target (see 'agentengine context list')
    --description string           Human-readable description
-h, --help                         help for create
    --ip-access-list strings       IPs or CIDRs allowed to use the credential (default: unrestricted)
    --json                         Output the created service account as JSON
    --org-id string                Organization scope for the service account
    --project-id string            Project scope for the service account
    --role string                  Role granted to the service account (project: PROJECT_OWNER, PROJECT_READ_ONLY, AGENT_DEVELOPER; organization: ORG_GROUP_CREATOR, ORG_READ_ONLY). Legacy names PROJECT_MEMBER, ORG_ADMIN, and ORG_MEMBER still work and print a deprecation warning.
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
