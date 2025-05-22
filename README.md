# Linux Domain Controller

This project aims to set up a Samba-based Active Directory Domain Controller on Linux. The goal is feature parity with a Windows Domain Controller (OU, GPOs, Users, Computers, replication) and interoperability with existing Windows Domain Controllers.

## Features
- Samba 4 as the core domain controller
- Scripts to bootstrap a new domain or join an existing Windows domain
- Example configuration for replication between Linux and Windows
- Optional Cockpit web GUI with `samba-ad-dc` module
- Basic time synchronization setup via chrony

## Getting Started
Run `./setup.sh` on a fresh Linux machine. On first run the script will copy
`config.env.example` to `config.env` if the file does not exist. Adjust the
variables in `config.env` to match your environment.
Key variables include:
- `DOMAIN`: Your short domain name (e.g., EXAMPLE).
- `REALM`: Your full domain realm (e.g., EXAMPLE.COM).
- `ADMIN_PASS`: The administrator password. As a security enhancement, if this is left as the default "Passw0rd!" or is empty when running `./setup.sh --provision` (and not in `TEST_MODE`), the script will interactively prompt you to set a strong administrator password.
- `CHRONY_ALLOW_SUBNET`: Specifies the subnet(s) allowed to access the chrony NTP server. It defaults to `127.0.0.1` (localhost only). For broader LAN access, you might set it to something like `CHRONY_ALLOW_SUBNET="192.168.1.0/24"`.

The script installs the `samba-ad-dc` package, configures Kerberos and Samba, sets up chrony for time
synchronization, and optionally joins an existing domain. Pass `--gui` to
install Cockpit with the `samba-ad-dc` management module for a web-based
administration interface. If the `DOMAIN` variable is not set, it will be
 derived from the realm automatically. If `config.env` still contains the
 default values from `config.env.example`, the script prints a warning.

For containerized setups, build the provided `Dockerfile`. Note that this image does **not** contain a default `/config.env` file. You **must** mount your own `config.env` file at runtime for actual domain provisioning or joining.
Example:
\`\`\`bash
docker run -v /path/to/your/custom/config.env:/config.env your_image_name ./setup.sh --provision
\`\`\`
During the Docker build, `setup.sh` is run with `TEST_MODE=1` for validation, using `config.env.example` to create a temporary `config.env`. This does not result in a fully provisioned domain controller within the image itself; real provisioning occurs at runtime with your provided configuration.

## Keycloak Integration
The `keycloak_setup.sh` script assists with setting up Keycloak. It now automatically downloads Keycloak version 24.0.5 if the ZIP file (`keycloak-24.0.5.zip`) is not found in the current directory. The script can also print basic instructions for configuring Keycloak as a SAML identity provider for Google Workspace.
Run `./keycloak_setup.sh --install` to download (if needed) and extract Keycloak.
Run `./keycloak_setup.sh --configure-google` to view the Google Workspace configuration instructions.

## Disclaimer
This repository contains high-level examples. Review and adapt the configuration to your environment. Testing in isolated labs is strongly recommended before production use.

## Testing
Basic tests and linting are run via GitHub Actions. Shell scripts are linted with `shellcheck` and simple smoke tests ensure the setup script displays usage information correctly.

## CI/CD
The workflow defined in `.github/workflows/ci.yml` installs required packages and
executes `shellcheck` followed by the test suite. Add new scripts to the workflow
so they are automatically tested on every pull request.

