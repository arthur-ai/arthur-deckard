# Events and alerting

Deckard sends two kinds of event to its destination: one per agent found, and one per scan.

## Discovered agents

One event per agent per scan:

```json
{
  "event_type": "arthur.discovery.agent",
  "schema_version": 1,
  "observed_at": "2026-10-07T18:00:00.123456+00:00",
  "source": {"id": "6b0f…", "name": "vertex-prod", "vendor": "gcp_vertex", "config_name": "agent-engines"},
  "agent": {
    "external_id": "projects/123456789012/locations/us-central1/reasoningEngines/111…",
    "name": "personal-assistant",
    "last_seen": "2026-10-07T17:58:12+00:00"
  }
}
```

Each agent records which source found it, where it runs, and when it was last seen, so you
can follow up with the team that owns it. `agent` also carries whatever else the source
reported, such as the models it calls and the tools it uses.

Every scan sends what the source reports now, so the same agents arrive each time. Dedupe on
`agent.external_id` and `source.id`.

## Scan outcomes

With `emit_scan_outcomes: true`, each scan also sends one `arthur.discovery.scan_outcome`
event saying whether it succeeded, how many agents it sent, and why it failed if it did.

## What to alert on

- **A new `agent.external_id`**: an agent nobody has seen before.
- **`outcome.succeeded: false`**: a source Deckard can no longer read. `error_code` says why
  (`authentication_failed`, `permission_denied`, …).
- **A non-empty `outcome.denied_scopes`**: a cloud project or account inside the scope that
  the scan was refused, so its agents are invisible.
- **`outcome.device_coverage.unreadable_devices`**: machines the scan could not read, such as
  ones the endpoint collector has never reported from. A machine Deckard cannot see is where
  unmanaged AI sits.

The [configuration reference](https://github.com/arthur-ai/arthur-engine/blob/main/ml-engine/docs/standalone-discovery.md#what-the-destination-receives)
documents every field.
