> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine auth login

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Authenticate with Agent Engine using browser OIDC or username/password.

## Synopsis

Authenticate and store local auth state. Browser OIDC is the default; --username selects username/password login, and --from-refresh-token exchanges AGENTENGINE\_REFRESH\_TOKEN.

\--password and --password-stdin require --username. --from-refresh-token cannot be combined with --username, --password, or --password-stdin.

```bash
agentengine auth login [flags]
```

## Examples

```bash
agentengine auth login
secret-manager read AGENTENGINE_PASSWORD | agentengine auth login --username user@example.com --password-stdin
```

## Options

```bash
    --base-url string      Agent Engine API base URL (default "https://agentengine.mongodb.com")
    --callback-port int    Pin the local login callback port so an SSH tunnel can be reused across logins (default: random; AGENTENGINE_LOGIN_CALLBACK_PORT also sets this)
    --from-refresh-token   Exchange AGENTENGINE_REFRESH_TOKEN for a fresh login session without browser SSO
-h, --help                 help for login
    --json                 Output login result as JSON
    --no-browser           Print the login URL without attempting to open a browser
    --password-stdin       Read the password from stdin (piped or redirected); requires --username
    --timeout duration     Maximum time to wait for browser authentication (default 2m0s)
    --username string      Username for credential-based authentication
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

- [agentengine auth](https://www.mongodb.com/docs/agentengine/cli/agentengine_auth.md#std-label-agentengine_auth) - Authentication commands.
