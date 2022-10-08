#!/bin/sh

tunnel_exists() {
    tmux has-session -t tunnel 2> /dev/null
}

if tunnel_exists; then
    HAS_TUNNEL='Y'
else
    HAS_TUNNEL='N'
    . "$(dirname "$0")/tunnel.sh"
    while ! tunnel_exists; do
        sleep 1
    done
fi

echo HAS_TUNNEL= "$HAS_TUNNEL"
xfreerdp /f /u:tbaxendale /v:127.0.0.1:5500

if [[ "$HAS_TUNNEL" = 'N' ]]; then
    tmux send-keys -t tunnel "exit"
fi

