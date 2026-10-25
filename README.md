# Arthur Deckard

[![CI](https://github.com/arthur-ai/arthur-deckard/actions/workflows/ci.yaml/badge.svg)](https://github.com/arthur-ai/arthur-deckard/actions/workflows/ci.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Find the rogue AI agents running across your organization, and flag them in your SIEM.**

Deckard scans the systems you already run (cloud AI platforms, endpoints, network logs and
your SIEM) for AI agents, and sends every one it finds to Splunk or any webhook. It's
headless, read-only, and runs entirely in your environment.

## Quickstart

Find the AI agents on your own machine in a couple of minutes, with no accounts or
credentials. You need Docker and [osquery](https://osquery.io/downloads)
(`brew install --cask osquery` on a Mac).

```bash
git clone https://github.com/arthur-ai/arthur-deckard.git
cd arthur-deckard/docker-compose
./scan-local.sh
docker compose up -d
docker compose logs -f webhook-receiver
```

`scan-local.sh` lists what's installed on this machine using the osquery queries from
[ai-detection-spec](https://github.com/arthur-ai/ai-detection-spec), our open format and
catalog for finding AI agents on a machine. It changes nothing and doesn't need root.
Deckard matches what it finds against that catalog and sends each agent to a small receiver
that prints them:

```text
AGENT  Claude Code  (this-machine/inventory)
{
  "external_id": "3F2504E0-4F89-11D3-9A0C-0305E82C3301:claude-code",
  "name": "Claude Code",
  "runs_on": "endpoint",
  "creation_source": {
    "observations": {
      "install_path": "/Users/you/.local/bin/claude",
      "classification": "Coding agent",
      ...
AGENT  Cursor  (this-machine/inventory)
...
SCAN   this-machine/inventory: ok, 7 agents sent
```

Next, add your cloud, MDM or SIEM sources to
[`docker-compose/discovery.yaml`](docker-compose/discovery.yaml) (it has commented
examples), and point its `destination` at Splunk or your own webhook. See
[`docker-compose/`](docker-compose/README.md) for more.

## Deploy on Kubernetes

```bash
helm install deckard ./charts/deckard \
  --namespace deckard --create-namespace \
  --set-file config=discovery.yaml \
  --set secretEnv.SPLUNK_HEC_TOKEN="$SPLUNK_HEC_TOKEN"
```

See the [chart's README](charts/deckard/README.md) for managing secrets and using cloud
workload identity.

## Integrations

| Class | Sources |
|---|---|
| Cloud AI platforms | Vertex AI Agent Engine, AWS Bedrock and AgentCore |
| Endpoints and servers | Jamf Pro, Google Compute Engine, AWS EC2, this machine (`scan-local.sh`) |
| Network and gateway logs | AWS CloudWatch Logs, Google Cloud Logging |
| Security telemetry | Splunk Enterprise, Elastic Security |

**Destinations:** Splunk HTTP Event Collector, or any HTTPS webhook.

Missing one you use? [Open an issue](https://github.com/arthur-ai/arthur-deckard/issues).

## Documentation

- [How Deckard works](docs/how-it-works.md): discovery classes, sources and scans
- [Events and alerting](docs/events.md): what your SIEM receives and what to alert on
- [Configuration reference](https://github.com/arthur-ai/arthur-engine/blob/main/ml-engine/docs/standalone-discovery.md):
  every source's fields and permissions, destination options, scheduling

## Contributing

Deckard is the standalone discovery mode of the
[Arthur Engine](https://github.com/arthur-ai/arthur-engine), where its code lives. This
repository holds its deployment and docs. Bug reports and integration requests are welcome
in [issues](https://github.com/arthur-ai/arthur-deckard/issues); report security issues
privately, as described in [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
