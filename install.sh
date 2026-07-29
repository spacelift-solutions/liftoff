#!/bin/sh
# Installs liftoff on Linux and macOS; Homebrew is the better path where it
# exists. POSIX sh: this runs before liftoff does, on an unknown machine.
set -eu

REPO=spacelift-solutions/liftoff
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
VERSION="${VERSION:-}"

die() {
	echo "liftoff: $1" >&2
	[ $# -gt 1 ] && echo "  $2" >&2
	exit 1
}

need() {
	command -v "$1" >/dev/null 2>&1 || die "$1 is required but not installed"
}

need curl
need tar

case "$(uname -s)" in
Linux) os=linux ;;
Darwin) os=darwin ;;
MINGW* | MSYS* | CYGWIN*)
	die "this script does not support Windows" \
		"download the Windows zip from https://github.com/$REPO/releases/latest"
	;;
*) die "unsupported operating system: $(uname -s)" ;;
esac

case "$(uname -m)" in
x86_64 | amd64) arch=amd64 ;;
arm64 | aarch64) arch=arm64 ;;
*) die "unsupported architecture: $(uname -m)" ;;
esac

# The latest-release endpoint skips prereleases, so a release candidate is only
# ever installed by asking for it: VERSION=v1.2.0-rc.1
if [ -z "$VERSION" ]; then
	VERSION="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" |
		sed -n 's/.*"tag_name" *: *"\([^"]*\)".*/\1/p' | head -n1)"
	[ -n "$VERSION" ] || die "could not work out the latest version" \
		"check https://github.com/$REPO/releases, or set VERSION"
fi

archive="liftoff_${VERSION#v}_${os}_${arch}.tar.gz"
base="https://github.com/$REPO/releases/download/$VERSION"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "liftoff: downloading $VERSION for $os/$arch"
curl -fsSL "$base/$archive" -o "$tmp/$archive" ||
	die "no build for $os/$arch at $VERSION" "see https://github.com/$REPO/releases"
curl -fsSL "$base/checksums.txt" -o "$tmp/checksums.txt" ||
	die "could not download the checksums for $VERSION"

if command -v sha256sum >/dev/null 2>&1; then
	actual="$(sha256sum "$tmp/$archive" | cut -d' ' -f1)"
elif command -v shasum >/dev/null 2>&1; then
	actual="$(shasum -a 256 "$tmp/$archive" | cut -d' ' -f1)"
else
	die "neither sha256sum nor shasum is installed" "cannot verify the download"
fi

expected="$(grep " $archive\$" "$tmp/checksums.txt" | cut -d' ' -f1)"
[ -n "$expected" ] || die "$archive is not listed in checksums.txt"
[ "$actual" = "$expected" ] ||
	die "checksum mismatch for $archive — the download is not what we published" \
		"expected $expected, got $actual"

tar -xzf "$tmp/$archive" -C "$tmp" liftoff || die "could not extract $archive"

if [ ! -d "$INSTALL_DIR" ]; then
	mkdir -p "$INSTALL_DIR" 2>/dev/null ||
		die "$INSTALL_DIR does not exist and could not be created" \
			"re-run piping to: INSTALL_DIR=\$HOME/.local/bin sh"
fi

# Never escalate on the caller's behalf: say what to run instead. The setting
# goes on sh — in front of curl it reaches the download, not this script.
[ -w "$INSTALL_DIR" ] ||
	die "$INSTALL_DIR is not writable" \
		"pipe to: INSTALL_DIR=\$HOME/.local/bin sh — or to: sudo sh"

install -m 755 "$tmp/liftoff" "$INSTALL_DIR/liftoff" ||
	die "could not install to $INSTALL_DIR"

echo "liftoff: installed $VERSION to $INSTALL_DIR/liftoff"

case ":$PATH:" in
*":$INSTALL_DIR:"*) ;;
*) echo "liftoff: $INSTALL_DIR is not on your PATH — add it to run 'liftoff'" >&2 ;;
esac

echo "liftoff: next, run 'liftoff skills start'"
