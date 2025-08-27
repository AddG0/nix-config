# LastPass helpers for direnv (Nix Module)

A Nix home-manager module providing direnv integration for fetching secrets using [LastPass CLI](https://github.com/lastpass/lastpass-cli).

## Nix Configuration

Enable the module in your home-manager configuration:

```nix
{
  programs.direnv.lastpass.enable = true;
}
```

This will:

- Install the LastPass CLI and direnv packages
- Place the LastPass direnv helper at `~/.config/direnv/lib/lastpass.sh`
- Make the `from_lpass` function available in your `.envrc` files

---

## Usage

Example `.envrc`:

```bash
# Fetch one secret and export it into the specified environment variable
from_lpass MY_SECRET=my-secret-name

# Multiple secrets can be fetched by passing the items to the command's STDIN
from_lpass <<LP
    FIRST_SECRET=first-secret
    OTHER_SECRET=other-secret
LP

# Multiple secrets can be fetched from a file as well.
# direnv will reload when the file changes.
from_lpass .lastpass

# Only load a secret from LastPass if it wasn't already set in `.env`.
dotenv_if_exists
from_lpass --no-overwrite MY_SECRET=my-secret-name

# Show the status of LastPass while loading direnv.
from_lpass --verbose MY_SECRET=my-secret-name
```

### Secret Names

The secret names should match the names of your LastPass entries. The function will retrieve the password field from the specified entry.

### LastPass Login

For the `from_lpass` command to work, you must be logged in to LastPass. Before using the `.envrc` file, run:

```bash
lpass login <username>
```

You can check your login status with:

```bash
lpass status
```

---

## Requirements

- [direnv](https://direnv.net)
- [LastPass CLI](https://github.com/lastpass/lastpass-cli) (`lpass`)
- A valid LastPass account and login session
- A shell supported by direnv (Bash v3+ should work)

---

## Functions

### `from_lpass [options] [VAR=secret-name]`

Load secrets from LastPass into environment variables.

**Options:**
- `--no-overwrite`: Only set variables that aren't already defined
- `--verbose`: Show status messages during loading

**Examples:**
```bash
# Single secret
from_lpass API_KEY=my-api-key

# Multiple secrets from stdin
from_lpass <<EOF
DB_PASSWORD=database-password
API_TOKEN=api-token
EOF

# From file
from_lpass secrets.txt

# With options
from_lpass --verbose --no-overwrite API_KEY=my-api-key
```

---

## Security Notes

- Secrets are loaded into environment variables and may be visible to other processes
- Make sure your LastPass session is secured and logged out when not needed
- Consider using `.env` files with appropriate permissions for less sensitive data
- The LastPass CLI stores session information locally - ensure your system is secure