#!/bin/bash
set -o errexit
set -o pipefail


SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}" || realpath "${BASH_SOURCE[0]}")")
export SCRIPT_DIR
source "$SCRIPT_DIR/common.sh"

install_helm
install_artifactory_plugin
add_helm_repo
fix_chart_version

case $1 in
    "check")
        helm_dependency
        helm_lint
        helm_package
        ;;
    "dependency")
        helm_dependency
        ;;
    "lint")
        helm_lint
        ;;
    "package")
        helm_package
        ;;
    "check_push"):
        helm_dependency
        helm_lint
        helm_package
        helm_push
        ;;
    "push")
        helm_push
        ;;
esac

remove_helm
