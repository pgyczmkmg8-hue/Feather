#!/bin/sh
# Merge the latest seomin0610/Feather main into local main and push to origin.
# On conflict, resolve the files, `git commit`, then `git push origin main`.
set -e
cd "$(git rev-parse --show-toplevel)"

git remote get-url upstream >/dev/null 2>&1 ||
	git remote add upstream https://github.com/seomin0610/Feather.git

git checkout main
git pull --ff-only origin main
git fetch upstream main

if [ "$(git rev-list --count HEAD..upstream/main)" = 0 ]; then
	echo "Already up to date with upstream."
	exit 0
fi

git merge --no-edit upstream/main
git submodule update --init --recursive
git push origin main
