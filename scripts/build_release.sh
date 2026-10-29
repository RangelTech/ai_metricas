#!/usr/bin/env bash
# Empacota UMA imagem de terceiros (fixada por digest em images.env) no formato de release do vps_rt_infra:
#   <servico>.image.tar.gz            docker save | gzip -9
#   release-manifest.<servico>.json   manifesto schema 1
# Uso: scripts/build_release.sh umami|umami-db <versao, ex.: v0.1.0> [sha completo do commit]
set -euo pipefail
cd "$(dirname "$0")/.."
SERVICE="${1:?servico: umami ou umami-db}"
VERSION="${2:?versao, ex.: v0.1.0}"
SHA="${3:-$(git rev-parse HEAD)}"
PY="${PYTHON:-python3}"; command -v "$PY" >/dev/null 2>&1 || PY=python
# shellcheck disable=SC1091
. ./images.env
case "$SERVICE" in
  umami)    REF="$UMAMI_REF" ;;
  umami-db) REF="$POSTGRES_REF" ;;
  *) echo "servico desconhecido: $SERVICE" >&2; exit 2 ;;
esac
TAG="$SERVICE:$VERSION"
ARCHIVE="$SERVICE.image.tar.gz"
docker pull --platform linux/amd64 "$REF"
docker tag "$REF" "$TAG"
docker save "$TAG" | gzip -9 > "$ARCHIVE"
IMAGE_ID="sha256:$(gunzip -c "$ARCHIVE" | tar -xO manifest.json | "$PY" -c "import sys,json,re;print(re.sub(r'^.*/','',json.load(sys.stdin)[0]['Config']).replace('.json',''))")"
ARCHIVE_SHA="$(sha256sum "$ARCHIVE" | cut -d' ' -f1)"
SERVICE="$SERVICE" VERSION="$VERSION" SHA="$SHA" TAG="$TAG" ARCHIVE="$ARCHIVE" IMAGE_ID="$IMAGE_ID" ARCHIVE_SHA="$ARCHIVE_SHA" "$PY" - <<'PYEOF'
import datetime, json, os
service = os.environ["SERVICE"]
spec = {
    "umami": {
        "healthcheck": {"path": "/api/heartbeat", "expect": 200, "timeout_s": 180, "port": 3000},
        "env": {"required": []},
        "resources": {"memory": "512m", "cpus": "1"},
    },
    "umami-db": {
        "healthcheck": {"path": "", "expect": 0, "timeout_s": 120, "port": 5432},
        "env": {"required": []},
        "resources": {"memory": "256m", "cpus": "0.5"},
    },
}[service]
manifest = {
    "schema": 1,
    "service": service,
    "repo": "RangelTech/ai_metricas",
    "commit": os.environ["SHA"][:7],
    "version": os.environ["VERSION"],
    "artifact": {
        "type": "docker-archive",
        "asset": os.environ["ARCHIVE"],
        "sha256": os.environ["ARCHIVE_SHA"],
        "image_id": os.environ["IMAGE_ID"],
        "tag": os.environ["TAG"],
    },
    "built_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    **spec,
}
with open(f"release-manifest.{service}.json", "w", newline="\n") as fh:
    json.dump(manifest, fh, indent=2)
    fh.write("\n")
PYEOF
cat "release-manifest.$SERVICE.json"
ls -l "$ARCHIVE"
