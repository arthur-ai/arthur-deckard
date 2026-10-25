# Running Deckard with Docker Compose

```bash
cp discovery.example.yaml discovery.yaml
cp .env.template .env
mkdir -p secrets
docker compose up -d
docker compose logs -f webhook-receiver
```

1. Edit the sources in `discovery.yaml`. The example is commented, and the
   [configuration reference](https://github.com/arthur-ai/arthur-engine/blob/main/ml-engine/docs/standalone-discovery.md)
   documents every key.
2. Put the secrets it references:
   - values it references as `${NAME}` go in `.env`;
   - files it references as `{file: secrets/...}` go in `secrets/`, e.g. a GCP service
     account key at `secrets/gcp-key.json`.
3. Start it, and watch the receiver's log. Each agent found is printed with its full record:

   ```text
   AGENT  personal-assistant  (vertex-prod/agent-engines)
   {
     "external_id": "projects/123456789012/locations/us-central1/reasoningEngines/111…",
     "name": "personal-assistant",
     ...
   }
   SCAN   vertex-prod/agent-engines: ok, 1 agent sent
   ```

   A scan that fails says why, e.g. `FAILED (authentication_failed)`.

`discovery.yaml`, `.env` and `secrets/` are gitignored.

## Sending to your SIEM

The example config sends events to `webhook-receiver`, a small service in this Compose file
that prints them. To send them to Splunk HEC or your own HTTPS endpoint, replace the config's
`destination` with one of the commented examples beneath it, put its token in `.env`, and
`docker compose up -d` again. The receiver keeps running but gets nothing; remove it from
`docker-compose.yaml` if you like.

## Notes

- Deckard runs as UID `65532`, which must be able to read `discovery.yaml` and everything in
  `secrets/`. On Linux, `chmod` or `chown` them accordingly, and keep them unreadable to
  anyone else.
- A config Deckard cannot use stops it at startup with a message naming the problem:
  `docker compose logs deckard`.
- The image is built for `linux/amd64`. On Apple Silicon, Docker runs it under emulation.
- Set `DECKARD_VERSION` in `.env` to pin an image version instead of tracking `latest`.
- `stop_grace_period` is 30s so running scans get Deckard's 15-second drain before the
  container is killed.
