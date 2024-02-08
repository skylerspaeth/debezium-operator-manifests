#! /usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/functions.sh"
checkDependencies

OPTS=`getopt -o v:i:u:f --long version:,input:,input-url:,force,push,commit -n 'parse-options' -- "$@"`
if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi
eval set -- "$OPTS"

# Set defaults
OUTPUT_DIR_BASE="$(cd -- "$SCRIPT_DIR/../helm/charts" && pwd )"
MAVEN_REPO_CENTRAL="https://repo1.maven.org/maven2"
FORCE=false
TMP_WORKDIR=$(mktemp -d)
COMMIT=false
PUSH=false
LEGACY=false

# Process script options
while true; do
  case "$1" in
    -v | --version )            DEBEZIUM_VERSION=$2;                shift; shift ;;
    -i | --input )              INPUT_FILE=$2;                      shift; shift ;;
    -u | --input-url )          INPUT_URL=$2;                       shift; shift ;;
    -f | --force )              FORCE=true;                         shift ;;
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

if [[ ! -z "${CHART_VERSION:-}" ]]; then
  if [[ ! -z "${INPUT_URL:-}" ||  ! -z "${INPUT_FILE:-}" ]]; then
    echo "-v specifying Debezium version with explicit input"
    echo "Chart version will be deduced and option value is ignored"
    echo ""
  fi
fi

if [[ -z "${INPUT_URL:-}" && -z "${INPUT_FILE:-}" ]]; then
  INPUT_URL="$MAVEN_REPO_CENTRAL/io/debezium/debezium-operator-dist/$DEBEZIUM_VERSION/debezium-operator-dist-$DEBEZIUM_VERSION-helm-chart.zip"
fi

if [[ ! -z "${INPUT_URL:-}" ]]; then
  INPUT_FILE="$TMP_WORKDIR/chart.zip"
  echo "Input url: $INPUT_FILE"
  echo "Downloading chart archive to '$INPUT_FILE'"
  curl -Ljs -o "$INPUT_FILE" "$INPUT_URL"
fi

# Unzip $INPUT_INPUT_FILE and move helm/charts
unzip -qd "$TMP_WORKDIR" "$INPUT_FILE"
CHART_VERSION=$(chartVersion "$TMP_WORKDIR")
OUTPUT_DIR="$OUTPUT_DIR_BASE/$CHART_VERSION"

echo ""
echo "Installing Helm chart"
echo "Chart output dir: $OUTPUT_DIR"
echo ""

if [[ -d "$OUTPUT_DIR" && "$FORCE" = true ]]; then
  echo "Removing exiting chart directory '$OUTPUT_DIR'"
  rm -rf "$OUTPUT_DIR"
fi


if [[ -d "$OUTPUT_DIR" ]]; then
  echo "Directory $OUTPUT_DIR already exists!"
  echo "Use -f / --force to overwrite"
  exit 2
fi

# Move the chart to $OUTPUT_DIR
mv "$TMP_WORKDIR"/debezium-operator-* "$OUTPUT_DIR"

# Remove temporary work directory
if [[ -d "$TMP_WORKDIR" ]]; then
  rm -rf "$TMP_WORKDIR"
fi

echo ""
echo "Helm chart $CHART_VERSION installed!"

# Commit and push if requested
if [[ "$COMMIT" = true ]]; then
  echo ""
  echo "Committing chart to repository"
  git add "$OUTPUT_DIR"
  git commit -m "operator chart debezium-operator-($CHART_VERSION)"
fi

if [[ "$PUSH" = true ]]; then
  echo ""
  echo "Pushing changes to remote repository"
  git push
fi