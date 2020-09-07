#!/bin/bash
#
# Performs Safe Push by pushing HEAD to temporary branch what triggers TeamCity build chain (compilation and/or test aggregator).
#
# Usage: ./safePush.sh <safepush_type>
#
# Limitations:
#  At the moment Safe Push can be performed only to master branch.

set -e
set -o pipefail

BUILD_SERVER=https://buildserver.labs.intellij.net
SAFEPUSH_REFS_PREFIX=refs/heads

safepush_type="$(echo -e "$1" | tr -d '[:space:]')"
case "$safepush_type" in
"")
  echo "Usage: ./safePush.sh <safepush_type>"
  echo "Available Safe Push types:"
  echo "  autopush  - auto push."
  echo "  compile  - compilation only."
  echo "  all      - all tests in aggregator."
  echo "  affected - tests that could be affected by changes."
  echo "  fleet    - tests related to Fleet project."
  exit 1
  ;;
autopush)
  build_type=Kotlin_BuildPlayground_Jupiter_AutoPush
  ;;
compile)
  build_type=ijplatform_master_SafePushWithCompilation
  ;;
all)
  build_type=ijplatform_master_SafePushWithTests
  ;;
affected)
  build_type=ijplatform_master_SafePushWithAffectedTests
  ;;
fleet)
  build_type=ijplatform_master_SafePushFleet
  ;;
*)
  echo "Unknown safe push type '$safepush_type'."
  exit 1
  ;;
esac

cd "$(dirname "$0")"

current_branch="$(git rev-parse --abbrev-ref HEAD)"
#case $current_branch in
#master)
#  ;;
#202*)
#  ;;
#*)
#  echo "Safe push can be performed only to master, stable or release branches. Current branch - $current_branch"
#  exit 1
#  ;;
#esac

git status -uno --porcelain | grep "^\(A.\| M\|D.\| D\)\s" -q && {
  git stash
  trap 'git stash pop' EXIT
}

merges_count="$(git rev-list --count --merges origin/$current_branch..HEAD)"
if [ "$merges_count" = 0 ]; then
  git pull --rebase origin || >&2 echo "Failed to perform git pull"
else
  git pull origin || >&2 echo "Failed to perform git pull"
fi

user_name="$(git config user.name | tr ' ' .)"
branch_logical_name="$user_name/$current_branch/$RANDOM"
safepush_ref="$safepush_type/$branch_logical_name"
echo "Performing push to '$safepush_ref':"
# '2>&1 | cat' hides progress messages printed by git
git push origin "HEAD:$SAFEPUSH_REFS_PREFIX/$safepush_ref" 2>&1 | cat
echo "Build will be triggered here - $BUILD_SERVER/buildConfiguration/$build_type?branch=$safepush_ref&mode=builds"