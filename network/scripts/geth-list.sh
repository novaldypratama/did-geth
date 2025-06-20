#!/bin/bash -eu

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

# shellcheck disable=SC1090
source "$(dirname "${BASH_SOURCE[0]}")/../../.env"
# shellcheck disable=SC1090
source "$(dirname "${BASH_SOURCE[0]}")/geth-common.sh"

readonly HOST="${DOCKER_PORT_2375_TCP_ADDR:-localhost}"
readonly BOOTNODE_URL="http://${HOST}:30301"
readonly GRAFANA_URL="http://${HOST}:3000/d/a1lVy7ycin9Yv/geth-overview?orgId=1&refresh=10s&from=now-30m&to=now&var-system=All"

print_header() {
  echo "*************************************"
  echo "Geth Localnet"
  echo "*************************************"
  echo
  echo "----------------------------------"
  echo "List endpoints and services"
  echo "----------------------------------"
}

print_endpoints() {
  echo "JSON-RPC HTTP service endpoint                 : http://${HOST}:8545"
  echo "JSON-RPC WebSocket service endpoint            : ws://${HOST}:8546"
  echo "Bootnode discovery endpoint                    : ${BOOTNODE_URL}"

  # Print validator endpoints
  echo "Validator 1 RPC endpoint                       : http://${HOST}:21001"
  echo "Validator 2 RPC endpoint                       : http://${HOST}:21002"
  echo "Validator 3 RPC endpoint                       : http://${HOST}:21003"
  echo "Validator 4 RPC endpoint                       : http://${HOST}:21004"
}

check_prometheus() {
  if docker compose -f $GETH_DOCKER_CONFIG ps -q prometheus &>/dev/null; then
    echo "Prometheus address                             : http://${HOST}:9090/graph"
  fi
}

check_grafana() {
  if docker compose -f $GETH_DOCKER_CONFIG ps -q grafana &>/dev/null; then
    echo "Grafana address                                : ${GRAFANA_URL}"
  fi
}

print_footer() {
  echo
  echo "For more information on the endpoints and services, refer to README.md in the installation directory."
  echo "****************************************************************"
}

main() {
  print_header
  print_endpoints
  check_prometheus
  check_grafana
  print_footer
}

main "$@"
