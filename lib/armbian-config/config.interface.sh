#!/bin/bash

# Start of config interface


module_options+=(
	["see_cmd_list,author"]="Tearran"
	["see_cmd_list,ref_link"]="unused"
	["see_cmd_list,feature"]="see_cmd_list"
	["see_cmd_list,desc"]="Generate a Help message for cli commands."
	["see_cmd_list,example"]="see_cmd_list [catagory]"
	["see_cmd_list,status"]="unused"
	["see_cmd_list,doc_link"]="unused"
)
#
# See command options
#
see_cmd_list() {
	local help_menu="$1"

	if [[ -n "$help_menu" && "$help_menu" != "cmd" ]]; then
		echo "$JSON_DATA" | jq -r --arg menu "$help_menu" '
		def recurse_menu(menu; level):
		menu | .id as $id | .description as $desc |
		if has("sub") then
			if level == 0 then
				"\n  \($id) - \($desc)\n" + (.sub | map(recurse_menu(. ; level + 1)) | join("\n"))
			elif level == 1 then
				"    \($id) - \($desc)\n" + (.sub | map(recurse_menu(. ; level + 1)) | join("\n"))
			else
				"      \($id) - \($desc)\n" + (.sub | map(recurse_menu(. ; level + 1)) | join("\n"))
			end
		else
			if level == 0 then
				"  --cmd \($id) - \($desc)"
			elif level == 1 then
				"    --cmd \($id) - \($desc)"
			else
				"\t--cmd \($id) - \($desc)"
			end
		end;

		# Find the correct menu if $menu is passed, otherwise show all
		if $menu == "" then
			.menu | map(recurse_menu(. ; 0)) | join("\n")
		else
			.menu | map(select(.id == $menu) | recurse_menu(. ; 0)) | join("\n")
		end
		'
	elif [[ -z "$1" || "$1" == "cmd" ]]; then
		echo "$JSON_DATA" | jq -r --arg menu "$help_menu" '
		def recurse_menu(menu; level):
		menu | .id as $id | .description as $desc |
		if has("sub") then
			if level == 0 then
				"\n  \($id) - \($desc)\n" + (.sub | map(recurse_menu(. ; level + 1)) | join("\n"))
			elif level == 1 then
				"    \($id) - \($desc)\n" + (.sub | map(recurse_menu(. ; level + 1)) | join("\n"))
			else
				"      \($id) - \($desc)\n" + (.sub | map(recurse_menu(. ; level + 1)) | join("\n"))
			end
		else
			if level == 0 then
				"  --cmd \($id) - \($desc)"
			elif level == 1 then
				"    --cmd \($id) - \($desc)"
			else
				"\t--cmd \($id) - \($desc)"
			end
		end;
		.menu | map(recurse_menu(. ; 0)) | join("\n")
		'

	else
		echo "nope"
	fi
}

module_options+=(
	["see_use,author"]="Joey Turner"
	["see_use,ref_link"]=""
	["see_use,feature"]="see_use"
	["see_use,desc"]="Show the usage of the functions."
	["see_use,example"]="see_use"
	["see_use,status"]="review"
	["see_use,doc_link"]=""
)
#
# Function to parse the key-pairs  (WIP)
#
function see_api_list() {
	mod_message="Usage: \n\n"
	# Iterate over the options
	for key in "${!module_options[@]}"; do
		# Split the key into function_name and type
		IFS=',' read -r function_name type <<< "$key"
		# If the type is 'long', append the option to the help message
		if [[ "$type" == "feature" ]]; then
			mod_message+="${module_options["$function_name,feature"]} - ${module_options["$function_name,desc"]}\n"
			mod_message+="  ${module_options["$function_name,example"]}\n\n"
		fi
	done

	echo -e "$mod_message"
}

module_options+=(
	["parse_menu_items,author"]="Gunjan Gupta"
	["parse_menu_items,ref_link"]=""
	["parse_menu_items,feature"]="parse_menu_items"
	["parse_menu_items,desc"]="Parse json to get list of desired menu or submenu items"
	["parse_menu_items,example"]="parse_menu_items 'menu_options_array'"
	["parse_menu_items,doc_link"]=""
	["parse_menu_items,status"]="Active"
)
#
# Function to parse the menu items
#
parse_menu_items() {
	local -n options=$1
	while IFS= read -r id; do
		IFS= read -r description
		IFS= read -r condition
		# If the condition field is not empty and not null, run the function specified in the condition
		if [[ -n $condition && $condition != "null" ]]; then
			# If the function returns a truthy value, add the menu item to the menu
			if eval $condition; then
				options+=("$id" "  -  $description")
			fi
		else
			# If the condition field is empty or null, add the menu item to the menu
			options+=("$id" "  -  $description ")
		fi
	done < <(echo "$JSON_DATA" | jq -r '.menu[] | '${parent_id:+".. | objects | select(.id==\"$parent_id\") | .sub[]? |"}' select(.status != "Disabled") | "\(.id)\n\(.description)\n\(.condition)"' || exit 1)
}

