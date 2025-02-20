#!/bin/bash -l
set -eo pipefail

export HELM_VERSION=${HELM_VERSION:="3.8.0"}
export HELM_ARTIFACTORY_PLUGIN_VERSION=${HELM_ARTIFACTORY_PLUGIN_VERSION:="v1.0.2"}
export CHART_VERSION=${CHART_VERSION:-}
export HELM_REPO_NAME=${HELM_REPO_NAME:-}
export HELM_REPO_URL=${HELM_REPO_URL:-}
export HELM_INSTALLED=${HELM_INSTALLED:false}

print_title(){
    echo "#####################################################"
    echo "$1"
    echo "#####################################################"
}


fix_chart_version(){
    if [[ -z "$CHART_VERSION" ]]; then
        print_title "Calculating chart version"
        echo "Installing prerequisites"
        pip3 install PyYAML
        pushd "$CHART_DIR"
        CANDIDATE_VERSION=$(python3 -c "import yaml; f=open('Chart.yaml','r');  p=yaml.safe_load(f.read()); print(p['version']); f.close()" )
        popd
        echo "${GITHUB_EVENT_NAME}"
        if [ "${GITHUB_EVENT_NAME}" == "pull_request" ]; then
            CHART_VERSION="${CANDIDATE_VERSION}-$(git rev-parse --short "$GITHUB_SHA")"
        else
            CHART_VERSION="${CANDIDATE_VERSION}"
        fi
        export CHART_VERSION
    fi
}

add_helm_repo(){
    helm repo add stable 'https://charts.helm.sh/stable' \
    && helm repo add incubator 'https://charts.helm.sh/incubator' \
    && helm repo add jfrog 'https://charts.jfrog.io/' \
    && helm repo add jetstack https://charts.jetstack.io \
    && helm repo add codecentric https://codecentric.github.io/helm-charts \
    && helm repo add helm-charts-external https://raw.githubusercontent.com/OpenGov/helm-charts-external/master/ \
    && helm repo add botkube https://infracloudio.github.io/charts \
    && helm repo add external-dns https://charts.bitnami.com/bitnami \
    && helm repo add aws-load-balancer-controller https://aws.github.io/eks-charts
}

get_helm() {
    print_title "Get helm:${HELM_VERSION}"
    curl -L "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" | tar xvz
    chmod +x linux-amd64/helm
    sudo mv linux-amd64/helm /usr/local/bin/helm
    export HELM_INSTALLED=true
}

install_helm() {
    if ! command -v helm; then
        echo "Helm is missing"
        get_helm
    elif ! [[ $(helm version --short -c) == *${HELM_VERSION}* ]]; then
        echo "Helm $(helm version --short -c) is not desired version"
        get_helm
    fi
}

install_artifactory_plugin(){
    print_title "Install helm artifactory plugin"
    if ! (helm plugin list  | grep -q push-artifactory); then
        helm plugin install https://github.com/belitre/helm-push-artifactory-plugin --version ${HELM_ARTIFACTORY_PLUGIN_VERSION}
    fi
}

remove_helm(){
    helm plugin uninstall push-artifactory
    if [["$HELM_INSTALLED" = true]]; then
        sudo rm -rf /usr/local/bin/helm
    fi    
}

helm_dependency(){
    print_title "Helm dependency build"
    helm dependency build "${CHART_DIR}"
}

helm_lint(){
    print_title "Linting"
    helm lint "${CHART_DIR}"
}

helm_package(){
    print_title "Packaging"
    helm package "${CHART_DIR}" --version v"${CHART_VERSION}" --app-version "${CHART_VERSION}" --destination "${RUNNER_WORKSPACE}"
}

helm_push(){
    print_title "Push chart"
    if [[ -v ARTIFACTORY_API_KEY ]]; then 
        helm push-artifactory "${CHART_DIR}" "${ARTIFACTORY_URL}" --api-key "${ARTIFACTORY_API_KEY}" --version "${CHART_VERSION}" --skip-reindex
    elif [[ -v ARTIFACTORY_PASSWORD ]] && [[ -v ARTIFACTORY_USERNAME ]]; then 
        helm push-artifactory "${CHART_DIR}" "${ARTIFACTORY_URL}" --username "${ARTIFACTORY_USERNAME}" --password "${ARTIFACTORY_PASSWORD}" --version "${CHART_VERSION}" --skip-reindex
    else
        echo "ARTIFACTORY_API_KEY or ARTIFACTORY_PASSWORD and ARTIFACTORY_USERNAME must be set"
        exit 1
    fi
}
