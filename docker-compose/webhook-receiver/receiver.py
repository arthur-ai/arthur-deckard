"""A webhook destination for trying Deckard out: prints every event it receives.

Deckard POSTs a JSON array of events. Each discovered agent is printed with its full
record, and each scan outcome as one line. Standard library only, so it runs on a stock
Python image.
"""

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def describe(event: dict) -> str:
    source = event.get("source", {})
    where = f"{source.get('name')}/{source.get('config_name')}"
    if event.get("event_type") == "arthur.discovery.agent":
        agent = event.get("agent", {})
        return (
            f"AGENT  {agent.get('name')}  ({where})\n"
            + json.dumps(agent, indent=2)
        )
    if event.get("event_type") == "arthur.discovery.scan_outcome":
        outcome = event.get("outcome", {})
        if outcome.get("succeeded"):
            sent = outcome.get("records_published", 0)
            return f"SCAN   {where}: ok, {sent} agent{'' if sent == 1 else 's'} sent"
        return f"SCAN   {where}: FAILED ({outcome.get('error_code')}) {outcome.get('error')}"
    return json.dumps(event, indent=2)


class Handler(BaseHTTPRequestHandler):
    def do_POST(self) -> None:
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        try:
            events = json.loads(body)
        except ValueError:
            print(f"Received a body that is not JSON: {body[:200]!r}", flush=True)
            self.send_response(400)
            self.end_headers()
            return
        for event in events if isinstance(events, list) else [events]:
            print(describe(event), flush=True)
        self.send_response(200)
        self.end_headers()

    def log_message(self, format: str, *args: object) -> None:
        # The events are the output; skip the per-request access log.
        pass


if __name__ == "__main__":
    print("Waiting for events from Deckard on :8080", flush=True)
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
