#!/bin/sh
TIMS_NEWDESKTOP=192.168.0.160
tmux new -ds tunnel ssh -L 5500:$TIMS_NEWDESKTOP:3389 -L 8888:192.168.0.1:80 minecraft.timbaxendale.com -p9022
