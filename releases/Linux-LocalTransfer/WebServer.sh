#!/bin/bash

# chmod 777 /home/illusionna/Linux-LocalTransfer/WebServer.sh
# ln -s /home/illusionna/Linux-LocalTransfer/WebServer.sh /usr/local/bin/webserver
# webserver

script_dir=$(dirname "$(realpath "$0")")

if [ $# -eq 0 ]; then
  python3 "$script_dir/main.py"
else
  python3 "$script_dir/main.py" "$@"
fi
