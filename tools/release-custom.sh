#!/bin/sh
# Build Feather from main, publish it as a custom-<version> release on the
# private repo, and list it in custom-repo.json so the app offers it as an update.
#
# Version: upstream FEATHER_PROJECT_VERSION plus a build counter, e.g. 2.9.4.1, 2.9.4.2.
set -e
cd "$(git rev-parse --show-toplevel)"

REPO=pgyczmkmg8-hue/Feather
FEED=custom-repo.json

if [ -n "$(git status --porcelain)" ]; then
	echo "Commit or stash local changes first." >&2
	exit 1
fi
git checkout -q main
git pull -q --ff-only origin main

BASE=$(sed -n 's/^FEATHER_PROJECT_VERSION *= *//p' Feather.xcconfig | tr -d '[:space:]')
COUNT=$(gh release list -R "$REPO" --limit 200 --json tagName -q ".[].tagName" | grep -c "^custom-$BASE\." || true)
VERSION="$BASE.$((COUNT + 1))"
TAG="custom-$VERSION"
echo "Building Feather $VERSION ($TAG)"

# same steps as `make iphoneos`, with the version overridden
rm -rf _build packages
xcodebuild \
	-project Feather.xcodeproj \
	-scheme Feather \
	-configuration Release \
	-destination "generic/platform=iOS" \
	-derivedDataPath "${TMPDIR:-/tmp}/Feather/custom" \
	-skipPackagePluginValidation \
	CODE_SIGNING_ALLOWED=NO \
	ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES=NO \
	FEATHER_PROJECT_VERSION="$VERSION" \
	CURRENT_PROJECT_VERSION="$(git rev-list --count HEAD)" \
	-quiet

mkdir -p _build/Payload packages
cp -R _build/Applications/*.app _build/Payload/Feather.app
chmod -R 0755 _build/Payload/Feather.app
find _build/Payload/Feather.app -name '*.appex' -exec codesign --force --sign - --timestamp=none {} \;
codesign --force --sign - --timestamp=none _build/Payload/Feather.app
ditto -c -k --sequesterRsrc --keepParent _build/Payload packages/Feather.ipa

# release notes: our commits since the previous custom release (or upstream's last tag)
PREVIOUS=$(git tag --list 'custom-*' --sort=-creatordate | head -1)
[ -z "$PREVIOUS" ] && PREVIOUS=$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)
NOTES=$(git log --no-merges --format='- %s' ${PREVIOUS:+"$PREVIOUS"..}HEAD)

gh release create "$TAG" packages/Feather.ipa \
	-R "$REPO" \
	--target main \
	--title "Feather $VERSION" \
	--notes "${NOTES:-Feather $VERSION}"
git fetch -q --tags origin

SIZE=$(stat -f %z packages/Feather.ipa)
DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
URL="https://github.com/$REPO/releases/download/$TAG/Feather.ipa"

# custom-repo.json starts from upstream's app entry and keeps only our versions
[ -f "$FEED" ] || jq '.apps = [.apps[0] | .versions = []] | .news = [] | .name = "Feather (custom)" | .identifier = "feather.custom"' app-repo.json > "$FEED"
jq \
	--arg version "$VERSION" \
	--arg date "$DATE" \
	--arg url "$URL" \
	--argjson size "$SIZE" \
	--arg notes "$NOTES" \
	'
	{version: $version, date: $date, size: $size, downloadURL: $url, localizedDescription: $notes} as $entry |
	.apps[0].version = $version |
	.apps[0].versionDate = $date |
	.apps[0].size = $size |
	.apps[0].downloadURL = $url |
	.apps[0].versions = [$entry] + (.apps[0].versions | map(select(.version != $version)))
	' "$FEED" > "$FEED.tmp"
mv "$FEED.tmp" "$FEED"

git add "$FEED"
git commit -q -m "chore: custom release $VERSION"
git push -q origin main
echo "Published $TAG: $URL"