module_options+=(
	["generate_top_menu,author"]="Tearran"
	["generate_top_menu,ref_link"]="unused"
	["generate_top_menu,feature"]="generate_top_menu"
	["generate_top_menu,desc"]="Build the main menu from a object"
	["generate_top_menu,example"]="generate_top_menu 'json_data'"
	["generate_top_menu,doc_link"]="unused"
	["generate_top_menu,status"]="unused"
)
#
# Function to generate the main menu from a JSON object
#
generate_top_menu() {
	local json_data="$1"
	local status="$ARMBIAN $KERNELID ($DISTRO $DISTROID)"
	local backtitle="$BACKTITLE"


	while true; do
		local menu_options=()

		parse_menu_items menu_options

		local OPTION=$($DIALOG --backtitle "$backtitle" --title "$TITLE" --menu "$status" 0 80 9 "${menu_options[@]}" \
			--ok-button Select --cancel-button Exit 3>&1 1>&2 2>&3)
		local exitstatus=$?

		if [ $exitstatus = 0 ]; then
			[ -z "$OPTION" ] && break
			[ "$OPTION" != "Help" ] && generate_menu "$OPTION" ;
			[ "$OPTION" == "Help" ] && execute_command "$OPTION" ;
		fi
	done
}

module_options+=(
	["generate_menu,author"]="Tearran"
	["generate_menu,ref_link"]="unused"
	["generate_menu,feature"]="generate_menu"
	["generate_menu,desc"]="Generate a submenu from a parent_id"
	["generate_menu,example"]="generate_menu 'parent_id'"
	["generate_menu,doc_link"]="unused"
	["generate_menu,status"]="unused"
)
#
# Function to generate the submenu
#
function generate_menu() {
	local parent_id="$1"
	local top_parent_id="$2"
	local backtitle="$BACKTITLE"
	local status=""

	while true; do
		# Get the submenu options for the current parent_id
		local submenu_options=()
		parse_menu_items submenu_options

		local OPTION=$($DIALOG --backtitle "$BACKTITLE" --title "$top_parent_id $parent_id" --menu "$status" 0 80 9 "${submenu_options[@]}" \
			--ok-button Select --cancel-button Back 3>&1 1>&2 2>&3)

		local exitstatus=$?

		if [ $exitstatus = 0 ]; then
			[ -z "$OPTION" ] && break

			# Check if the selected option has a submenu
			local submenu_count=$(echo "$JSON_DATA" |jq -r --arg id "$OPTION" '.menu[] | .. | objects | select(.id==$id) | .sub? | length')
			submenu_count=${submenu_count:-0} # If submenu_count is null or empty, set it to 0
			if [ "$submenu_count" -gt 0 ]; then
				# If it does, generate a new menu for the submenu
				[[ -n "$debug" ]] && echo "$OPTION"
				generate_menu "$OPTION" "$parent_id"
			else
				# If it doesn't, execute the command
				[[ -n "$debug" ]] && echo "$OPTION"
				execute_command "$OPTION"
			fi
		fi
	done
}

