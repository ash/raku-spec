#!/bin/sh
# Build the spec site with rakupp, then publish out/ to the spec.raku.online server.
#
# Configuration (no paths are hard-coded here):
#   RAKUPP      interpreter to build/verify with   (default: rakupp on PATH)
#   SPEC_DEST   destination directory to publish to (the server's doc root)
#   ORACLE      optional 2nd interpreter to cross-check every example against
#               (e.g. raku = Rakudo); a divergence aborts the deploy
#
# Set them in a git-ignored ./.deploy.env, via the environment, or pass the
# destination as the first argument:
#   ./deploy.sh /path/to/docroot
set -e

cd "$(dirname "$0")"

# Optional local overrides (git-ignored): e.g. RAKUPP=… SPEC_DEST=…
[ -f .deploy.env ] && . ./.deploy.env

RAKUPP="$(command -v "${RAKUPP:-rakupp}" 2>/dev/null || true)"
DEST="${1:-$SPEC_DEST}"

[ -n "$RAKUPP" ] || { echo "rakupp not found (set RAKUPP, or put it on PATH)" >&2; exit 1; }
[ -n "$DEST" ]   || { echo "no destination (pass one, or set SPEC_DEST)" >&2; exit 1; }
[ -d "$DEST" ]   || { echo "destination not found (sshfs not mounted?): $DEST" >&2; exit 1; }

# Build and verify every example against the interpreter (and the oracle, if set);
# abort the deploy on any drift.
"$RAKUPP" build.raku --clean --verify --rakupp="$RAKUPP" ${ORACLE:+--oracle="$ORACLE"}

# Mirror out/ to the server.
cp -R out/. "$DEST"/

# macOS cp over sshfs leaves AppleDouble files, which the server would serve.
find "$DEST" -name '._*' -delete 2>/dev/null || true

echo "deployed to $DEST:"
ls -R "$DEST" | head -40
