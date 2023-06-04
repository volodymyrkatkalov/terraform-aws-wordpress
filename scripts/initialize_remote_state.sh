#!/usr/bin/env bash
. ./scripts/export_env.sh
terraform -chdir="terraform-remote-state" init
terraform -chdir="terraform-remote-state" apply -auto-approve