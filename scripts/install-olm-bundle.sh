#! /usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/functions.sh"
checkDependencies

OPTS=`getopt -o v:i:u:f --long version:,input:,input-url:,force,push,commit,validate -n 'parse-options' -- "$@"`
if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi
eval set -- "$OPTS"

# Set defaults
OUTPUT_DIR_BASE="$(cd -- "$SCRIPT_DIR/../olm/bundles" && pwd )"
MAVEN_REPO_CENTRAL="https://repo1.maven.org/maven2"
FORCE=false
TMP_WORKDIR=$(mktemp -d)
COMMIT=false
PUSH=false
VALIDATE=false

# Process script options
while true; do
  case "$1" in
    -v | --version )            DEBEZIUM_VERSION=$2;                  shift; shift ;;
    -i | --input )              INPUT_FILE=$2;                      shift; shift ;;
    -u | --input-url )          INPUT_URL=$2;                       shift; shift ;;
    -f | --force )              FORCE=true;                         shift ;;
    --validate )                VALIDATE=true;                      shift ;;
    --commit )                  COMMIT=true;                        shift ;;
    --push )                    COMMIT=true;
                                PUSH=true;                          shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

if [[ ! -d "$OUTPUT_DIR_BASE" ]]; then
  echo "Output directory $OUTPUT_DIR_BASE does not exist!"
  exit 1
fi

if [[ ! -z "${BUNDLE_VERSION:-}" ]]; then
  if [[ ! -z "${INPUT_URL:-}" ||  ! -z "${INPUT_FILE:-}" ]]; then
    echo "-v specifying Debezium version with explicit input"
    echo "Bundle version will be deduced and option value is ignored"
    echo ""
  fi
fi

if [[ -z "${INPUT_URL:-}" && -z "${INPUT_FILE:-}" ]]; then
  INPUT_URL="$MAVEN_REPO_CENTRAL/io/debezium/debezium-operator/$DEBEZIUM_VERSION/debezium-operator-$DEBEZIUM_VERSION-olm-bundle.zip"
fi

if [[ ! -z "${INPUT_URL:-}" ]]; then
  INPUT_FILE="$TMP_WORKDIR/bundle.zip"
  echo "Input url: $INPUT_FILE"
  echo "Downloading bundle archive to '$INPUT_FILE'"
  curl -Ljs -o "$INPUT_FILE" "$INPUT_URL"
fi

# Unzip $INPUT_INPUT_FILE and move bundle to
unzip -qd "$TMP_WORKDIR" "$INPUT_FILE"
BUNDLE_VERSION=$(csvVersion "$TMP_WORKDIR")
OUTPUT_DIR="$OUTPUT_DIR_BASE/$BUNDLE_VERSION"

echo ""
echo "Installing OLM bundle"
echo "Bundle output dir: $OUTPUT_DIR"
echo ""

if [[ -d "$OUTPUT_DIR" && "$FORCE" = true ]]; then
  echo "Removing exiting bundle directory '$OUTPUT_DIR'"
  rm -rf "$OUTPUT_DIR"
fi


if [[ -d "$OUTPUT_DIR" ]]; then
  echo "Directory $OUTPUT_DIR already exists!"
  echo "Use -f / --force to overwrite"
  exit 2
fi

# Move the bundle to $OUTPUT_DIR
mv "$TMP_WORKDIR"/debezium-operator.v* "$OUTPUT_DIR"

# Remove temporary work directory
if [[ -d "$TMP_WORKDIR" ]]; then
  rm -rf "$TMP_WORKDIR"
fi

# Validate installed bundle if requested
if [[ "$VALIDATE" = true ]]; then
  echo ""
  echo "Validating OLM bundle in $OUTPUT_DIR"
  operator-sdk bundle validate "$OUTPUT_DIR"
fi

echo ""
echo "OLM bundle $BUNDLE_VERSION installed!"

# Commit and push if requested
if [[ "$COMMIT" = true ]]; then
  echo ""
  echo "Committing bundle to repository"
  git add "$OUTPUT_DIR"
  git commit -m "operator debezium-operator ($BUNDLE_VERSION)"
fi

if [[ "$PUSH" = true ]]; then
  echo ""
  echo "Pushing changes to remote repository"
  git push
fi