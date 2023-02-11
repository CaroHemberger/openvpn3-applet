#!/bin/bash

CONFIG_DIR=~/.openvpn-applet
CONFIG_FILE_PATH=$CONFIG_DIR/config
sleepTime=10

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

function selectAndSaveConfigfile() {
	configfile=$(yad --width="500" --center --title="Select config file" --text="\nPlease select your openvpn3 config file:\n" --file --file-filter="*.ovpn")
	# create directory in case it does not exist
	mkdir -p $CONFIG_DIR
	echo "OPENVPN_CONFIG_PATH="$configfile > $CONFIG_FILE_PATH
	OPENVPN_CONFIG_PATH=$configfile
}
export -f selectAndSaveConfigfile

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

if [[ -z $OPENVPN_CONFIG_PATH ]]
then
	selectAndSaveConfigfile
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
	echo $(date) " | " "quitting.."
    echo "quit" >&3
    rm -f $PIPE
}
trap on_exit EXIT
export -f on_exit

# add handler for tray icon left click
function on_click() {
    update_state
}
export -f on_click

function disconnect() {
	echo $(date) " | " "disconnecting.."
	exec 3<> $PIPE
	echo "icon:$RUNNING_DIR/icons/circle-lightblue.png" >&3
    sessionPath=$(openvpn3 sessions-list | grep Path | awk ' { print $2 } ')
    openvpn3 session-manage --disconnect --session-path $sessionPath
    update_state
    echo $(date) " | " "disconnected."
}
export -f disconnect

function connect() {
	echo $(date) " | " "connecting..."
	exec 3<> $PIPE
	echo "icon:$RUNNING_DIR/icons/circle-lightblue.png" >&3
    openvpn3 session-start --config $OPENVPN_CONFIG_PATH
    update_state
    echo $(date) " | " "connected."
}
export -f connect

function update_state() {
	exec 3<> $PIPE
	defaultMenuEntries="|Select config!bash -c 'selectAndSaveConfigfile'|Exit!bash -c 'on_exit"
	statEntry="|Stats!bash -c 'display_session_stats'"
	
	detectedState=false
	output=$(openvpn3 sessions-list)
	while IFS= read -r line; do
		if [[ $line = "No sessions available" || $line = *"Client authentication failed: Authentication failed" ]]
		then
			echo $(date) " | " "Not connected"
			echo "icon:$RUNNING_DIR/icons/circle-red.png" >&3
			echo "menu:Connect!bash -c 'connect'" $defaultMenuEntries >&3
			echo "tooltip:Not connected" >&3
			detectedState=true
		elif [[ $line = *"Client connected" ]]
		then
			echo $(date) " | " "Session found!"
			echo "icon:$RUNNING_DIR/icons/circle-green.png" >&3
			echo "menu:Disconnect!bash -c 'disconnect''" $statEntry $defaultMenuEntries >&3
			echo "tooltip:Connected to VPN" >&3
			detectedState=true
		elif [[ $line = *"Web authentication required to connect" ]]
		then
			echo $(date) " | " "Waiting for web authentication"
			echo "icon:$RUNNING_DIR/icons/circle-lightblue.png" >&3
			echo "menu:Disconnect!bash -c 'disconnect'" $statEntry $defaultMenuEntries >&3
			echo "tooltip:Waiting for Web authentiction (check webbrowser)" >&3
			detectedState=true
		fi
	done <<< "$output"
	
	# failsafe for unknown states
	if [[ $detectedState = false ]]
	then
		echo $(date) " | " "Unknown state"
		echo "icon:$RUNNING_DIR/icons/circle-red.png" >&3
		echo "menu:Connect!bash -c 'connect'" $defaultMenuEntries >&3
		echo "tooltip:Not connected" >&3
	fi
	
}
export -f update_state

function display_session_stats() {
	sessionPath=$(openvpn3 sessions-list | grep Path | awk ' { print $2 } ')
	output=$(openvpn3 session-stats -o $sessionPath)
	yad --width=500 --title="session-stats" --text="$output" --center --button="Close"
}
export -f display_session_stats

export PIPE
export RUNNING_DIR
export OPENVPN_CONFIG_PATH
export CONFIG_DIR
export CONFIG_FILE_PATH

# create the notification icon
yad --notification                  \
    --listen                        \
    --image="${BASH_SOURCE%/*}/icons/circle-red.png"  \
    --text="openvpn3-applet"        \
    --command="bash -c 'on_click'"   <&3 & notifpid=$!
    
echo $(date) " | " "created"

    
while true
do 
	if ! ps -p $notifpid > /dev/null
	then
		# exit if yad process has been terminated
		exit
	fi
    update_state
    sleep $sleepTime
done
    

    

