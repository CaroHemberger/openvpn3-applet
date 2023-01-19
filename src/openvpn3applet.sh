#!/bin/bash

################################################################################
# Help                                                                         #
################################################################################
function displayHelp()
{
   # Display Help
   echo "Helper to display openvpn3 connection state."
   echo
   echo "Syntax: ./openvpn3applet.sh [-g|h|v|V]"
   echo "options:"
   echo "-s [seconds]     Time between state refresh in seconds, default: 10"
   echo "-h     Print this Help."
   echo
}

sleepTime=10

while getopts s:h flag
do
    case "${flag}" in
        s) sleepTime=${OPTARG};;
        h) displayHelp
		   exit;;
    esac
done

# create a FIFO file, used to manage the I/O redirection from shell
PIPE=$(mktemp -u --tmpdir ${0##*/}.XXXXXXXX)
mkfifo $PIPE

# attach a file descriptor to the file
exec 3<> $PIPE

# add handler to manage process shutdown
function on_exit() {
	exec 3<> $PIPE
	echo "quitting.."
    echo "quit" >&3
    rm -f $PIPE
}
trap on_exit EXIT

# add handler for tray icon left click
function on_click() {
    update_state $1
}
export -f on_click

function disconnect() {
	exec 3<> $PIPE
	echo "icon:$1/icons/circle-lightblue.png" >&3
    sessionPath=$(openvpn3 sessions-list | grep Path | awk ' { print $2 } ')
    openvpn3 session-manage --disconnect --session-path $sessionPath
    update_state $1
}
export -f disconnect

function connect() {
	exec 3<> $PIPE
	echo "icon:$1/icons/circle-lightblue.png" >&3
	configfile=$(yad --file)
    openvpn3 session-start --config $configfile
    update_state $1
}
export -f connect

function update_state() {
	exec 3<> $PIPE
	bashSource=$1
	
	output=$(openvpn3 sessions-list)
	while IFS= read -r line; do
		if [[ $line = "No sessions available" ]]
		then
			echo "no sessions"
			echo "icon:$bashSource/icons/circle-red.png" >&3
			echo "tooltip:Not connected" >&3
		elif [[ $line = *"Client connected" ]]
		then
			echo "sessions found!"
			echo "icon:$bashSource/icons/circle-green.png" >&3
			echo "tooltip:Connected to VPN" >&3
		fi
	done <<< "$output"
	
}

export -f update_state
export PIPE

# create the notification icon
yad --notification                  \
    --listen                        \
    --image="${BASH_SOURCE%/*}/icons/circle-red.png"  \
    --text="openvpn3-applet"        \
    --command="bash -c 'on_click ${BASH_SOURCE%/*}'"   \
    --menu="List sessions!${BASH_SOURCE%/*}/list-sessions.sh|Connect!bash -c 'connect ${BASH_SOURCE%/*}'|Disconnect!bash -c 'disconnect ${BASH_SOURCE%/*}'|Exit!exit 0" <&3 & notifpid=$!
    
while true
do 
echo "notify: " $notifpid
    update_state ${BASH_SOURCE%/*}
    sleep $sleepTime
done
    

    

