#!/bin/sh
# Copyright 2025 Timothy Baxendale (pcluddite@outlook.com)

TIMS_NEWDESKTOP=192.168.0.15
tmux new -ds tunnel ssh -L 5500:$TIMS_NEWDESKTOP:3389 -L 8443:192.168.0.1:443 -L 9090:192.168.0.10:9090 minecraft.timbaxendale.com -p9022
