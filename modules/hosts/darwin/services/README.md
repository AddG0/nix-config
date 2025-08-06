# Darwin Services

This directory contains Darwin system-level service modules for macOS.

## Available Services

- **[MySQL/MariaDB](#mysql-service)** - Full-featured MySQL/MariaDB server with socket and password authentication

---

## MySQL Service

A Nix-Darwin module that provides a system-wide MySQL/MariaDB service for macOS.

### Quick Start

1. **Enable the service in your Darwin configuration:**
   ```nix
   services.mysql = {
     enable = true;
     # Optional: specify package (defaults to MariaDB)
     package = pkgs.mariadb; # or pkgs.mysql80
   };
   ```

2. **Rebuild your system:**
   ```bash
   sudo darwin-rebuild switch --flake .
   ```

3. **Connect to MySQL:**
   ```bash
   mysql -S /opt/mysql/mysql.sock
   ```

### Configuration Options

```nix
services.mysql = {
  enable = true;
  
  # Database package (MariaDB or MySQL)
  package = pkgs.mariadb;  # default: pkgs.mariadb
  
  # User and group (defaults to your username)
  user = "your-username";   # default: config.hostSpec.username
  group = "staff";          # default: "staff"
  
  # Data directory
  dataDir = "/opt/mysql";   # default: "/opt/mysql"
  
  # Database settings
  settings = {
    mysqld = {
      port = 3306;
      bind-address = "127.0.0.1";
      # Add any MySQL/MariaDB configuration here
    };
  };
  
  # Ensure these databases exist
  ensureDatabases = [ "myapp" "dev_db" ];
  
  # Ensure these users exist with permissions
  ensureUsers = [
    {
      name = "admin";
      authentication = "password";  # or "socket"
      ensurePermissions = {
        "*.*" = "ALL PRIVILEGES";
      };
    }
    {
      name = "app_user";
      authentication = "socket";
      ensurePermissions = {
        "myapp.*" = "ALL PRIVILEGES";
      };
    }
  ];
  
  # Run SQL script on first startup
  initialScript = pkgs.writeText "mysql-init.sql" ''
    SET PASSWORD FOR 'admin'@'localhost' = PASSWORD('your-password');
    FLUSH PRIVILEGES;
  '';
};
```

### Service Management

The module provides several convenience commands:

```bash
# Check service status
mysql-status

# View logs
mysql-logs

# Start service (if stopped)
mysql-start

# Stop service
mysql-stop

# Restart service
mysql-restart
```

### Manual Service Control

```bash
# Check if service is loaded
sudo launchctl list | grep mysql

# Load service
sudo launchctl load /Library/LaunchDaemons/org.nixos.mysql.plist

# Unload service
sudo launchctl unload /Library/LaunchDaemons/org.nixos.mysql.plist

# View detailed service info
sudo launchctl list org.nixos.mysql
```

## Debugging Guide

### 1. Service Not Starting

**Check service status:**
```bash
sudo launchctl list | grep mysql
```

**Expected output:**
- `PID 0 org.nixos.mysql` = Service running (PID is the process ID)
- `- 78 org.nixos.mysql` = Service failed (78 is exit code)
- No output = Service not loaded

**If service is not loaded:**
```bash
# Load the service
sudo launchctl load /Library/LaunchDaemons/org.nixos.mysql.plist
```

**If service fails to start (exit code != 0):**
```bash
# Check error logs
tail -50 /opt/mysql/mysql.error.log

# Check system logs
sudo tail -50 /var/log/system.log | grep mysql
```

### 2. Connection Issues

**Socket connection failed:**
```bash
# Check if socket exists
ls -la /opt/mysql/mysql.sock

# Check socket permissions
stat /opt/mysql/mysql.sock
```

**Common socket errors:**
- `ERROR 2002 (HY000): Can't connect to local server through socket` = Socket doesn't exist or service not running
- `ERROR 2013 (HY000): Lost connection to MySQL server` = Service crashed
- `Permission denied` = Socket permission issue

**Test different connection methods:**
```bash
# Socket connection (preferred)
mysql -S /opt/mysql/mysql.sock

# TCP connection (if enabled)
mysql -h 127.0.0.1 -P 3306

# As specific user
mysql -S /opt/mysql/mysql.sock -u your-username
```

### 3. Data Directory Issues

**Check directory exists and permissions:**
```bash
ls -la /opt/mysql/
```

**Expected ownership:** Your username (e.g., `addg:staff`)
**Expected permissions:** `drwx------` (700)

**Fix permissions:**
```bash
sudo chown your-username:staff /opt/mysql
sudo chmod 700 /opt/mysql
```

**Recreate data directory:**
```bash
# Stop service
sudo launchctl unload /Library/LaunchDaemons/org.nixos.mysql.plist

# Remove corrupted data
sudo rm -rf /opt/mysql

# Rebuild system (will recreate directory)
sudo darwin-rebuild switch --flake .
```

### 4. Database Initialization Issues

**Check initialization status:**
```bash
# Look for initialization marker
ls -la /opt/mysql/.mysql_initialized

# Check for MySQL system tables
ls -la /opt/mysql/mysql/
```

**Force re-initialization:**
```bash
# Stop service
sudo launchctl unload /Library/LaunchDaemons/org.nixos.mysql.plist

# Remove initialization markers
sudo rm -f /opt/mysql/.mysql_initialized
sudo rm -f /opt/mysql/.mysql_needs_setup

# Start service (will re-initialize)
sudo launchctl load /Library/LaunchDaemons/org.nixos.mysql.plist
```

### 5. Authentication Issues

**Socket authentication (default):**
- Your system username must match MySQL username
- No password required for socket connections
- Only works for local connections

**Password authentication:**
```nix
ensureUsers = [
  {
    name = "admin";
    authentication = "password";
    ensurePermissions = {
      "*.*" = "ALL PRIVILEGES";
    };
  }
];
```

**Test authentication:**
```bash
# List MySQL users
mysql -S /opt/mysql/mysql.sock -e "SELECT User, Host, plugin FROM mysql.user;"

# Test connection as specific user
mysql -S /opt/mysql/mysql.sock -u admin -p
```

### 6. Log Analysis

**Service logs:**
```bash
# Error log (most important)
tail -f /opt/mysql/mysql.error.log

# General log
tail -f /opt/mysql/mysql.log

# System logs
sudo tail -f /var/log/system.log | grep mysql
```

**Important log patterns:**
- `ERROR: MySQL daemon (PID: XXXX) exited unexpectedly` = Service crash
- `Access denied for user 'root'@'localhost'` = Authentication issue (often normal)
- `Can't connect to local server through socket` = Socket/service issue
- `Table 'mysql.user' doesn't exist` = Database corruption
- `Terminated: 15` = Service was killed by system

### 7. Performance Issues

**Check resource usage:**
```bash
# Find MySQL process
ps aux | grep mysqld

# Check disk usage
du -sh /opt/mysql/

# Check connections
mysql -S /opt/mysql/mysql.sock -e "SHOW PROCESSLIST;"
```

**Common performance settings:**
```nix
services.mysql.settings = {
  mysqld = {
    # Memory settings
    innodb_buffer_pool_size = "1G";
    
    # Connection settings
    max_connections = 100;
    
    # Logging
    slow_query_log = 1;
    slow_query_log_file = "/opt/mysql/slow.log";
    long_query_time = 2;
  };
};
```

## Architecture

### Service Type
- **Type:** Darwin system daemon (`launchd.daemons`)
- **Runs as:** Specified user (default: your username)
- **Starts:** At system boot
- **Survives:** User logout/login
- **Location:** `/Library/LaunchDaemons/org.nixos.mysql.plist`

### Directory Structure
```
/opt/mysql/                    # Data directory
├── mysql/                     # System database
├── performance_schema/        # Performance monitoring
├── sys/                       # System views
├── test/                      # Default test database
├── mysql.sock                 # Unix socket
├── mysql.pid                  # Process ID file
├── mysql.error.log           # Error log
├── mysql.log                 # General log
├── .mysql_initialized        # Initialization marker
└── .mysql_needs_setup        # Setup marker
```

### User Management
- **Default user:** Your system username with socket authentication
- **Admin users:** Created via `ensureUsers` with configurable authentication
- **Socket auth:** System username = MySQL username, no password
- **Password auth:** Traditional username/password authentication

## Common Patterns

### Development Setup
```nix
services.mysql = {
  enable = true;
  ensureDatabases = [ "myapp_dev" "myapp_test" ];
  ensureUsers = [
    {
      name = "dev";
      authentication = "socket";
      ensurePermissions = {
        "myapp_dev.*" = "ALL PRIVILEGES";
        "myapp_test.*" = "ALL PRIVILEGES";
      };
    }
  ];
};
```

### Production-like Setup
```nix
services.mysql = {
  enable = true;
  settings = {
    mysqld = {
      # Security
      bind-address = "127.0.0.1";
      skip-networking = false;
      
      # Performance
      innodb_buffer_pool_size = "2G";
      max_connections = 200;
      
      # Logging
      log-error = "/opt/mysql/error.log";
      slow_query_log = 1;
      slow_query_log_file = "/opt/mysql/slow.log";
    };
  };
  ensureUsers = [
    {
      name = "app";
      authentication = "password";
      ensurePermissions = {
        "production.*" = "SELECT, INSERT, UPDATE, DELETE";
      };
    }
  ];
};
```

## Troubleshooting Checklist

1. **Service Status:** `sudo launchctl list | grep mysql`
2. **Socket Exists:** `ls -la /opt/mysql/mysql.sock`
3. **Directory Permissions:** `ls -la /opt/mysql/`
4. **Error Logs:** `tail -20 /opt/mysql/mysql.error.log`
5. **Connection Test:** `mysql -S /opt/mysql/mysql.sock -e "SELECT 1;"`
6. **User Authentication:** `mysql -S /opt/mysql/mysql.sock -e "SELECT USER();"`

## Getting Help

If you encounter issues:

1. Check this README's debugging section
2. Review the error logs (`/opt/mysql/mysql.error.log`)
3. Verify your configuration against the examples
4. Try recreating the data directory if corruption is suspected
5. Check the [MySQL](https://dev.mysql.com/doc/) or [MariaDB](https://mariadb.com/kb/en/) documentation for database-specific issues


## Getting Help