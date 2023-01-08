#!/bin/bash

# create a FIFO file, used to manage the I/O redirection from shell
PIPE=$(mktemp -u --tmpdir ${0##*/}.XXXXXXXX)
mkfifo $PIPE

# attach a file descriptor to the file
exec 3<> $PIPE

# add handler to manage process shutdown
function on_exit() {
	echo "quitting.."
    echo "quit" >&3
    rm -f $PIPE
}
trap on_exit EXIT

# add handler for tray icon left click
function on_click() {
    echo "clicked"
    update_state
}
export -f on_click

function update_state() {
	exec 3<> $PIPE
	
	output=$(openvpn3 sessions-list)
	while IFS= read -r line; do
		if [[ $line = "No sessions available" ]]
		then
			echo "no sessions"
			echo "icon:network-error" >&3
		elif [[ $line = *"Client connected" ]]
		then
			echo "sessions found!"
			echo "icon:data-success" >&3
		fi
	done <<< "$output"
	
}

export -f update_state
export PIPE

# create the notification icon
yad --notification                  \
    --listen                        \
    --image="network-error"              \
    --text="Notification tooltip"   \
    --command="bash -c on_click" \
    --menu="connect!bash -c update_state|disconnect!bash -c 'update_state'" <&3 &
    
while true
do 
    update_state
    sleep 10
done
    

    

