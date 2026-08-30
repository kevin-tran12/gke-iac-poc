#!/usr/bin/env bash

profile=${1:-core}
export profile
TF_VAR_project_id=${TF_VAR_project_id:?TF_VAR_project_id is required}
TF_VAR_region=${TF_VAR_region:?TF_VAR_region is required}
mkdir -p test-results/live

tf_output() {
  terraform -chdir="terraform/$1" output -raw "$2"
}
