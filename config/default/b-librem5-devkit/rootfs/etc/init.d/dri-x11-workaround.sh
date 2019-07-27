#! /bin/sh
### BEGIN INIT INFO
# Provides:          dri-x11-workaround
# Required-Start:    mountall
# Required-Stop: 
# Default-Start:     S
# Default-Stop:
# Short-Description: Remove /dev/dri/card0, it currently doesn't work and causes X11 to fail to start
# Description:
### END INIT INFO

rm -f /dev/dri/card0
