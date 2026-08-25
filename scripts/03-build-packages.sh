#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_ROOT="$ROOT_DIR/sources"
# shellcheck disable=SC1091
source "$SOURCE_ROOT/SOURCE-PINS.env"

jobs="${WAREHOUSE_BUILD_JOBS:-2}"
work="$SOURCE_ROOT/.work"
if [[ ${WAREHOUSE_REUSE_WORK:-0} != 1 ]]; then
  rm -rf "$work"
fi
mkdir -p "$work"

prepare_repo() {
  local name="$1" bundle="$2" ref="$3" commit="$4" destination="$5"
  if [[ ! -d $destination/.git ]]; then
    echo "[$name] Erzeuge Arbeitskopie von $ref aus lokalem Bundle"
    git clone "$bundle" "$destination"
    git -C "$destination" checkout --detach "$commit"
  fi
  local actual
  actual="$(git -C "$destination" rev-parse HEAD)"
  if [[ $actual != "$commit" ]]; then
    echo "[$name] Unerwarteter Commit: $actual statt $commit" >&2
    exit 1
  fi
}

echo 'Baue Lesbian Stable labwc ohne CyLab, Tiling-Layer und Workspace-Overview'
LABWC_WORKDIR="$work/lesbian-labwc" \
  LABWC_REF="$LABWC_REF" \
  LABWC_VERSION="$LABWC_REF" \
  LABWC_PACKAGE_REVISION="$LABWC_PACKAGE_REVISION" \
  LESBIAN_BUILD_JOBS="$jobs" \
  "$SOURCE_ROOT/scripts/build-lesbian-labwc-deb.sh"

echo 'Verpacke das verifizierte rmpc-Upstream-Binary'
"$SOURCE_ROOT/scripts/build-rmpc-deb.sh"

echo
echo 'Gebaut:'
find "$SOURCE_ROOT/build" -maxdepth 2 -type f -name '*.deb' -print -exec sha256sum {} \;
