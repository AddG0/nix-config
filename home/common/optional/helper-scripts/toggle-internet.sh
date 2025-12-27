#!/usr/bin/env bash
# Function to toggle all network services
toggle_all_services() {
	local action=$1
	echo "${action^} all network services..."
	while IFS= read -r service; do
		clean_service=${service//^\*/}
		echo "${action^} '$clean_service'..."
		if ! sudo networksetup -setnetworkserviceenabled "$clean_service" "$action"; then
			echo "Failed to ${action} '$clean_service', continuing..."
		fi
	done <<<"$2"
}

# Function to flush DNS cache and renew DHCP lease
flush_network() {
	echo "Restarting mDNSResponder..."
	if ! sudo killall -HUP mDNSResponder; then
		echo "Failed to restart mDNSResponder, continuing..."
	fi

	echo "Flushing DNS cache..."
	if ! sudo dscacheutil -flushcache; then
		echo "Failed to flush DNS cache, continuing..."
	fi
	echo "Flushing complete."

	echo "Renewing DHCP lease..."
	for service in $(networksetup -listallnetworkservices | tail -n +2 | sed 's/^\*//'); do
		if networksetup -getinfo "$service" | grep -q "DHCP"; then
			if ! sudo ipconfig set "$service" DHCP; then
				echo "Failed to renew DHCP lease for '$service', continuing..."
			fi
		fi
	done
	echo "DHCP lease renewed."
}

# Get all network services and remove asterisks
SERVICES=$(networksetup -listallnetworkservices | tail -n +2 | sed 's/^\*//')

echo "$(date): Internet appears down, toggling network services."
# Disable all services
toggle_all_services off "$SERVICES"

# Flush DNS cache and renew DHCP lease
flush_network

# Enable all services
toggle_all_services on "$SERVICES"
