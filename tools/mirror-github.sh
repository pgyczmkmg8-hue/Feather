#!/bin/sh
# Mirror main, a custom-<version> tag and its release (with the IPA) to the GitHub fork.
# GitLab is the primary host: tools/release-custom.sh publishes there first, then calls this.
#
# Usage: tools/mirror-github.sh [tag [ipa]]
#   tag  defaults to the newest custom-* tag
#   ipa  must be named Feather.ipa; defaults to a download of the GitLab release asset
# Safe to re-run: pushes are fast-forward only and an existing GitHub release is left alone.
set -e
cd "$(git rev-parse --show-toplevel)"

GITLAB_REPO=Yami_Q_Ray/Feather
GITHUB_REPO=pgyczmkmg8-hue/Feather
FEED=custom-repo.json
# fail instead of waiting for a password
export GIT_TERMINAL_PROMPT=0

git fetch -q github main
if ! git merge-base --is-ancestor github/main main; then
	echo "github/main has commits that main lacks (its daily upstream sync merged something)." >&2
	echo "Merge them first (git merge github/main), then push both remotes." >&2
	exit 1
fi
git push -q github main

TAG=${1:-$(git tag --list 'custom-*' --sort=-v:refname | head -1)}
VERSION=${TAG#custom-}
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || {
	echo "No local tag $TAG (try: git fetch --tags origin)." >&2
	exit 1
}
git push -q github "refs/tags/$TAG"

if gh release view "$TAG" -R "$GITHUB_REPO" >/dev/null 2>&1; then
	echo "GitHub release $TAG already exists."
	exit 0
fi

IPA=$2
if [ -z "$IPA" ]; then
	TMP=$(mktemp -d)
	trap 'rm -rf "$TMP"' EXIT
	IPA="$TMP/Feather.ipa"
	curl -fsSL -o "$IPA" "https://gitlab.com/$GITLAB_REPO/-/releases/$TAG/downloads/Feather.ipa"
fi
[ "$(basename "$IPA")" = Feather.ipa ] || {
	echo "The asset must be named Feather.ipa (the feeds link to that name)." >&2
	exit 1
}

NOTES=$(jq -r --arg v "$VERSION" '.apps[0].versions[] | select(.version == $v) | .localizedDescription // empty' "$FEED" 2>/dev/null || true)
gh release create "$TAG" "$IPA" -R "$GITHUB_REPO" --verify-tag --title "Feather $VERSION" --notes "${NOTES:-Feather $VERSION}"
echo "Mirrored $TAG: https://github.com/$GITHUB_REPO/releases/tag/$TAG"
