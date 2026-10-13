> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine dev login

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Log the local container tooling in to the platform image registry.

## Synopsis

Fetches a short-lived pull credential for the platform’s first-party container images from the Agent Engine API and runs `docker login` with it, so `agentengine dev up` can pull images without a GitHub or AWS account. This requires the internal image source; other sources fail.

The credential is cached, and `agentengine dev up` re-runs this flow when a platform image is missing locally and the credential is absent or expiring. Run it by hand only to troubleshoot registry auth or pull images directly.

Gateway-proxy flows are the default; AGENTENGINE\_USE\_GATEWAY\_PROXY=false pulls from the legacy GHCR location instead and disables this command.

```bash
agentengine dev login [flags]
```

## Options

```bash
-h, --help   help for login
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

- [agentengine dev](https://www.mongodb.com/docs/agentengine/cli/agentengine_dev.md#std-label-agentengine_dev) - Local dev environment commands.
