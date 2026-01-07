# SSH Host Configurations

This directory contains SSH host configuration files that are automatically loaded to generate separate SSH config files.

## How it works

**All `.json` files in this directory are automatically discovered and each generates its own config file!**

- `ssh-hosts.json` → `~/.ssh/config.d/rbw-ssh-hosts.conf`
- `customer-a.json` → `~/.ssh/config.d/rbw-customer-a.conf`
- `customer-b.json` → `~/.ssh/config.d/rbw-customer-b.conf`

No need to manually add files to a list in the Nix configuration. Just:
1. Create a new `.json` file here
2. Run `home-manager switch`
3. Done! A new config file is automatically created.

## File naming convention

Choose descriptive names for your configuration files:

- `ssh-hosts.json` - General/personal SSH hosts
- `customer-technative.json` - TechNative customer hosts
- `customer-acme.json` - ACME Corp customer hosts
- `home-servers.json` - Home lab servers
- `cloud-aws.json` - AWS instances

## JSON Format

Each JSON file should contain an array of host configurations:

```json
[
  {
    "host": "server-name",           // Required: SSH host alias
    "hostname": "server.example.com", // Optional: actual hostname/IP
    "user": "username",               // Optional: SSH user
    "identity_file": "key-name",      // Required: SSH key name from rbw
    "port": 22                        // Optional: SSH port (default: 22)
  }
]
```

### Host Patterns

You can use wildcard patterns in the `host` field:

```json
{
  "host": "*.customer.internal",
  "user": "admin",
  "identity_file": "customer-admin-key"
}
```

### Multiple hosts with same key

```json
[
  {
    "host": "web1 web2 web3",
    "hostname": "%h.example.com",
    "user": "deploy",
    "identity_file": "deploy-key"
  }
]
```

## SSH Key Management

SSH keys are managed through rbw (Bitwarden CLI) and should:

1. Be stored in rbw in the `ssh-keys` folder
2. Have a `fingerprint` field set
3. Be exported to `~/.ssh/rbw-keys/` using:

```bash
~/bin/export-ssh-keys.sh
```

The `identity_file` field in your JSON should match the **name** of the key item in rbw.

## Examples

### Basic host configuration
```json
{
  "host": "myserver",
  "hostname": "192.168.1.100",
  "user": "admin",
  "identity_file": "my-server-key",
  "port": 22
}
```

### Wildcard pattern for multiple hosts
```json
{
  "host": "*.production.internal",
  "user": "deploy",
  "identity_file": "production-deploy-key",
  "port": 22
}
```

### Host without hostname (using host as hostname)
```json
{
  "host": "server.example.com",
  "user": "root",
  "identity_file": "root-key"
}
```

## Example Files

- `customer-a.json.example` - Example customer configuration

Rename `.example` files to `.json` to enable them.

## Troubleshooting

### Check all generated configs
```bash
ls -la ~/.ssh/config.d/rbw-*.conf
```

### Check a specific config file
```bash
cat ~/.ssh/config.d/rbw-ssh-hosts.conf
cat ~/.ssh/config.d/rbw-customer-a.conf
```

### Test SSH config syntax
```bash
ssh -G hostname
```

### Verify SSH keys are exported
```bash
ls -la ~/.ssh/rbw-keys/
```

### Re-export SSH keys
```bash
~/bin/export-ssh-keys.sh
```

### Disable a customer temporarily
```bash
# Rename the file to skip it
mv customer-a.json customer-a.json.disabled
home-manager switch
# The rbw-customer-a.conf will be automatically removed
```
