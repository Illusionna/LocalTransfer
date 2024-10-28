#!/bin/bash

# chmod 777 /Users/illusionna/Desktop/macOS-LocalTransfer/WebServer.sh
# ln -s /Users/illusionna/Desktop/macOS-LocalTransfer/WebServer.sh /usr/local/bin/webserver
# webserver -lru 36 -max 1GB

script_dir=$(dirname "$(realpath "$0")")

if [ $# -eq 0 ]; then
  python3 "$script_dir/main.py"
else
  python3 "$script_dir/main.py" "$@"
fi
