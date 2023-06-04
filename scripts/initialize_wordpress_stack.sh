#!/usr/bin/env bash
. ./scripts/export_env.sh
terraform -chdir="./terraform-stack" init \
    -backend-config="bucket=${TF_VAR_project_name}-remote-state" \
    -backend-config="dynamodb_table=${TF_VAR_project_name}-remote-state-locks" \
    -backend-config="region=${TF_VAR_state_region}"
mkdir -p ./terraform-stack/.ssh 
if [ ! -f ./terraform-stack/.ssh/${TF_VAR_project_name} ]; then
    ssh-keygen -t rsa -b 4096 -f ./terraform-stack/.ssh/${TF_VAR_project_name} -N '' -q
fi
terraform -chdir="./terraform-stack" apply -auto-approve