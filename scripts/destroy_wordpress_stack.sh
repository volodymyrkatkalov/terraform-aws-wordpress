#!/usr/bin/env bash
. ./scripts/export_env.sh
terraform -chdir="./terraform-stack" destroy -auto-approve -lock=false
rm -rf ./terraform-stack/.ssh
