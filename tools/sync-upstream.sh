#!/bin/sh
# Merge the latest seomin0610/Feather main into local main and push to origin (GitLab) and the GitHub mirror.
# On conflict, resolve the files, `git commit`, then `git push origin main` and `git push github main`.
# GitHub's own daily sync may have merged upstream first: then `git fetch github && git merge github/main` before pushing.
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
GIT_TERMINAL_PROMPT=0 git push github main ||
	echo "warning: could not push to github (diverged? see the note at the top of this script)" >&2
