# Linux Domain Controller

This project aims to set up a Samba-based Active Directory Domain Controller on Linux. The goal is feature parity with a Windows Domain Controller (OU, GPOs, Users, Computers, replication) and interoperability with existing Windows Domain Controllers.

## Features
- Samba 4 as the core domain controller
- Scripts to bootstrap a new domain or join an existing Windows domain
- Example configuration for replication between Linux and Windows
- Placeholder GUI management tool integration
- Basic time synchronization setup via chrony

## Getting Started
Run `./setup.sh` on a fresh Linux machine. The script installs required packages, configures Kerberos and Samba, sets up chrony for time synchronization, and optionally joins an existing domain.

## Disclaimer
This repository contains high-level examples. Review and adapt the configuration to your environment. Testing in isolated labs is strongly recommended before production use.

## Testing
Basic tests and linting are run via GitHub Actions. Shell scripts are linted with `shellcheck` and simple smoke tests ensure the setup script displays usage information correctly.

## CI/CD
The workflow defined in `.github/workflows/ci.yml` installs required packages and
executes `shellcheck` followed by the test suite. Add new scripts to the workflow
so they are automatically tested on every pull request.

