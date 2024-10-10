#!/bin/bash


module_options+=(
	["check_if_installed,author"]="Igor Pecovnik"
	["check_if_installed,ref_link"]=""
	["check_if_installed,feature"]="check_if_installed"
	["check_if_installed,desc"]="Migrated procedures from Armbian config."
	["check_if_installed,example"]="check_if_installed nano"
	["check_if_installed,status"]="Active"
)
#
# check dpkg status of $1 -- currently only 'not installed at all' case caught
#
function check_if_installed() {

	local DPKG_Status="$(dpkg -s "$1" 2> /dev/null | awk -F": " '/^Status/ {print $2}')"
	if [[ "X${DPKG_Status}" = "X" || "${DPKG_Status}" = *deinstall* || "${DPKG_Status}" = *not-installed* ]]; then
		return 1
	else
		return 0
	fi

}

module_options+=(
	["is_package_manager_running,author"]="Igor Pecovnik"
	["is_package_manager_running,ref_link"]=""
	["is_package_manager_running,feature"]="is_package_manager_running"
	["is_package_manager_running,desc"]="Migrated procedures from Armbian config."
	["is_package_manager_running,example"]="is_package_manager_running"
	["is_package_manager_running,status"]="Active"
)
#
# check if package manager is doing something
#
function is_package_manager_running() {

	if ps -C apt-get,apt,dpkg > /dev/null; then
		[[ -z $scripted ]] && echo -e "\nPackage manager is running in the background. \n\nCan't install dependencies. Try again later." | show_infobox
		return 0
	else
		return 1
	fi

}

module_options+=(
	["set_runtime_variables,author"]="Igor Pecovnik"
	["set_runtime_variables,ref_link"]=""
	["set_runtime_variables,feature"]="set_runtime_variables"
	["set_runtime_variables,desc"]="Run time variables Migrated procedures from Armbian config."
	["set_runtime_variables,example"]="set_runtime_variables"
	["set_runtime_variables,status"]="Active"
)
#
# gather info about the board and start with loading menu variables
#
function set_runtime_variables() {

	missing_dependencies=()

	# Check if whiptail is available and set DIALOG
	if [[ -z "$DIALOG" ]]; then
		missing_dependencies+=("whiptail")
	fi

	# Check if jq is available
	if ! [[ -x "$(command -v jq)" ]]; then
		missing_dependencies+=("jq")
	fi

	# If any dependencies are missing, print a combined message and exit
	if [[ ${#missing_dependencies[@]} -ne 0 ]]; then
		if is_package_manager_running; then
			sudo apt install ${missing_dependencies[*]}
		fi
	fi

	# Determine which network renderer is in use for NetPlan
	if systemctl is-active systemd-networkd 1> /dev/null; then
		renderer=networkd
	else
		renderer=NetworkManager
	fi

	DIALOG_CANCEL=1
	DIALOG_ESC=255

	# we have our own lsb_release which does not use Python. Others shell install it here
	if [[ ! -f /usr/bin/lsb_release ]]; then
		if is_package_manager_running; then
			sleep 3
		fi
		debconf-apt-progress -- apt-get update
		debconf-apt-progress -- apt -y -qq --allow-downgrades --no-install-recommends install lsb-release
	fi

	[[ -f /etc/armbian-release ]] && source /etc/armbian-release && ARMBIAN="Armbian $VERSION $IMAGE_TYPE"
	DISTRO=$(lsb_release -is)
	DISTROID=$(lsb_release -sc)
	KERNELID=$(uname -r)
	[[ -z "${ARMBIAN// /}" ]] && ARMBIAN="$DISTRO $DISTROID"
	DEFAULT_ADAPTER=$(ip -4 route ls | grep default | tail -1 | grep -Po '(?<=dev )(\S+)')
	LOCALIPADD=$(ip -4 addr show dev $DEFAULT_ADAPTER | awk '/inet/ {print $2}' | cut -d'/' -f1)
	BACKTITLE="Contribute: https://github.com/armbian/configng"
	TITLE="Armbian configuration utility"
	[[ -z "${DEFAULT_ADAPTER// /}" ]] && DEFAULT_ADAPTER="lo"

	# detect desktop
	check_desktop

}


module_options+=(
	["see_current_apt,author"]="Joey Turner"
	["see_current_apt,ref_link"]=""
	["see_current_apt,feature"]="see_current_apt"
	["see_current_apt,desc"]="Check when apt list was last updated and suggest updating or update"
	["see_current_apt,example"]="see_current_apt || see_current_apt update"
	["see_current_apt,doc_link"]=""
	["see_current_apt,status"]="Active"
)
#
# Function to check when the package list was last updated
#
see_current_apt() {
	# Number of seconds in a day
	local update_apt="$1"
	local day=86400
	local ten_minutes=600
	# Get the current date as a Unix timestamp
	local now=$(date +%s)

	# Get the timestamp of the most recently updated file in /var/lib/apt/lists/
	local update=$(stat -c %Y /var/lib/apt/lists/* 2>/dev/null | sort -n | tail -1)

	# Check if the update timestamp was found
	if [[ -z "$update" ]]; then
		echo "No package lists found."
		return 1 # No package lists exist
	fi

	# Calculate the number of seconds since the last update
	local elapsed=$((now - update))

	# Check if any apt-related processes are running
	if ps -C apt-get,apt,dpkg > /dev/null; then
		echo "A package manager is currently running."
		export running_pkg="true"
		return 1 # The processes are running
	else
		export running_pkg="false"
	fi

	# Check if the package list is up-to-date
	if ((elapsed < ten_minutes)); then
		[[ "$update_apt" != "update" ]] && echo "The package lists are up-to-date."
		return 0 # The package lists are up-to-date
	else
		[[ "$update_apt" != "update" ]] && echo "Update the package lists." # Suggest updating
		[[ "$update_apt" == "update" ]] && debconf-apt-progress apt-get update
		return 0 # The package lists are not up-to-date
	fi
}

