#! /bin/bash

YAD_OPTIONS="--window-icon='dialog-information' --name=IxSysinfo"

KEY=$RANDOM


# main dialog
TXT="<b>Current sessions:</b>\\n\\n"
TXT+="$(openvpn3 sessions-list)\\n"

yad --notebook --width=800 --height=450 --title="System info" --text="$TXT" --button=Close \
    --key=$KEY
