#! /usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/functions.sh"
checkDependencies

OPTS=`getopt -o v:r:f --long version:,repodir:,force,push,push-remote: -n 'parse-options' -- "$@"`
if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi
eval set -- "$OPTS"

# Set defaults
INPUT_DIR_BASE="$SCRIPT_DIR/../olm/bundles"
FORCE=false
PUSH=false
PUSH_REMOTE="origin"

# Process script options
while true; do
  case "$1" in
    -v | --version )            BUNDLE_VERSION=$2;                  shift; shift ;;
    -r | --repodir )            COMMUNITY_OPERATORS_REPO_DIR=$2;    shift; shift ;;
    -f | --force )              FORCE=true;                         shift ;;
    --push-remote )             PUSH_REMOTE=$2;                     shift; shift ;;
    --push )                    PUSH=true;                          shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

INPUT_DIR="$INPUT_DIR_BASE/$BUNDLE_VERSION"
OUTPUT_DIR_PATH="operators/debezium-operator"
OUTPUT_DIR_BASE="$COMMUNITY_OPERATORS_REPO_DIR/$OUTPUT_DIR_PATH"
OUTPUT_DIR="$OUTPUT_DIR_BASE/$BUNDLE_VERSION"
BRANCH="debezium-operator.v$BUNDLE_VERSION"

if [[ ! -d "$COMMUNITY_OPERATORS_REPO_DIR" ]]; then
  echo "Community Operators repo directory $COMMUNITY_OPERATORS_REPO_DIR does not exist!"
  exit 1
fi

if [[ -d "$OUTPUT_DIR" && "$FORCE" = true ]]; then
  echo "Removing exiting bundle directory '$OUTPUT_DIR'"
  rm -rf "$OUTPUT_DIR"
fi


if [[ -d "$OUTPUT_DIR" ]]; then
  echo "Directory $OUTPUT_DIR already exists!"
  echo "Use -f / --force to overwrite"
  exit 2
fi

echo ""
echo "Copying OLM bundle to Community Operators"
echo "Source dir: $INPUT_DIR"
echo "Target dir: $OUTPUT_DIR"
echo ""

# Copy bundle manifest to community operators repository
if [[ ! -d "$OUTPUT_DIR_BASE" ]]; then
  mkdir -p "OUTPUT_DIR_BASE"
fi
cp -r "$INPUT_DIR" "$OUTPUT_DIR_BASE"


# Create branch and commit changes to Community Operators
pushd "$COMMUNITY_OPERATORS_REPO_DIR"
echo "Creating new branch '$BRANCH' in Community Operators repository"
git switch -c "$BRANCH" main
echo "Committing bundle to Community Operators repository"
git add "$OUTPUT_DIR_PATH"
git commit -s -m "operator debezium-operator ($BUNDLE_VERSION)"


if [[ "$PUSH" = true ]]; then
  echo "Pushing changes to remote repository"
  git push "$PUSH_REMOTE" "$BRANCH"

  echo ""
  echo "Done! Review changes and open PR to the main branch of https://github.com/k8s-operatorhub/community-operators"
else
  echo ""
  echo "Done! Push changes and open PR to the main branch of https://github.com/k8s-operatorhub/community-operators"
fi


popd "$COMMUNITY_OPERATORS_REPO_DIR"