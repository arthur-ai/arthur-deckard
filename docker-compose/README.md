# Running Deckard with Docker Compose

```bash
cp discovery.example.yaml discovery.yaml
cp .env.template .env
mkdir -p secrets
docker compose up
```

1. Edit `discovery.yaml`: your sources and your destination. The example is commented, and
   the [configuration reference](https://github.com/arthur-ai/arthur-engine/blob/main/ml-engine/docs/standalone-discovery.md)
   documents every key.
2. Put the secrets it references:
   - values it references as `${NAME}` go in `.env`;
   - files it references as `{file: secrets/...}` go in `secrets/`, e.g. a GCP service
     account key at `secrets/gcp-key.json`.
3. Start it. Each scan logs `Starting discovery scan of '<source>/<config>'`, then a
   `discovery_scan_outcome` line saying how many agents it sent.

`discovery.yaml`, `.env` and `secrets/` are gitignored.

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
