#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# SOURCE-PINS.env is resolved from the calculated project root.
# shellcheck disable=SC1091
source "$ROOT_DIR/sources/SOURCE-PINS.env"

version="${RMPC_REF#v}"
archive="$ROOT_DIR/sources/vendor/rmpc-${RMPC_REF}-x86_64-unknown-linux-gnu.tar.gz"
build_root="$ROOT_DIR/sources/build/rmpc-deb"
output="$build_root/rmpc_${version}-${RMPC_PACKAGE_REVISION}_amd64.deb"
license="$ROOT_DIR/licenses/BSD-3-Clause-RMPC.txt"
export SOURCE_DATE_EPOCH="$RMPC_SOURCE_DATE_EPOCH"
export LC_ALL=C

[[ -f $archive ]] || {
  echo "rmpc-Archiv fehlt: $archive" >&2
  exit 1
}
[[ -f $license ]] || {
  echo "rmpc-Lizenz fehlt: $license" >&2
  exit 1
}

printf '%s  %s\n' "$RMPC_ARCHIVE_SHA256" "$archive" | sha256sum -c -

mkdir -p "$build_root"
stage="$(mktemp -d "$build_root/rmpc-package.XXXXXX")"
unpack="$(mktemp -d "$build_root/rmpc-unpack.XXXXXX")"
trap 'rm -rf "$stage" "$unpack"' EXIT

tar -xzf "$archive" -C "$unpack"

for required in \
  "$unpack/rmpc" \
  "$unpack/man/rmpc.1" \
  "$unpack/completions/rmpc.bash"
do
  [[ -f $required ]] || {
    echo "Unerwarteter rmpc-Archivinhalt; fehlt: $required" >&2
    exit 1
  }
done

reported_version="$("$unpack/rmpc" version 2>/dev/null | head -n1)"
grep -Fq "$version" <<<"$reported_version" || {
  echo "Unerwartete rmpc-Version: $reported_version" >&2
  exit 1
}

install -D -m 0755 "$unpack/rmpc" "$stage/usr/bin/rmpc"
install -D -m 0644 "$unpack/man/rmpc.1" "$stage/usr/share/man/man1/rmpc.1"
install -D -m 0644 "$unpack/completions/rmpc.bash" \
  "$stage/usr/share/bash-completion/completions/rmpc"
install -D -m 0644 "$license" "$stage/usr/share/doc/rmpc/copyright"

mkdir -p "$stage/DEBIAN"
cat >"$stage/DEBIAN/control" <<EOF
Package: rmpc
Version: ${version}-${RMPC_PACKAGE_REVISION}
Section: sound
Priority: optional
Architecture: amd64
Maintainer: Lesbian Stable Project <noreply@invalid>
Depends: libc6, libgcc-s1
Description: terminal client for Music Player Daemon
 rmpc is a terminal MPD client packaged from the pinned upstream binary
 used by the Lesbian Stable desktop profile.
EOF

changelog_date="$(date -u -d "@$SOURCE_DATE_EPOCH" '+%a, %d %b %Y %H:%M:%S +0000')"
cat >"$stage/usr/share/doc/rmpc/changelog.Debian" <<EOF
rmpc (${version}-${RMPC_PACKAGE_REVISION}) unstable; urgency=medium

  * Package the verified upstream rmpc ${version} binary for Lesbian Stable.

 -- Lesbian Stable Project <noreply@invalid>  ${changelog_date}
EOF

sed -i '0,/^rmpc$/s//rmpc \\- terminal client for Music Player Daemon/' \
  "$stage/usr/share/man/man1/rmpc.1"
gzip -9n "$stage/usr/share/man/man1/rmpc.1"
gzip -9n "$stage/usr/share/doc/rmpc/changelog.Debian"

find "$stage" -type d -exec chmod 0755 {} +
find "$stage" -type f -exec chmod 0644 {} +
chmod 0755 "$stage/usr/bin/rmpc"
find "$stage" -exec touch -d "@$SOURCE_DATE_EPOCH" {} +

dpkg-deb --root-owner-group --build "$stage" "$output"
dpkg-deb --info "$output"
sha256sum "$output"
