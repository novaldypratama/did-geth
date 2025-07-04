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

NO_LOCK_REQUIRED=true

. ../../.env
source "$(dirname "$0")/geth-common.sh"

# Build and run containers and network
echo "docker-compose-geth.yml" >${LOCK_FILE}

echo "*************************************"
echo "Geth Localnet"
echo "*************************************"
echo "Start network"
echo "--------------------"

echo "Starting network..."
# Ensure bootnode keys directory exists
mkdir -p ./network/config/geth/bootnode

# Build and pull images
docker compose -f $GETH_DOCKER_CONFIG build --pull

echo "Starting containers..."
docker compose -f $GETH_DOCKER_CONFIG up --detach

#list services and endpoints
./$(dirname "$0")/geth-list.sh
