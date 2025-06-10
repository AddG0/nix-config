# Just Command Runner Features

This document covers the features and capabilities of the [Just](https://github.com/casey/just) command runner tool.

## What is Just?

Just is a handy way to save and run project-specific commands. It's a command runner, not a build system, which makes it simpler and more flexible than Make for many use cases.

## Core Features

### 📝 Recipe Syntax

```just
# Basic recipe
hello:
  echo "Hello, world!"

# Recipe with parameters
greet name:
  echo "Hello, {{name}}!"

# Recipe with default parameters
greet name="World":
  echo "Hello, {{name}}!"

# Recipe with dependencies
build: clean
  echo "Building..."

clean:
  rm -rf build/
```

### 🔧 Variables and Expressions

```just
# Simple variables
version := "1.0.0"
name := "my-project"

# Expressions and concatenation
build_dir := "build/" + version
full_name := name + "-" + version

# Environment variables
home := env_var("HOME")
user := env_var_or_default("USER", "anonymous")

# Command execution (backticks)
git_branch := `git rev-parse --abbrev-ref HEAD`
timestamp := `date +%Y%m%d_%H%M%S`
```

### 🛠️ Built-in Functions

#### System Information
```just
# Operating system detection
os_name := os()                    # "linux", "macos", "windows", etc.
arch_name := arch()                # "x86_64", "aarch64", etc.
family := os_family()              # "unix" or "windows"
cpu_count := num_cpus()            # Number of logical CPUs
```

#### Path Operations
```just
# Path manipulation
config_dir := config_directory()
home_dir := home_directory()
current := invocation_directory()
justfile_dir := justfile_directory()

# Path functions
basename := file_name("/path/to/file.txt")     # "file.txt"
extension := extension("/path/to/file.txt")    # "txt"
parent := parent_directory("/path/to/file.txt") # "/path/to"
```

#### String Operations
```just
# String manipulation
upper := uppercase("hello")        # "HELLO"
lower := lowercase("HELLO")        # "hello"
trimmed := trim("  hello  ")       # "hello"
replaced := replace("hello", "l", "x")  # "hexxo"

# Case conversion
snake := snakecase("HelloWorld")   # "hello_world"
kebab := kebabcase("HelloWorld")   # "hello-world"
camel := lowercamelcase("hello_world")  # "helloWorld"
```

#### File Operations
```just
# File system functions
exists := path_exists("config.toml")
content := read("version.txt")
hash := sha256_file("package.tar.gz")
```

### 🏷️ Recipe Attributes

#### Platform-Specific Recipes
```just
[linux]
install-linux:
  apt update && apt install package

[macos]
install-macos:
  brew install package

[windows]
install-windows:
  choco install package
```

#### Confirmation Prompts
```just
[confirm]
dangerous-operation:
  rm -rf /important/data

[confirm("Are you sure you want to delete everything?")]
nuclear-option:
  rm -rf *
```

#### Private Recipes
```just
[private]
helper-function:
  echo "This won't show in --list"

# Or use underscore prefix
_another-helper:
  echo "Also private"
```

#### Working Directory Control
```just
[no-cd]
current-dir-operation:
  pwd  # Will show the directory you called 'just' from

[working-directory('subdirectory')]
subdir-operation:
  pwd  # Will show 'subdirectory' path
```

#### Recipe Groups
```just
[group('database')]
db-migrate:
  echo "Running migrations"

[group('database')]
db-backup:
  echo "Creating backup"

[group('testing')]
test-unit:
  echo "Running unit tests"
```

#### Documentation
```just
[doc('Builds the project in release mode')]
build-release:
  cargo build --release
```

### ⚙️ Settings

#### Shell Configuration
```just
# Use different shell
set shell := ["bash", "-uc"]
set shell := ["python3", "-c"]
set shell := ["powershell.exe", "-Command"]

# Windows-specific shell
set windows-shell := ["cmd.exe", "/c"]
```

#### Environment Variables
```just
# Export all variables as environment variables
set export

# Load .env files
set dotenv-load
set dotenv-filename := ".development.env"
set dotenv-path := "/absolute/path/to/.env"
```

#### Execution Behavior
```just
# Make all recipes quiet by default
set quiet

# Allow duplicate recipes (later ones override)
set allow-duplicate-recipes

# Use positional arguments ($1, $2, etc.)
set positional-arguments
```

### 🔀 Conditional Expressions

```just
# Basic conditionals
greeting := if os() == "windows" { "Hello from Windows!" } else { "Hello from Unix!" }

# Multiple conditions
build_command := if os() == "linux" {
  "make linux"
} else if os() == "macos" {
  "make macos"  
} else {
  "make generic"
}

# Regular expression matching
valid_branch := if `git branch --show-current` =~ "^(main|develop)$" {
  "true"
} else {
  "false"
}
```

### 📜 Advanced Recipe Features

#### Variadic Parameters
```just
# One or more files
backup +files:
  tar czf backup.tar.gz {{files}}

# Zero or more flags
test *flags:
  cargo test {{flags}}

# Mixed parameters
deploy environment +files *flags:
  rsync {{flags}} {{files}} {{environment}}:/app/
```

#### Shebang Recipes
```just
# Python recipe
python-script:
  #!/usr/bin/env python3
  print("Hello from Python!")
  import sys
  print(f"Args: {sys.argv[1:]}")

# Bash recipe with error handling
bash-script:
  #!/usr/bin/env bash
  set -euxo pipefail
  echo "Bash script with strict error handling"
```

#### Recipe Dependencies
```just
# Simple dependency
deploy: build test
  echo "Deploying..."

# Parameterized dependencies
deploy environment: (build environment) (test environment)
  echo "Deploying to {{environment}}"

# Subsequent dependencies (run after)
test: compile && cleanup
  echo "Running tests"

compile:
  echo "Compiling"

cleanup:
  echo "Cleaning up"
```

### 🎛️ Command Line Features

#### Recipe Selection
```just
# List recipes
just --list
just --list --unsorted

# Show recipe details
just --show recipe-name

# Choose recipe interactively
just --choose

# Run multiple recipes
just build test deploy
```

#### Variable Override
```just
# Set variables from command line
just build version=2.0.0 debug=true

# Using --set flag
just --set version 2.0.0 build
```

#### Execution Control
```just
# Dry run (show what would be executed)
just --dry-run deploy

# Continue on errors
just --keep-going test-suite

# Quiet execution
just --quiet build

# Verbose output
just --verbose deploy
```

### 🔍 Advanced Features

#### Imports and Modules
```just
# Import other justfiles
import 'scripts/deployment.just'
import? 'optional-config.just'  # Optional import

# Module system
mod database
mod testing 'tests/recipes.just'
```

#### String Literals
```just
# Different quote types
single := 'single quotes'
double := "double quotes with\nescapes"
triple := '''
  Multi-line string
  with automatic dedenting
'''

# Raw strings (shell expansion)
path := x'~/$USER/config'  # Expands ~ and $USER
```

#### Error Handling
```just
# Continue on command failure
recipe:
  -command_that_might_fail
  echo "This runs even if above fails"

# Custom error messages
validate:
  @{{ if env_var_or_default("REQUIRED_VAR", "") == "" { error("REQUIRED_VAR must be set") } else { "" } }}
```

#### Constants and Special Variables
```just
# Built-in constants
hex_chars := HEX          # "0123456789abcdef"
normal_color := NORMAL    # ANSI reset sequence
bold_text := BOLD         # ANSI bold sequence

# Special interpolations
recipe:
  echo "Escaping braces: {{{{not_a_variable}}}}"
```

## Command Line Options

### Common Flags
- `--list` / `-l` - List available recipes
- `--show <recipe>` - Show recipe and its dependencies
- `--dry-run` / `-n` - Show what would be executed
- `--quiet` / `-q` - Suppress echoing of commands
- `--verbose` / `-v` - Show additional information
- `--choose` - Select recipe interactively
- `--yes` - Automatically confirm all prompts

### File Options
- `--justfile <file>` / `-f <file>` - Use specific justfile
- `--working-directory <dir>` / `-d <dir>` - Run from specific directory
- `--dotenv-path <path>` - Load environment from specific file

### Variable Options
- `--set <var> <value>` - Set variable value
- `--eval <expression>` - Evaluate and print expression

## Best Practices

### Recipe Organization
```just
# Use descriptive names
setup-development-environment:
  # Setup commands

# Group related recipes
[group('docker')]
docker-build:
  docker build .

[group('docker')]  
docker-run:
  docker run my-app
```

### Error Handling
```just
# Validate inputs
deploy target:
  @{{ if target == "" { error("target parameter required") } else { "" } }}
  # Deployment commands

# Use confirmation for dangerous operations
[confirm("This will delete all data. Continue?")]
reset-database:
  rm -rf data/
```

### Documentation
```just
# Document complex recipes
[doc('Builds and deploys to production with full validation')]
production-deploy: validate build test
  # Deployment logic
```

### Platform Compatibility
```just
# Handle cross-platform differences
install:
  @echo "Installing on {{ os() }}"
  {{ if os() == "linux" { "sudo apt install package" } else if os() == "macos" { "brew install package" } else { error("Unsupported platform") } }}
```

## Debugging and Development

### Debugging Recipes
```just
# Show recipe execution
just --verbose recipe-name

# Dry run to see commands
just --dry-run recipe-name

# Show recipe source
just --show recipe-name
```

### Development Workflow
```just
# Default to showing available recipes
default:
  @just --list

# Development commands group
[group('dev')]
dev-setup: install-deps setup-config
  echo "Development environment ready"

[group('dev')]
dev-test:
  cargo test --watch
```

## Integration Examples

### CI/CD Integration
```just
# GitHub Actions friendly
ci: check test build
  echo "CI pipeline complete"

check:
  cargo clippy -- -D warnings

test:
  cargo test --all-features

build:
  cargo build --release
```

### Docker Integration
```just
# Docker development workflow
docker-dev: docker-build docker-run

docker-build:
  docker build -t myapp:dev .

docker-run:
  docker run --rm -it -p 8080:8080 myapp:dev
```

This covers the major features of Just. It's a powerful tool that bridges the gap between simple shell scripts and complex build systems, providing just the right amount of structure and features for most project automation needs. 