#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# SOURCE-PINS.env is resolved from the calculated project root.
# shellcheck disable=SC1091
source "$ROOT_DIR/sources/SOURCE-PINS.env"

version="${RMPC_REF#v}"
archive="$ROOT_DIR/sources/vendor/rmpc-${RMPC_REF}-x86_64-unknown-linux-gnu.tar.gz"
package_root="$ROOT_DIR/sources/packaging/rmpc"
build_root="$ROOT_DIR/sources/build/rmpc-deb"
output="$build_root/rmpc_${version}-${RMPC_PACKAGE_REVISION}_amd64.deb"
export SOURCE_DATE_EPOCH="$RMPC_SOURCE_DATE_EPOCH"

[[ -f $archive ]] || {
  echo "rmpc-Archiv fehlt: $archive" >&2
  exit 1
}

printf '%s  %s\n' "$RMPC_ARCHIVE_SHA256" "$archive" | sha256sum -c -

mkdir -p "$build_root"
stage="$(mktemp -d "$build_root/rmpc-package.XXXXXX")"
unpack="$(mktemp -d "$build_root/rmpc-unpack.XXXXXX")"
trap 'rm -rf "$stage" "$unpack"' EXIT

cp -a "$package_root/." "$stage/"
tar -xzf "$archive" -C "$unpack"

find "$stage" -type d -exec chmod 0755 {} +
find "$stage" -type f -exec chmod 0644 {} +

install -D -m 0755 "$unpack/rmpc" "$stage/usr/bin/rmpc"
install -D -m 0644 "$unpack/man/rmpc.1" "$stage/usr/share/man/man1/rmpc.1"
install -D -m 0644 "$unpack/completions/rmpc.bash" \
  "$stage/usr/share/bash-completion/completions/rmpc"
sed -i '0,/^rmpc$/s//rmpc \\- terminal client for Music Player Daemon/' \
  "$stage/usr/share/man/man1/rmpc.1"
gzip -9n "$stage/usr/share/man/man1/rmpc.1"
gzip -9n "$stage/usr/share/doc/rmpc/changelog.Debian"
find "$stage" -exec touch -d "@$SOURCE_DATE_EPOCH" {} +

reported_version="$("$unpack/rmpc" version 2>/dev/null | head -n1)"
grep -Fq "$version" <<<"$reported_version" || {
  echo "Unerwartete rmpc-Version: $reported_version" >&2
  exit 1
}

dpkg-deb --root-owner-group --build "$stage" "$output"
dpkg-deb --info "$output"
sha256sum "$output"
