#! /usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/functions.sh"
checkDependencies

OPTS=`getopt -o v:k:o:f --long version:,k8s:,ocp:,force,push,push-remote: -n 'parse-options' -- "$@"`
if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi
eval set -- "$OPTS"

# Set defaults
INPUT_DIR_BASE="$(cd -- "$SCRIPT_DIR/../olm/bundles" && pwd )"
FORCE=false
PUSH=false
PUSH_REMOTE="origin"

# Process script options
while true; do
  case "$1" in
    -v | --version )            BUNDLE_VERSION=$2;                  shift; shift ;;
    -k | --k8s )                K8_COMMUNITY_OPERATORS=$2;          shift; shift ;;
    -o | --ocp )                OCP_COMMUNITY_OPERATORS=$2;         shift; shift ;;
    -f | --force )              FORCE=true;                         shift ;;
    --push-remote )             PUSH_REMOTE=$2;                     shift; shift ;;
    --push )                    PUSH=true;                          shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

INPUT_DIR="$INPUT_DIR_BASE/$BUNDLE_VERSION"
OUTPUT_DIR_PATH="operators/debezium-operator"

function release() {
    community_operators="$1"
    community_operators_url="$2"
    output_dir_base="$community_operators/$OUTPUT_DIR_PATH"
    output_dir="$output_dir_base/$BUNDLE_VERSION"
    ci_input_file="$INPUT_DIR_BASE/$3"
    ci_output_file="$output_dir_base/ci.yaml"

    if [[ ! -d "$community_operators" ]]; then
      echo "Community Operators repo directory $community_operators does not exist!"
      exit 1
    fi

    if [[ -d "$output_dir" && "$FORCE" = true ]]; then
      echo "Removing exiting bundle directory '$output_dir'"
      rm -rf "$output_dir"
    fi


    if [[ -d "$output_dir" ]]; then
      echo "Directory $output_dir already exists!"
      echo "Use -f / --force to overwrite"
      exit 2
    fi

    echo ""
    echo "Copying OLM bundle to Community Operators"
    echo "Source dir: $INPUT_DIR"
    echo "Target dir: $output_dir"
    echo ""

    # Copy bundle manifest and ci file to community operators repository
    if [[ ! -d "$output_dir_base" ]]; then
      mkdir -p "$output_dir_base"
    fi
    cp -r "$INPUT_DIR" "$output_dir"
    cp "$ci_input_file" "$ci_output_file"

    # Create branch and commit changes to Community Operators
    pushd "$community_operators"
    echo "Creating new branch '$BUNDLE_VERSION' in Community Operators repository"
    git switch -c "$BUNDLE_VERSION" main
    echo "Committing bundle to Community Operators repository"
    git add "$OUTPUT_DIR_PATH"
    git add "$ci_output_file"
    echo ""
    echo "Following change will be committed:"
    git status
    git commit -s -m "operator debezium-operator ($BUNDLE_VERSION)"


    if [[ "$PUSH" = true ]]; then
      echo "Pushing changes to remote repository"
      git push "$PUSH_REMOTE" "$BUNDLE_VERSION"

      echo ""
      echo "Done! Review changes and open PR to the main branch of $community_operators_url"
    else
      echo ""
      echo "Done! Push changes and open PR to the main branch of $community_operators_url"
    fi

    popd
}


if [[ ! -z "${K8_COMMUNITY_OPERATORS:-}" ]]; then
    release "$K8_COMMUNITY_OPERATORS" "https://github.com/k8s-operatorhub/community-operators" "ci.yaml"
fi

if [[ ! -z "${OCP_COMMUNITY_OPERATORS:-}" ]]; then
    release "$OCP_COMMUNITY_OPERATORS" "https://github.com/redhat-openshift-ecosystem/community-operators-prod" "ci.openshift.yaml"
fi