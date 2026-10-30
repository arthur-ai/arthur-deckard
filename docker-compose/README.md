# Running Deckard with Docker Compose

```bash
./scan-local.sh
docker compose up -d --wait
```

On Windows, scan with `powershell -NoProfile -ExecutionPolicy Bypass -File .\scan-local.ps1`
instead ([On Windows](#on-windows)).

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
  to start; Deckard waits for both to be set up, and `--wait` waits for all of it.

## Scanning this machine

`scan-local.sh` runs Arthur's
[endpoint collector](https://github.com/arthur-ai/arthur-engine/tree/main/integrations/endpoint-ai-discovery),
which uses osquery to list the coding agents, desktop assistants, AI browsers and
extensions installed on this machine. It writes two files to `local-scan/`, which Compose
mounts into Deckard:

| File | Holds |
|---|---|
| `inventory.json` | what the collector found |
| `machine.json` | which machine it was: its hardware UUID on macOS, `/etc/machine-id` on Linux, or `MachineGuid` on Windows, plus its hostname and OS version |

- It needs [osquery](https://osquery.io/downloads) and runs on macOS and Linux.
- It doesn't need root. Run as you, it sees what you can read, which on a laptop is where
  these tools install.
- It downloads the collector pinned to one arthur-engine commit, and won't run it if the
  download doesn't match the pinned hash.
- Deckard re-reads `local-scan/` every interval (1 hour in the shipped config), but the
  folder only changes when you scan again. A scan more than 7 days old is not published.

### On Windows

`scan-local.ps1` does the same from PowerShell. Arthur's collector doesn't run on Windows,
so it runs [ai-detection-spec](https://github.com/arthur-ai/ai-detection-spec)'s Windows
query through osquery itself, pinned and checked the same way, and writes the same two
files:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scan-local.ps1
```

- It needs [osquery](https://osquery.io/downloads) 5.17.0 or later: the Windows installer
  (`.msi`). The installer also starts osquery's own background service, `osqueryd`, which
  Deckard doesn't use; `Stop-Service osqueryd; Set-Service osqueryd -StartupType Disabled`
  from an administrator PowerShell turns it off.
- It doesn't need an administrator. Run as you, it sees what you can read. Windows lists
  the apps a user installed for themselves only while that user is signed in, so it finds
  yours, not those of other people on the machine who are signed out.
- `-ExecutionPolicy Bypass` lets Windows run this one script file this once, since by
  default it runs none. Nothing is changed for other scripts.
- If you downloaded the repository as a ZIP rather than cloning it, Windows marks the file
  as downloaded; run `Unblock-File .\scan-local.ps1` first.
- A machine whose IT allows signed scripts only (an `AllSigned` execution policy set by
  Group Policy) won't run it, and `-ExecutionPolicy Bypass` can't override that. Where
  AppLocker or Windows Defender Application Control restricts unsigned scripts to
  PowerShell's ConstrainedLanguage mode, it runs unchanged: it uses only what that mode
  allows.

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
| `… machine.json does not exist` | Run `./scan-local.sh` (`scan-local.ps1` on Windows). Deckard reads its output; it can't scan the host itself |
| a scan too old to publish | Run `./scan-local.sh` (`scan-local.ps1` on Windows) again |
| nothing in Discover at all | `docker compose logs deckard`: a config Deckard can't use stops it at startup, naming the problem, and a destination that refuses events is logged there too |
| `docker compose up` fails at `elastic-setup` | `docker compose logs elastic-setup` says why |

`scan-local.sh` says so if osquery is missing, and prints the collector's own output if the
scan fails. `scan-local.ps1` does the same with osquery's output, and also says if osquery
is older than the Windows query needs.

## Notes

- Deckard runs as UID `65532`, which must be able to read `discovery.yaml` and everything in
  `secrets/` and `local-scan/`. `scan-local.sh` sets that for its own files. For `secrets/`
  on Linux, `chmod` or `chown` accordingly, and keep it unreadable to anyone else.
- The image is built for `linux/amd64` and `linux/arm64`, so it runs natively on Apple
  Silicon and Intel alike. Deckard 0.1.0 was amd64 only; Docker Desktop runs it under
  emulation.
- This checkout runs the `arthurplatform/deckard` image of its own version. Set
  `DECKARD_VERSION` in `.env` to run a different
  [release](https://github.com/arthur-ai/arthur-deckard/releases), and `ELASTIC_VERSION` to
  run another Elasticsearch and Kibana.
- `stop_grace_period` is 30s so running scans get Deckard's 15-second drain before the
  container is killed.
