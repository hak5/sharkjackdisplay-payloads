# deploy-shark

Provision a Shark Jack Display from this repository, driven by a config file.

A firmware update wipes the device overlay, taking your payloads and the nmap
OUI database with it. `deploy-shark.sh` puts them back: it reads a `shark.conf`
that lists exactly which payloads you want, applies any per-payload config
overrides you define, and pushes the result onto the device.

> **Note on repo layout.** The contribution guidelines ask not to create new
> top-level directories. This is a deploy *tool*, not a payload, so a `tools/`
> directory fits it better than the payload tree. Flagged for Darren.

## Quick start

```sh
./deploy-shark.sh --init        # write a starter shark.conf next to the script
$EDITOR shark.conf              # choose payloads + set overrides
./deploy-shark.sh --dry-run     # render + validate; contacts no device
./deploy-shark.sh               # provision (prompts for IP + root password)
```

## Flags

| Flag | Effect |
|------|--------|
| `-h`, `--help` | Full usage. |
| `--init [FILE]` | Write a starter config (default `shark.conf`). Won't overwrite without `--force`. |
| `--config FILE` | Use a config other than the default. |
| `--dry-run` | Render payloads with overrides applied and report what *would* be pushed. No device contact, no prompts. |
| `--no-oui` | Skip installing the nmap MAC/OUI database. |
| `--force` | Let `--init` overwrite an existing config. |

## Config format

`shark.conf` is sectioned, one section per payload to load. Section names are the
payload's directory under [`payloads/library/`](../../payloads/library/) (the
script finds the category for you).

```ini
[options]
shark_ip = 172.16.24.1          # default device IP (password is always prompted)
install_oui_db = yes            # yes/no

[port_id_beacon]                # loaded unchanged

[jack_survey]
EXPECTED_SWITCH="" --> EXPECTED_SWITCH="MDF-SW-01"
EXPECTED_VLAN="" --> EXPECTED_VLAN="20"

[remote_debug_bridge]
JUMP_HOST="X.X.X.X" --> JUMP_HOST="203.0.113.10"
JUMP_USER="sharkdebug" --> JUMP_USER="bridge"
```

### Overrides: `FIND --> REPLACE`

Each override line is a **literal** find-and-replace applied to that payload's
`payload.txt` before it is pushed. The `FIND` side must match the line in the
payload's CONFIG block **exactly** (copy it straight from the payload), including
the quotes. Replacement is literal (no regex), so special characters are safe.

If a `FIND` string isn't present in the payload, the override is **skipped with a
loud warning** rather than silently doing nothing, so a typo or an upstream
change to a config line can't quietly leave you with the default value. Use
`--dry-run` to see exactly which overrides applied before touching a device.

## What gets pushed

For each configured payload the script:

1. Resolves `<name>` to `payloads/library/<category>/<name>/payload.txt`.
2. Applies that section's overrides to a temporary copy.
3. Pushes it as `/root/library/my_payloads/<name>/payload.txt`.

Then it installs the nmap OUI database (unless `--no-oui` or `install_oui_db =
no`), which several recon payloads use for vendor lookups.

## Files

| File | Tracked? | Purpose |
|------|----------|---------|
| `deploy-shark.sh` | yes | the tool |
| `shark.conf.example` | yes | the documented template (also produced by `--init`) |
| `shark.conf` | **no** (gitignored) | your real config: site IPs, hostnames, overrides |
| `.gitignore` | yes | ignores `shark.conf` |

`shark.conf` is gitignored on purpose: it holds deployment-specific values
(jump-host IPs, expected switch names, etc.) that should not land in the repo.

## Requirements

- `bash`, `ssh`/`scp`, `curl`, `awk` (all standard on macOS/Linux).
- Optional: `sshpass` so the password is entered once
  (`brew install hudochenkov/sshpass/sshpass`). Without it, the script opens one
  shared SSH connection and prompts a single time.

## Auth / host keys

A freshly-updated Shark presents a new host key, so the script disables strict
host-key checking for the connection. That is appropriate for a device you
control on a local link; do not reuse these options against arbitrary hosts. The
root password is only ever prompted, never read from the config file.
