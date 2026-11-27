#!/bin/bash
# This fork publishes its maintained code on master.
set -o pipefail
curl -fsSL https://raw.githubusercontent.com/huabanmao168-one/mdserver-web/master/scripts/update.sh | bash
