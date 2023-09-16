# debezium-operator-manifests
This is a repository of operator bundle manifests for released versions of [Debezium operator](https://github.com/debezium/debezium-operator)

## Publishing bundles to OperatorHub catalog
Full documentation is available at [OperatorHub.io](https://operatorhub.io/contribute)

*Prerequisities:*
1. Version of operator bundle is present in `olm/bundles` of this repo
2. Read [Contributing Prerequisites](https://k8s-operatorhub.github.io/community-operators/contributing-prerequisites/) and configure your git appropriately 
3. Fork OperatorHub's [community operators repo](https://github.com/k8s-operatorhub/community-operators) and clone it

*Steps:*
The code snippet bellow demonstrates the process of publishif $BUDNLE_VERSION to OperatorHub's community catalog

```bash
# Change the following
export BUNDLE_VERSION="2.4.0" 
export COMMUNITY_OPERATORS_REPO_DIR="placeholder" 

# Copy the bundle and push changes
./scripts/release-operatorhub.sh -v "$BUNDLE_VERSION" --repodir "$COMMUNITY_OPERATORS_REPO_DIR" --push
```

Now open a PR against the main branch of OperatorHub's [community operators repo](https://github.com/k8s-operatorhub/community-operators). Once the PR is approved by somebody listed in `ci.yaml` all is done.

## Creating new bundle manifests
Following these steps to generate OLM bundle manifest for new Debezium Operator release.

```bash
# Change the following
export DEBEZIUM_VERSION="2.4.0"
export MAVEN_REPO_CENTRAL="https://repo1.maven.org/maven2"
export BUNDLE_URL="$MAVEN_REPO_CENTRAL/io/debezium/debezium-operator/$DEBEZIUM_VERSION/debezium-operator-$DEBEZIUM_VERSION-olm-bundle.zip"

# Add bundle to olm/bundles
# (and commit right away)
./scripts/install-olm-bundle.sh -u "$BUNDLE_URL" -v $DEBEZIUM_VERSION --commit

# Alternatively you can also add bundle from  local file
# ./scripts/install-olm-bundle.sh -i "$BUNDLE_ZIP" -v $DEBEZIUM_VERSION --commit


# Optional if you also wish to build the test catalog later
# Build and push bundle image 
# (defaults to quay.io/debezium/operator-bundle)
./scripts/create-olm-bundle-image.sh -v "$DEBEZIUM_VERSION" --push
```

Now open a PR agaisnt the main branch of [manifest repo](https://github.com/debezium/debezium-operator-manifests) and all is done.

## Creating test catalog
You can build a test OLM catalog index from these operator bundles

_Note: while the script uses these manifests files, the bundles included in the catalog have to be published as container images_

```bash
# Build and push catalog image (assumes bundle images were pushed)
# (defaults to quay.io/debezium/operator-catalog)
./scripts/create-olm-test-catalog.sh \
    -i "$MANIFESTS_REPO_DIR/olm/bundles" \
    -o "$MANIFESTS_REPO_DIR/olm/catalog" \
    --push
```

