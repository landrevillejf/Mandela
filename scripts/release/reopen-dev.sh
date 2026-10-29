#!/usr/bin/env bash
# scripts/release/reopen-dev.sh — re-open the dev cycle after a release ships.
#
# Once vX.Y.Z is published, the default branch needs a fresh "## [Unreleased]"
# CHANGELOG section above the just-released [X.Y.Z] so subsequent PRs have
# somewhere to add bullets. Mandela carries NO -dev line: the jar-axis refs
# (gradle.properties and friends) STAY at the released X.Y.Z — that is what keeps
# scripts/mandela/mandela-version.mnd green — and the re-opened header is labelled
# with the next anticipated version for clarity only. Stages nothing; never runs
# `git add -A`.
#
# Usage:
#   reopen-dev.sh --released <X.Y.Z> [--next <A.B.C>] [--level major|minor|patch]
#                 [--dry-run]
#
#   --released  the version just published (used to derive --next when omitted)
#   --next      explicit label for the re-opened [Unreleased] header
#               (default: <released> bumped one --level, no -dev suffix)
#   --level     bump level used to derive --next from --released (default: patch)
#   --dry-run   show what would change without writing
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/release/lib.sh
. "$HERE/lib.sh"

RELEASED="" NEXT="" LEVEL="patch" DRY=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --released) RELEASED="$2"; shift 2 ;;
        --next)     NEXT="$2"; shift 2 ;;
        --level)    LEVEL="$2"; shift 2 ;;
        --dry-run)  DRY=true; shift ;;
        -h|--help)  sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)          log_die "reopen-dev.sh: unknown argument '$1'" ;;
    esac
done

if [ -z "$NEXT" ]; then
    [ -n "$RELEASED" ] || log_die "either --released or --next is required."
    is_semver "$RELEASED" || log_die "--released '$RELEASED' is not X.Y.Z."
    case "$LEVEL" in major|minor|patch) ;; *) log_die "invalid --level '$LEVEL'" ;; esac
    NEXT="$(bump_version "$RELEASED" "$LEVEL")"
fi
NEXT="$(strip_dev "$NEXT")"
is_version "$NEXT" || log_die "next '$NEXT' is not a valid version."

cd "$(repo_root)"

if [ "$DRY" = true ]; then
    log_info "[dry-run] would re-open CHANGELOG [Unreleased] — ${NEXT}"
    log_info "[dry-run] jar-axis refs stay at the released version (no -dev line)."
    exit 0
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
    git status --short | grep -vE '^\?\?' || true
    log_die "uncommitted changes to tracked files (above); commit or stash them first."
fi

reopen_changelog_unreleased "$NEXT"
log_ok "re-opened the dev cycle with a fresh [Unreleased] — ${NEXT} (jar-axis refs unchanged)."
