#!/bin/bash


module_options+=(
	["check_desktop,author"]="Igor Pecovnik"
	["check_desktop,ref_link"]=""
	["check_desktop,feature"]="check_desktop"
	["check_desktop,desc"]="Migrated procedures from Armbian config."
	["check_desktop,example"]="check_desktop"
	["check_desktop,status"]="Active"
	["check_desktop,doc_link"]=""
)
#
# read desktop parameters
#
function check_desktop() {

	DISPLAY_MANAGER=""
	DESKTOP_INSTALLED=""
	check_if_installed nodm && DESKTOP_INSTALLED="nodm"
	check_if_installed lightdm && DESKTOP_INSTALLED="lightdm"
	check_if_installed lightdm && DESKTOP_INSTALLED="gnome"
	[[ -n $(service lightdm status 2> /dev/null | grep -w active) ]] && DISPLAY_MANAGER="lightdm"
	[[ -n $(service nodm status 2> /dev/null | grep -w active) ]] && DISPLAY_MANAGER="nodm"
	[[ -n $(service gdm status 2> /dev/null | grep -w active) ]] && DISPLAY_MANAGER="gdm"

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
		missing_dependencies+=("$DIALOG")
	fi

	# Check if jq is available
	if ! [[ -x "$(command -v jq)" ]]; then
		missing_dependencies+=("jq")
	fi

	# If any dependencies are missing, print a combined message and exit
	if [[ ${#missing_dependencies[@]} -ne 0 ]]; then
		if is_package_manager_running; then
			apt-get -y install ${missing_dependencies[*]}
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
# Dynamically updates a JSON menu structure based on system checks.

module_options+=(
	["update_json_data,author"]="Joey Turner"
	["update_json_data,ref_link"]=""
	["update_json_data,feature"]="update_json_data"
	["update_json_data,desc"]="Update JSON data with system information"
	["update_json_data,example"]="update_json_data"
	["update_json_data,status"]="review"
	["update_json_data,doc_link"]=""

)
#
# Update JSON data with system information
update_json_data() {
	JSON_DATA=$(echo "$JSON_DATA" | jq --arg key "$1" --arg value "$2" \
		'(.menu[] | select(.id == $key).description) += " (" + $value + ")"')
}

module_options+=(
	["update_submenu_data,author"]="Joey Turner"
	["update_submenu_data,ref_link"]=""
	["update_submenu_data,feature"]="update_submenu_data"
	["update_submenu_data,desc"]="Update submenu descriptions based on conditions"
	["update_submenu_data,example"]="update_submenu_data"
	["update_submenu_data,status"]="review"
	["update_submenu_data,doc_link"]=""
)
#
# Update submenu descriptions based on conditions
update_submenu_data() {
	JSON_DATA=$(echo "$JSON_DATA" | jq --arg key "$1" --arg subkey "$2" --arg value "$3" \
		'(.menu[] | select(.id==$key).sub[] | select(.id == $subkey).description) += " (" + $value + ")"')
}



set_runtime_variables

#
# Main menu updates
update_json_data "Network" "$DEFAULT_ADAPTER"
update_json_data "Localisation" "$LANG"
update_json_data "Software" "$(see_current_apt)"

# Conditional submenu updates based on network type
if [ "$network_adapter" = "IPv6" ]; then
	update_submenu_data "Network" "N08" "IPV6"
else
	update_submenu_data "Network" "N08" "IPV4"
fi
