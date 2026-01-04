#!/usr/bin/env bash
# Ingest log file(s) into OTLP collector
# Usage: otlp-ingest <file_or_folder> [service_name]

set -euo pipefail

# Constants
readonly DEFAULT_BATCH_SIZE=100
readonly DEFAULT_OTLP_ENDPOINT="http://localhost:4318/v1/logs"
readonly MAX_RETRIES=3
readonly CURL_TIMEOUT=30

# Configuration
INPUT_PATH="${1:-}"
SERVICE_NAME="${2:-file-import}"
OTLP_ENDPOINT="${OTLP_ENDPOINT:-$DEFAULT_OTLP_ENDPOINT}"
BATCH_SIZE="${BATCH_SIZE:-$DEFAULT_BATCH_SIZE}"

# Globals
total_lines=0
total_errors=0

# Cleanup handler (invoked via trap)
# shellcheck disable=SC2329
cleanup() {
	local exit_code=$?
	if ((exit_code != 0)) && ((total_lines > 0)); then
		echo -e "\nInterrupted. Processed $total_lines lines ($total_errors errors)." >&2
	fi
}
trap cleanup EXIT INT TERM

# Validation
[[ -z $INPUT_PATH ]] && {
	echo "Usage: otlp-ingest <file_or_folder> [service_name]"
	exit 1
}
[[ ! -e $INPUT_PATH ]] && {
	echo "Error: Path not found: $INPUT_PATH"
	exit 1
}

# Convert log severity text to OTLP severity number
sev_num() {
	case "${1^^}" in
	TRACE) echo 1 ;; DEBUG) echo 5 ;; INFO) echo 9 ;;
	WARN | WARNING) echo 13 ;; ERROR) echo 17 ;; FATAL | CRITICAL) echo 21 ;; *) echo 9 ;;
	esac
}

# Safe timestamp parsing - sanitize input to prevent injection
parse_timestamp() {
	local ts_str="$1"
	# Only allow ISO8601 characters
	if [[ $ts_str =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[T\ ][0-9]{2}:[0-9]{2}:[0-9]{2}([.,][0-9]+)?Z?$ ]]; then
		date -d "$ts_str" +%s%N 2>/dev/null || date +%s000000000
	else
		date +%s000000000
	fi
}

# Send batch with retry logic
send_batch() {
	local records="$1"
	local payload response http_code body
	local retry_count=0

	payload=$(jq -n --arg svc "$SERVICE_NAME" --argjson recs "$records" '{
        resourceLogs: [{
            resource: {attributes: [{key: "service.name", value: {stringValue: $svc}}]},
            scopeLogs: [{scope: {name: "file-import"}, logRecords: $recs}]
        }]
    }')

	while ((retry_count < MAX_RETRIES)); do
		response=$(curl --max-time "$CURL_TIMEOUT" -s -w "\n%{http_code}" \
			-X POST "$OTLP_ENDPOINT" \
			-H "Content-Type: application/json" \
			-d "$payload" 2>&1) || true

		http_code=$(echo "$response" | tail -n1)
		body=$(echo "$response" | head -n-1)

		if [[ $http_code =~ ^2[0-9]{2}$ ]]; then
			return 0
		elif [[ $http_code =~ ^5[0-9]{2}$ ]]; then
			((retry_count++))
			local wait_time=$((2 ** retry_count))
			local jitter=$((RANDOM % wait_time + 1))
			echo -ne "\r  Retry $retry_count/$MAX_RETRIES (HTTP $http_code, waiting ${jitter}s)..." >&2
			sleep "$jitter"
		else
			echo -e "\n  Error: HTTP $http_code - $body" >&2
			((++total_errors))
			return 1
		fi
	done

	echo -e "\n  Error: Max retries exceeded" >&2
	((total_errors++))
	return 1
}

# Collect files to process
FILES=()
if [[ -d $INPUT_PATH ]]; then
	while IFS= read -r -d '' file; do
		FILES+=("$file")
	done < <(find "$INPUT_PATH" -type f -name "*.log" -print0 2>/dev/null)
	[[ ${#FILES[@]} -eq 0 ]] && {
		echo "No .log files found in $INPUT_PATH"
		exit 1
	}
	echo "Found ${#FILES[@]} log file(s) in $INPUT_PATH"
else
	FILES=("$INPUT_PATH")
fi

# Process each file
for LOG_FILE in "${FILES[@]}"; do
	filename="${LOG_FILE##*/}"
	echo "Ingesting $filename as '$SERVICE_NAME'..."

	line_num=0
	record_count=0
	record_stream=""

	while IFS= read -r line || [[ -n $line ]]; do
		((++line_num))
		[[ -z $line ]] && continue

		ts=$(date +%s000000000)
		sev="INFO"
		body="$line"

		# Parse structured logs
		if [[ $line =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}[T\ ][0-9]{2}:[0-9]{2}:[0-9]{2}[.,]?[0-9]*Z?)[\ ]*\[?([A-Z]+)\]?[\ ]+(.*)$ ]]; then
			sev="${BASH_REMATCH[2]}"
			body="${BASH_REMATCH[3]}"
			ts=$(parse_timestamp "${BASH_REMATCH[1]}")
		fi

		sev_number=$(sev_num "$sev")

		# Build record and append to stream (NDJSON format - O(n) instead of O(n²))
		record=$(jq -n \
			--arg ts "$ts" \
			--arg sev "$sev" \
			--argjson sevNum "$sev_number" \
			--arg body "$body" \
			--arg file "$filename" \
			--argjson ln "$line_num" \
			'{timeUnixNano: $ts, severityNumber: $sevNum, severityText: $sev,
              body: {stringValue: $body}, attributes: [
                {key: "log.file.name", value: {stringValue: $file}},
                {key: "log.file.line", value: {intValue: $ln}}
              ]}')

		record_stream+="$record"$'\n'
		((++record_count))

		if ((line_num % BATCH_SIZE == 0)); then
			echo -ne "\r  $line_num lines..."
			records=$(echo "$record_stream" | jq -s '.')
			send_batch "$records"
			record_stream=""
			record_count=0
		fi
	done <"$LOG_FILE"

	# Send remaining records
	if ((record_count > 0)); then
		records=$(echo "$record_stream" | jq -s '.')
		send_batch "$records"
	fi

	echo -e "\r  ✓ $line_num lines"
	total_lines=$((total_lines + line_num))
done

if ((total_errors > 0)); then
	echo "Done: $total_lines lines ($total_errors errors)"
else
	echo "Done: $total_lines lines"
fi
[[ $total_errors -gt 0 ]] && exit 1
exit 0
