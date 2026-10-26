# Running Deckard with Docker Compose

```bash
./scan-local.sh
docker compose up -d
docker compose logs -f webhook-receiver
```

That's the whole setup: [`discovery.yaml`](discovery.yaml) works as shipped. It scans this
machine and sends what it finds to `webhook-receiver`, a small service in this Compose file
that prints every event.

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
(Splunk HEC or your own HTTPS endpoint), put its token in `.env`, and
`docker compose up -d` again. The receiver keeps running but gets nothing; remove it from
`docker-compose.yaml` if you like.

## Troubleshooting

The receiver prints one line per scan, and a failed one says why:

| The receiver says | Do this |
|---|---|
| `… machine.json does not exist` | Run `./scan-local.sh`. Deckard reads its output; it can't scan the host itself |
| a scan too old to publish | Run `./scan-local.sh` again |
| nothing at all | `docker compose logs deckard`: a config Deckard can't use stops it at startup, naming the problem |

`scan-local.sh` says so if osquery is missing, and prints the collector's own output if the
scan fails.

## Notes

- Deckard runs as UID `65532`, which must be able to read `discovery.yaml` and everything in
  `secrets/` and `local-scan/`. `scan-local.sh` sets that for its own files. For `secrets/`
  on Linux, `chmod` or `chown` accordingly, and keep it unreadable to anyone else.
- The image is built for `linux/amd64`. On Apple Silicon, Docker runs it under emulation.
- This checkout runs the `arthurplatform/deckard` image of its own version. Set
  `DECKARD_VERSION` in `.env` to run a different
  [release](https://github.com/arthur-ai/arthur-deckard/releases).
- `stop_grace_period` is 30s so running scans get Deckard's 15-second drain before the
  container is killed.
