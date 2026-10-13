> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine create

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Scaffold a new agent from a starter template.

## Synopsis

Create a local-first starter agent from a supported template, rewrite identity fields such as name and package metadata, write a personalized environment file, and print template-specific next steps.

Interactive creation offers an optional LLM smoke test after the files are written: one Hello request with a 10-second timeout. --smoke-test opts in without a prompt. A failed check leaves the project fully created and explains how to fix its configuration before running agentengine dev up; do not rerun create. Manual LLM setup, client apps, and memory-only projects skip the check.

```bash
agentengine create [flags]
```

## Examples

```bash
agentengine create
agentengine create --name "Acme Assistant" --llm anthropic --memory
```

## Options

```bash
    --dir string               Target directory (default: ./<slug>)
-h, --help                     help for create
    --json                     Output the scaffold result as JSON
    --llm string               LLM connection: openai, anthropic, gemini, openrouter, openai-compatible, anthropic-compatible, or custom (configure in code)
    --llm-auth-header string   Header field the compatible endpoint expects the API key in (default: inferred; authorization uses Bearer)
    --llm-base-url string      Compatible endpoint base URL; its host is added to network.egress
    --llm-model string         Model or deployment name (required for OpenRouter and compatible endpoints)
    --memory                   Enable memory for supported agent templates and prompt for Voyage API key
    --memory-only              Scaffold a memory-only project (project-config.yaml only, no agent template)
    --name string              Application display name
    --open-egress              Allow open outbound access for Agent and Tool (writes network.egress_mode: allow_all)
    --smoke-test               Send one Hello request to the selected LLM after creation (10s timeout)
    --template string          Starter template to use (default: insurance-agent)
    --yes                      Accept defaults for optional prompts
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
