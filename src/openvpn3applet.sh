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

CONFIG_DIR=~/.openvpn-applet
CONFIG_FILE_PATH=$CONFIG_DIR/config

sleepTime=10

while getopts s:h flag
do
    case "${flag}" in
        s) sleepTime=${OPTARG};;
        h) displayHelp
		   exit;;
    esac
done

# check if there is a saved vpn config file, if not, ask for one and save it
if [ -f "$CONFIG_FILE_PATH" ]
then
	source $CONFIG_FILE_PATH
fi

if [[ -z $CONFIG_PATH ]]
then
	configfile=$(yad --file)
	# create directory in case it does not exist
	mkdir -p $CONFIG_DIR
	echo "CONFIG_PATH="$configfile > $CONFIG_FILE_PATH
	CONFIG_PATH=$configfile
fi


# create a FIFO file, used to manage the I/O redirection from shell
PIPE=$(mktemp -u --tmpdir ${0##*/}.XXXXXXXX)
mkfifo $PIPE

# attach a file descriptor to the file
exec 3<> $PIPE

RUNNING_DIR=${BASH_SOURCE%/*}

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
    update_state
}
export -f on_click

function disconnect() {
	echo "disconnecting.."
	exec 3<> $PIPE
	echo "icon:$RUNNING_DIR/icons/circle-lightblue.png" >&3
    sessionPath=$(openvpn3 sessions-list | grep Path | awk ' { print $2 } ')
    openvpn3 session-manage --disconnect --session-path $sessionPath
    update_state
    echo "disconnected."
}
export -f disconnect

function connect() {
	echo "connecting..."
	exec 3<> $PIPE
	echo "icon:$RUNNING_DIR/icons/circle-lightblue.png" >&3
    openvpn3 session-start --config $CONFIG_PATH
    update_state
    echo "connected."
}
export -f connect

function update_state() {
	exec 3<> $PIPE
	
	output=$(openvpn3 sessions-list)
	while IFS= read -r line; do
		if [[ $line = "No sessions available" ]]
		then
			echo "no sessions"
			echo "icon:$RUNNING_DIR/icons/circle-red.png" >&3
			echo "menu:Connect!bash -c 'connect'|Exit!exit 0" >&3
			echo "tooltip:Not connected" >&3
		elif [[ $line = *"Client connected" ]]
		then
			echo "sessions found!"
			echo "icon:$RUNNING_DIR/icons/circle-green.png" >&3
			echo "menu:Disconnect!bash -c 'disconnect'|Exit!exit 0" >&3
			echo "tooltip:Connected to VPN" >&3
		fi
	done <<< "$output"
	
}


export -f update_state
export PIPE
export RUNNING_DIR
export CONFIG_PATH


# create the notification icon
yad --notification                  \
    --listen                        \
    --image="${BASH_SOURCE%/*}/icons/circle-red.png"  \
    --text="openvpn3-applet"        \
    --command="bash -c 'on_click'"   <&3 &
    
while true
do 
    update_state
    sleep $sleepTime
done
    

    

