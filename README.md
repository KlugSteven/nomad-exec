# Nomad Exec Script

This script allows you to interactively select a running Nomad job and task, and then execute a shell within the selected task.

## Prerequisites

Ensure the following tools are installed on your system:

- `nomad`
- `fzf`
- `jq`

## Usage

```bash
nomadexec [--address=<addr>] [--verbose] [--job=<job_name>] [--task=<task_name>] [--command=<command>] [--help]
```

The Nomad server address is determined in the following order:

1. **Command-Line Argument**: If `--address=<addr>` is provided, it takes the highest priority.
2. **Environment Variable**: If the `NOMAD_ADDR` environment variable is set, it is used.
3. **Default Value**: If neither is set, the default address `http://127.0.0.1:4646` is used.

