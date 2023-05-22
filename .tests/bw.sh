#!/bin/bash

. ./.tests/utils.sh

echo "ℹ️ Pulling repo ..."
CHANGE_DIR="/tmp" do_and_check_cmd git clone https://github.com/bunkerity/bunkerweb.git

echo "ℹ️ Checkout branch ..."
CHANGE_DIR="/tmp/bunkerweb" do_and_check_cmd git checkout $1

echo "ℹ️ Build BW ..."
CHANGE_DIR="/tmp/bunkerweb" do_and_check_cmd docker build -t bunkerweb:tests -f src/bw/Dockerfile .

echo "ℹ️ Build scheduler ..."
CHANGE_DIR="/tmp/bunkerweb" do_and_check_cmd docker build -t bw-scheduler:tests -f src/scheduler/Dockerfile .

echo "ℹ️ Images built"