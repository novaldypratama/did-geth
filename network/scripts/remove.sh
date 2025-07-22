#!/bin/bash -u

# Copyright 2023 DID Project
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
# the License. You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
# specific language governing permissions and limitations under the License.

NO_LOCK_REQUIRED=false

. ../../.env
source "$(dirname "$0")/common.sh"

removeDockerImage() {
  if [[ ! -z $(docker ps -a | grep $1) ]]; then
    docker image rm $1
  fi
}

echo "*************************************"
echo "Geth Localnet"
echo "*************************************"
echo "Stop and remove network..."

docker compose -f $GETH_DOCKER_CONFIG down -v
docker compose -f $GETH_DOCKER_CONFIG rm -sfv

# Remove volumes (prune only removes unused volumes)
docker volume rm did-geth_validator1-data did-geth_validator2-data did-geth_validator3-data did-geth_validator4-data did-geth_rpcnode-data 2>/dev/null || true

# Remove bootnode keys
rm -rf $GETH_CONFIGS_DIR/bootnode/* 2>/dev/null || true

# Remove the lock file
rm ${LOCK_FILE}
echo "Lock file ${LOCK_FILE} removed"
