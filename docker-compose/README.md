# Running Deckard with Docker Compose

```bash
./scan-local.sh
docker compose up -d --wait
```

Then open [Kibana](http://localhost:5601/app/discover) and log in as `elastic`, password
`changeme`.

That's the whole setup: [`discovery.yaml`](discovery.yaml) works as shipped. It scans this
machine and sends what it finds to Elasticsearch, which runs in this Compose file with
Kibana beside it. Kibana's Discover opens on Deckard's events: one per agent found, and one
per scan saying how it went. Both are described in [Events and alerting](../docs/events.md).

To see the agents from the terminal instead:

```bash
curl -s -u elastic:changeme 'localhost:9200/_query?format=txt' \
  -H 'Content-Type: application/json' \
  -d '{"query": "FROM logs-arthur.discovery-* | WHERE event_type == \"arthur.discovery.agent\" | KEEP @timestamp, agent.name, source.name | SORT @timestamp DESC"}'
```

## What runs

| Service | Does |
|---|---|
| `deckard` | Scans on the schedule in `discovery.yaml` |
| `elasticsearch` | Stores the events, at `localhost:9200`, in the `logs-arthur.discovery-default` data stream |
| `kibana` | Browses them, at `localhost:5601` |
| `elastic-setup` | Runs once: creates the `deckard` user Deckard sends as, which can only add documents to `logs-arthur.discovery-*`, and sets Kibana's own password |
| `kibana-setup` | Runs once: creates the `Deckard` data view Discover opens on |

- Both ports listen on this machine only. Deckard reaches Elasticsearch over Compose's
  private network, in plain HTTP.
- One password, `ELASTIC_PASSWORD` in `.env` (`changeme` if unset), is used for `elastic`,
  for Kibana's user and for `deckard`. Set your own and `docker compose up -d` again.
- The events are kept in the `elasticsearch-data` volume. `docker compose down -v` deletes
  them.
- Elasticsearch and Kibana take about 3.5 GB of memory between them, and a minute or so
  to start; Deckard waits for Elasticsearch, and `--wait` waits for all of it.

## Scanning this machine

`scan-local.sh` runs Arthur's
[endpoint collector](https://github.com/arthur-ai/arthur-engine/tree/main/integrations/endpoint-ai-discovery),
which uses osquery to list the coding agents, desktop assistants, AI browsers and
extensions installed on this machine. It writes two files to `local-scan/`, which Compose
mounts into Deckard:

| File | Holds |
|---|---|
| `inventory.json` | what the collector found |
| `machine.json` | which machine it was: its hardware UUID on macOS, or `/etc/machine-id` on Linux, plus its hostname and OS version |

- It needs [osquery](https://osquery.io/downloads) and runs on macOS and Linux.
- It doesn't need root. Run as you, it sees what you can read, which on a laptop is where
  these tools install.
- It downloads the collector pinned to one arthur-engine commit, and won't run it if the
  download doesn't match the pinned hash.
- Deckard re-reads `local-scan/` every interval (1 hour in the shipped config), but the
  folder only changes when you run `./scan-local.sh` again. A scan more than 7 days old
  is not published.

## Adding sources

Uncomment or add sources in `discovery.yaml`. Each one is documented in the
[configuration reference](https://github.com/arthur-ai/arthur-engine/blob/main/ml-engine/docs/standalone-discovery.md).
Keep their credentials out of the file:

- values it references as `${NAME}` go in `.env` (start from `.env.template`);
- files it references as `{file: secrets/...}` go in `secrets/`, e.g. a GCP service
  account key at `secrets/gcp-key.json`.

`.env`, `secrets/` and `local-scan/` are gitignored. Then `docker compose up -d` again.

## Sending to your SIEM

Replace the `destination` in `discovery.yaml` with one of the commented examples beneath it
(your own Elasticsearch or Elastic Security, Splunk HEC, or your own HTTPS endpoint), put
its credential in `.env`, and `docker compose up -d` again. The Elasticsearch and Kibana
here keep running but get nothing new; remove them from `docker-compose.yaml` if you like,
along with Deckard's `depends_on`.

## Troubleshooting

Each scan sends an outcome event, which Discover finds with `outcome.succeeded : false`
when one fails, saying why in `outcome.error`. Deckard logs the same outcome:
`docker compose logs deckard`.

| The outcome says | Do this |
|---|---|
| `… machine.json does not exist` | Run `./scan-local.sh`. Deckard reads its output; it can't scan the host itself |
| a scan too old to publish | Run `./scan-local.sh` again |
| nothing in Discover at all | `docker compose logs deckard`: a config Deckard can't use stops it at startup, naming the problem, and a destination that refuses events is logged there too |
| `docker compose up` fails at `elastic-setup` | `docker compose logs elastic-setup` says why |

`scan-local.sh` says so if osquery is missing, and prints the collector's own output if the
scan fails.

## Notes

- Deckard runs as UID `65532`, which must be able to read `discovery.yaml` and everything in
  `secrets/` and `local-scan/`. `scan-local.sh` sets that for its own files. For `secrets/`
  on Linux, `chmod` or `chown` accordingly, and keep it unreadable to anyone else.
- The image is built for `linux/amd64`. On Apple Silicon, Docker runs it under emulation.
- Set `DECKARD_VERSION` in `.env` to pin an image version instead of tracking `latest-dev`,
  the engine's newest dev build, and `ELASTIC_VERSION` to run another Elasticsearch and
  Kibana.
- `stop_grace_period` is 30s so running scans get Deckard's 15-second drain before the
  container is killed.
