#!/bin/bash

# Check if any port numbers are provided
if [ $# -eq 0 ]; then
	echo "Usage: $0 [port numbers...]"
	exit 1
fi

# Initialize arrays to store all PIDs and their ports
ALL_PIDS=()
PORT_MAP=()

# Loop through each provided port to collect processes
for PORT in "$@"; do
	# Find processes using the port
	PIDS=$(lsof -ti tcp:"$PORT")

	# Check if any process was found
	if [ -z "$PIDS" ]; then
		echo "No process found running on port $PORT."
		continue
	fi

	# Display the processes
	echo "Processes running on port $PORT:"
	lsof -i tcp:"$PORT"

	# Add PIDs and ports to arrays
	for PID in $PIDS; do
		ALL_PIDS+=("$PID")
		PORT_MAP+=("$PORT")
	done
done

# If we found any processes
if [ ${#ALL_PIDS[@]} -gt 0 ]; then
	# Ask for confirmation, defaulting to 'No'
	read -p "Are you sure you want to kill all these processes? (y/N) " -n 1 -r
	echo # Move to a new line

	if [[ $REPLY =~ ^[Yy]$ ]]; then
		for i in "${!ALL_PIDS[@]}"; do
			PID="${ALL_PIDS[$i]}"
			PORT="${PORT_MAP[$i]}"
			if kill -9 "$PID"; then
				echo "Killed process $PID on port $PORT"
			else
				echo "Failed to kill process $PID on port $PORT"
			fi
		done
	fi
fi
