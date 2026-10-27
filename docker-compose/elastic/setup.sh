#!/bin/sh
# Sets up the Elasticsearch and Kibana beside Deckard. Compose runs it twice:
#
#   setup.sh elasticsearch   the user Deckard writes as, and Kibana's own password
#   setup.sh kibana          the data view Discover opens Deckard's events in
#
# Every call creates or replaces, so it is safe to run on every `docker compose up`.
set -eu

ES=http://elasticsearch:9200
KIBANA=http://kibana:5601
# What Deckard writes to: the default index of its elasticsearch destination.
INDEX_PATTERN="logs-arthur.discovery-*"

# Sends a request as the elastic superuser, and stops the setup if it is refused.
call() {
  method=$1 url=$2 body=$3
  shift 3
  curl -sS --fail-with-body -u "elastic:$ELASTIC_PASSWORD" -X "$method" "$url" \
    -H 'Content-Type: application/json' "$@" -d "$body" -o /dev/null
}

elasticsearch() {
  # ELASTIC_PASSWORD is elastic's until someone changes it in Kibana or the API, which
  # Elasticsearch then keeps instead.
  status=$(curl -s -o /dev/null -w '%{http_code}' -u "elastic:$ELASTIC_PASSWORD" "$ES/_security/_authenticate")
  if [ "$status" = 401 ]; then
    echo "Elasticsearch refused ELASTIC_PASSWORD for user elastic. If you changed elastic's" >&2
    echo "password, set ELASTIC_PASSWORD in .env to it, or start over: docker compose down -v" >&2
    exit 1
  fi

  call POST "$ES/_security/user/kibana_system/_password" \
    "{\"password\": \"$ELASTIC_PASSWORD\"}"
  # Only what the destination needs: add documents, and create the data stream the
  # first write goes to.
  call PUT "$ES/_security/role/deckard_writer" \
    "{\"indices\": [{\"names\": [\"$INDEX_PATTERN\"], \"privileges\": [\"create_doc\", \"auto_configure\"]}]}"
  call PUT "$ES/_security/user/deckard" \
    "{\"password\": \"$ELASTIC_PASSWORD\", \"roles\": [\"deckard_writer\"]}"
  echo "Elasticsearch is ready for Deckard"
}

kibana() {
  call POST "$KIBANA/api/data_views/data_view" \
    "{\"override\": true, \"data_view\": {\"id\": \"deckard\", \"name\": \"Deckard\", \"title\": \"$INDEX_PATTERN\", \"timeFieldName\": \"@timestamp\"}}" \
    -H 'kbn-xsrf: true'
  # So Discover opens on Deckard's events.
  call POST "$KIBANA/api/data_views/default" \
    '{"data_view_id": "deckard", "force": true}' \
    -H 'kbn-xsrf: true'
  echo "Kibana is ready: http://localhost:5601/app/discover (user elastic)"
}

"$1"
