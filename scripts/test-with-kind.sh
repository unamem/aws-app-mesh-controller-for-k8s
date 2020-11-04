#!/usr/bin/env bash

# A script that builds the appmesh controller, provisions a KinD
# Kubernetes cluster, installs appmesh CRDs and controller into that
# Kubernetes cluster and runs a set of tests

set -Eo pipefail

SCRIPTS_DIR=$(cd "$(dirname "$0")" || exit 1; pwd)
ROOT_DIR="$SCRIPTS_DIR/.."
INT_TEST_DIR="$ROOT_DIR/test/integration"

AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-""}
AWS_REGION=${AWS_REGION:-"us-west-2"}
IMAGE_NAME=amazon/appmesh-controller
ECR_URL=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
IMAGE=${ECR_URL}/${IMAGE_NAME}


CLUSTER_NAME_BASE="test"
K8S_VERSION="1.17"
TMP_DIR=""

source "$SCRIPTS_DIR/lib/aws.sh"
source "$SCRIPTS_DIR/lib/common.sh"

check_is_installed curl
check_is_installed docker
check_is_installed jq
check_is_installed uuidgen
check_is_installed wget
check_is_installed kind "You can install kind with the helper scripts/install-kind.sh"
check_is_installed kubectl "You can install kubectl with the helper scripts/install-kubectl.sh"
check_is_installed kustomize "You can install kustomize with the helper scripts/install-kustomize.sh"
check_is_installed controller-gen "You can install controller-gen with the helper scripts/install-controller-gen.sh"


function setup_kind_cluster {
    TEST_ID=$(uuidgen | cut -d'-' -f1 | tr '[:upper:]' '[:lower:]')
    CLUSTER_NAME_BASE=$(uuidgen | cut -d'-' -f1 | tr '[:upper:]' '[:lower:]')
    CLUSTER_NAME="appmesh-test-$CLUSTER_NAME_BASE"-"${TEST_ID}"
    TMP_DIR=$ROOT_DIR/build/tmp-$CLUSTER_NAME
    $SCRIPTS_DIR/provision-kind-cluster.sh "${CLUSTER_NAME}" -v "${K8S_VERSION}"
}

function install_crds {
    echo "installing CRDs ... "
    make install
    echo "ok."
}

function build_and_publish_controller {
       echo -n "building and publishing appmesh controller  ... "
       AWS_ACCOUNT=$AWS_ACCOUNT_ID AWS_REGION=$AWS_REGION make docker-build
       AWS_ACCOUNT=$AWS_ACCOUNT_ID AWS_REGION=$AWS_REGION make docker-push
       echo "ok."
}

function run_integration_tests {
       echo "Not implemented"
}

function clean_up {
    if [ -v "$TMP_DIR" ]; then
        "${SCRIPTS_DIR}"/delete-kind-cluster.sh -c "$TMP_DIR" || :
    fi
    return
}

trap "clean_up" EXIT

aws_check_credentials

if [ -z "$AWS_ACCOUNT_ID" ]; then
    AWS_ACCOUNT_ID=$( aws_account_id )
fi

ecr_login $AWS_REGION $ECR_URL

# Build and publish the controller image
build_and_publish_controller

setup_kind_cluster
export KUBECONFIG="${TMP_DIR}/kubeconfig"

# Generate and install CRDs
install_crds

# Install cert-manager
$SCRIPTS_DIR/install-cert-manager.sh

# Show the installed CRDs
kubectl get crds