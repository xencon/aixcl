# Bash Completion for AIXCL

AIXCL includes bash completion support to make using the CLI faster and easier.

## Quick Installation

The simplest way to install bash completion is to use the built-in command:

```bash
./aixcl install-completion
```

This will:
1. Install the completion script to the appropriate location
2. Add it to your `.bashrc` file for automatic loading
3. Make it available for immediate use

## Manual Installation

If you prefer to install it manually:

1. Source the completion script directly:
   ```bash
   source /path/to/aixcl_completion.sh
   ```

2. Or install it system-wide (requires sudo):
   ```bash
   sudo cp aixcl_completion.sh /etc/bash_completion.d/aixcl
   ```

## Using Completion

Once installed, you can use tab completion with aixcl commands:

```bash
./aixcl [TAB]              # Shows all available commands
./aixcl add [TAB]          # Shows available models to add
./aixcl remove [TAB]       # Shows installed models you can remove
```

## Features

The completion script provides:
- Command completion for all aixcl commands
- Model name suggestions for the add command
- Installed model suggestions for the remove command
- Support for completing multiple models in a single command

## Troubleshooting

If completion isn't working:
1. Make sure bash completion is installed on your system
2. Try restarting your terminal
3. Check that the script is properly sourced in your `.bashrc` 