#!/bin/bash

# Ensure required tools are installed
for cmd in nomad fzf jq; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is not installed." >&2
        exit 1
    fi
done

# Default values
NOMAD_ADDR=${NOMAD_ADDR:-"http://127.0.0.1:4646"}
VERBOSE=0

# Print usage information
usage() {
    echo "Usage: $0 [--address=<addr>] [--verbose] [--help]"
    echo "Options:"
    echo "  --address=<addr>  Specify the Nomad server address"
    echo "  --verbose         Enable verbose mode"
    echo "  --help            Show this help message"
    exit 0
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --address=*) NOMAD_ADDR="${1#*=}"; shift ;;
        --verbose) VERBOSE=1; shift ;;
        --help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
done

# Warn if using default localhost address
if [ "$NOMAD_ADDR" == "http://127.0.0.1:4646" ]; then
    echo "Warning: Using default address http://127.0.0.1:4646"
fi

# Verbose logging function
log() {
    if [ "$VERBOSE" -eq 1 ]; then
        echo "$@"
    fi
}

# Fetch all active allocations and present them for selection using fzf
alloc_id=$(nomad alloc status -address="$NOMAD_ADDR" -json | jq -r '.[] | select(.ClientStatus == "running") | "\(.JobID) \(.ID)"' | fzf --prompt="Select Job: " --with-nth=1 | awk '{print $2}')

# Check if an allocation was selected
if [ -z "$alloc_id" ]; then
    echo "No allocation selected."
    exit 1
fi

log "Selected allocation ID: $alloc_id"

# Fetch the tasks for the selected allocation
tasks=$(nomad alloc status -address="$NOMAD_ADDR" -json "$alloc_id" | jq -r '.TaskStates | keys[]')

# Check if there are tasks available
if [ -z "$tasks" ]; then
    echo "No tasks found for allocation $alloc_id."
    exit 1
fi

log "Tasks available: $tasks"

# Automatically select the task if there's only one, otherwise use fzf
if [ $(echo "$tasks" | wc -l) -eq 1 ]; then
    task=$tasks
    echo "Only one task found: $task. Automatically selected."
else
    task=$(echo "$tasks" | fzf --prompt="Select Task: ")
fi

# Check if a task was selected
if [ -z "$task" ]; then
    echo "No task selected."
    exit 1
fi

log "Selected task: $task"

# Function to execute command with fallback
exec_with_fallback() {
    local alloc_id=$1
    local task=$2

    # Detect available shell
    available_shells=("/bin/bash" "/bin/sh" "/bin/zsh")
    for shell in "${available_shells[@]}"; do
        if nomad alloc exec -address="$NOMAD_ADDR" -i -t -task "$task" "$alloc_id" "$shell" -c "exit" 2>/dev/null; then
            log "Shell detected: $shell"
            nomad alloc exec -address="$NOMAD_ADDR" -i -t -task "$task" "$alloc_id" "$shell"
            return
        fi
    done

    echo "No suitable shell found in the container."
    exit 1
}

# Execute into the selected task with fallback
exec_with_fallback "$alloc_id" "$task"