module_options+=(
	["execute_command,author"]="Tearran"
	["execute_command,ref_link"]="unused"
	["execute_command,feature"]="execute_command"
	["execute_command,desc"]="Needed by generate_menu"
	["execute_command,example"]="See generate_menu"
	["execute_command,doc_link"]="unused"
	["execute_command,status"]="unused"
)
#
# Function to execute the command
#
function execute_command() {
	local id=$1

	# Extract commands
	local commands=$(jq -r --arg id "$id" '
		.menu[] |
		.. |
		objects |
		select(.id == $id) |
		.command[]?' "$json_file")

	# Check if a prompt exists
	local prompt=$(jq -r --arg id "$id" '
		.menu[] |
		.. |
		objects |
		select(.id == $id) |
		.prompt?' "$json_file")

	# If a prompt exists, display it and wait for user confirmation
	if [[ "$prompt" != "null" && $INPUTMODE != "cmd" ]]; then
		get_user_continue "$prompt" process_input
	fi

	# Execute each command
	for command in "${commands[@]}"; do
		[[ -n "$debug" ]] && echo "$command"
		eval "$command"
	done
}

module_options+=(
	["show_message,author"]="Tearran"
	["show_message,ref_link"]="unused"
	["show_message,feature"]="show_message"
	["show_message,desc"]="Display a message box"
	["show_message,example"]="show_message <<< 'hello world' "
	["show_message,doc_link"]="unused"
	["show_message,status"]="unused"
)
#
# Function to display a message box
#
function show_message() {
	# Read the input from the pipe
	input=$(cat)

	# Display the "OK" message box with the input data
	if [[ $DIALOG != "bash" ]]; then
		$DIALOG --title "$TITLE" --msgbox "$input" 0 0
	else
		echo -e "$input"
		read -p -r "Press [Enter] to continue..."
	fi
}

module_options+=(
	["show_infobox,author"]="Tearran"
	["show_infobox,ref_link"]="unused"
	["show_infobox,feature"]="show_infobox"
	["show_infobox,desc"]="pipeline strings to an infobox "
	["show_infobox,example"]="show_infobox <<< 'hello world' ; "
	["show_infobox,doc_link"]="unused"
	["show_infobox,status"]="unused"
)
#
# Function to display an infobox with a message
#
function show_infobox() {
	export TERM=ansi
	local input
	local BACKTITLE="$BACKTITLE"
	local -a buffer # Declare buffer as an array
	if [ -p /dev/stdin ]; then
		while IFS= read -r line; do
			buffer+=("$line") # Add the line to the buffer
			# If the buffer has more than 10 lines, remove the oldest line
			if ((${#buffer[@]} > 18)); then
				buffer=("${buffer[@]:1}")
			fi
			# Display the lines in the buffer in the infobox

			TERM=ansi $DIALOG --title "$TITLE" --infobox "$(printf "%s\n" "${buffer[@]}")" 16 90
			sleep 0.5
		done
	else

		input="$1"
		TERM=ansi $DIALOG --title "$TITLE" --infobox "$input" 6 80
	fi
	echo -ne '\033[3J' # clear the screen
}

module_options+=(
	["show_menu,author"]="Tearran"
	["show_menu,ref_link"]="unused"
	["show_menu,feature"]="show_menu"
	["show_menu,desc"]="Display a menu from pipe"
	["show_menu,example"]="show_menu <<< armbianmonitor -h  ; "
	["show_menu,doc_link"]="unused"
	["show_menu,status"]="unused"
)
#
#
#
show_menu() {

	# Get the input and convert it into an array of options
	inpu_raw=$(cat)
	# Remove the lines before -h
	input=$(echo "$inpu_raw" | sed 's/-\([a-zA-Z]\)/\1/' | grep '^  [a-zA-Z] ' | grep -v '\[')
	options=()
	while read -r line; do
		package=$(echo "$line" | awk '{print $1}')
		description=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^ *//')
		options+=("$package" "$description")
	done <<< "$input"

	# Display the menu and get the user's choice
	[[ $DIALOG != "bash" ]] && choice=$($DIALOG --title "$TITLE" --menu "Choose an option:" 0 0 9 "${options[@]}" 3>&1 1>&2 2>&3)

	# Check if the user made a choice
	if [ $? -eq 0 ]; then
		echo "$choice"
	else
		exit 0
	fi

}

menu_options+=(
	["get_user_continue,author"]="Tearran"
	["get_user_continue,ref_link"]="unused"
	["get_user_continue,feature"]="process_input"
	["get_user_continue,desc"]="used to process the user's choice paired with get_user_continue"
	["get_user_continue,example"]="get_user_continue 'Do you wish to continue?' process_input"
	["get_user_continue,status"]="unused"
	["get_user_continue,doc_link"]="unused"
)
#
# Function to process the user's choice paired with get_user_continue
#
function process_input() {
	local input="$1"
	if [ "$input" = "No" ]; then
		exit 1
	fi
}

module_options+=(
	["get_user_continue_secure,author"]="Tearran"
	["get_user_continue_secure,ref_link"]="unused"
	["get_user_continue_secure,feature"]="get_user_continue"
	["get_user_continue_secure,desc"]="Yes/no to continue"
	["get_user_continue_secure,example"]="get_user_continue '<continue. message>' process_input"
	["get_user_continue_secure,doc_link"]="unused"
	["get_user_continue_secure,status"]="unused"
)
#
# Secure version of get_user_continue
#
function get_user_continue() {
	local message="$1"
	local next_action="$2"

	# Define a list of allowed functions
	local allowed_functions=("process_input" "other_function")
	# Check if the next_action is in the list of allowed functions
	found=0
	for func in "${allowed_functions[@]}"; do
		if [[ "$func" == "$next_action" ]]; then
			found=1
			break
		fi
	done

	if [[ "$found" -eq 1 ]]; then
		if $($DIALOG --yesno "$message" 10 80 3>&1 1>&2 2>&3); then
			$next_action
		else
			$next_action "No"
		fi
	else
		echo "Error: Invalid function"

		exit 1
	fi
}


module_options+=(
	["sanitize_input,author"]="Tearran"
	["sanitize_input,ref_link"]="unused"
	["sanitize_input,feature"]="sanitize_input"
	["sanitize_input,desc"]="sanitize input cli"
	["sanitize_input,example"]="sanitize_input"
	["sanitize_input,status"]="unused"
	["sanitize_input,doc_link"]="unused"
)
#
# sanitize input cli
#
sanitize_input() {
	local sanitized_input=()
	for arg in "$@"; do
		if [[ $arg =~ ^[a-zA-Z0-9_=]+$ ]]; then
			sanitized_input+=("$arg")
		else
			echo "Invalid argument: $arg"
			exit 1
		fi
	done
	echo "${sanitized_input[@]}"
}
