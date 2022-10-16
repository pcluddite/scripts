#!/bin/sh
TIMS_NEWDESKTOP=192.168.0.37
tmux new -ds tunnel ssh -L 5500:$TIMS_NEWDESKTOP:5900 minecraft.timbaxendale.com -p9022
