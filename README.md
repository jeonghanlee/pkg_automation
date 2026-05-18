# Package Automation for EPICS Environments

[![Ubuntu 24 LTS](https://github.com/jeonghanlee/pkg_automation/actions/workflows/ubuntu24.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/ubuntu24.yml)
[![Ubuntu 22 LTS](https://github.com/jeonghanlee/pkg_automation/actions/workflows/ubuntu22.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/ubuntu22.yml)
[![Debian 13](https://github.com/jeonghanlee/pkg_automation/actions/workflows/debian13.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/debian13.yml)
[![Debian 12](https://github.com/jeonghanlee/pkg_automation/actions/workflows/debian12.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/debian12.yml)
[![Rocky Linux 8](https://github.com/jeonghanlee/pkg_automation/actions/workflows/rocky8.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/rocky8.yml)
[![Rocky Linux 9](https://github.com/jeonghanlee/pkg_automation/actions/workflows/rocky9.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/rocky9.yml)
[![Rocky Linux 10](https://github.com/jeonghanlee/pkg_automation/actions/workflows/rocky10.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/rocky10.yml)

## Scope

This repository provides package installation automation for EPICS base,
EPICS modules, and supporting development tools across selected Linux
distributions and macOS with Homebrew.

**Out of scope:** General-purpose workstation provisioning, EPICS source
configuration policy, and distribution support beyond the package lists in
this repository.

## Components

- `pkg_automation.bash` detects the host distribution, loads package lists,
  confirms the operation, and installs the selected package set.
- `functions` provides shared Bash helper functions used by the installer.
- `build_epics_within_pkg_automation.bash` builds and installs EPICS through
  the external `EPICS-env` workflow from a Docker build context.
- `pkg-*` directories hold package-list fragments grouped by operating system
  family and functional category.

## Supported Targets

- Ubuntu 24.04 LTS (Noble Numbat), standard support through 2029-04
- Ubuntu 22.04 LTS (Jammy Jellyfish), standard support through 2027-04
- Debian 13 testing (Trixie)
- Debian 12 (Bookworm)
- Rocky Linux 8 (Green Obsidian)
- Rocky Linux 9 (Blue Onyx)
- Rocky Linux 10 (Red Quartz)

Package directories for other distributions may remain in the repository for
historical reference, but they are not actively maintained or covered by the
supported-target workflow set.

## Operation

The installer requires `sudo` for package-manager operations. It prompts
before installation unless `-y` is supplied.

```bash
bash pkg_automation.bash
```

```bash
bash pkg_automation.bash -y
```

Use `-f` with `-y` in non-interactive CI jobs when Rocky hosts must repair
the unversioned Python command without a prompt.

```bash
bash pkg_automation.bash -y -f
```

Use `-v` to verify at the end of supported Debian package paths that
`python` resolves to Python 3.

```bash
bash pkg_automation.bash -y -v
```

The installer uses `/etc/os-release` as parsed data and does not source it as
shell code. Package lists are read line by line, comments are skipped, Windows
carriage returns are stripped, and package names are installed through quoted
Bash arrays.

## EPICS Build Helper

`build_epics_within_pkg_automation.bash` expects to run from a directory that
contains the Docker build context. The optional first argument sets the
installation prefix; `/usr/local` is used when no argument is provided.

```bash
bash build_epics_within_pkg_automation.bash /usr/local
```

The helper clones `EPICS-env`, writes `CONFIG_SITE.local`, runs the EPICS-env
initialization and build targets, then creates the versioned EPICS symlinks.

## Rocky Python Command

EPICS Base uses the unversioned `python` command when generating linker RPATH
flags. Rocky 8 keeps the `python` alternatives group in auto mode with
`/usr/libexec/no-python` as the highest-priority entry, so EPICS builds need an
explicit package-automation contract for this command.

On Rocky 8, the installer registers `/usr/bin/python3` with priority `500`
and selects it through alternatives. On Rocky 9 and Rocky 10, the package list
includes `python-unversioned-command`, so the package is expected to provide
the unversioned command.

```bash
alternatives --install /usr/bin/unversioned-python python /usr/bin/python3 500
alternatives --set python /usr/bin/python3
ln -sfn /usr/bin/unversioned-python /usr/local/bin/python
```

The installer verifies this contract with `command -v python` and
`python --version` before returning from each Rocky package path. If `python`
does not resolve to Python 3, interactive runs prompt before creating the
site-owned `/usr/local/bin/python` link. CI runs should pass `-f` to force that
repair without a prompt.

## Debian Python Command

Debian 12 and Debian 13 keep the unversioned `python` command package-based
through `python-dev-is-python3`, which depends on `python-is-python3`. When
`-v` is supplied, the installer verifies the package result with
`command -v python` and `python --version` after package installation.

## Validation

The Bash sources are expected to pass:

```bash
bash -n pkg_automation.bash build_epics_within_pkg_automation.bash functions
```

```bash
shellcheck -x pkg_automation.bash build_epics_within_pkg_automation.bash functions
```

## Operational Notes

- Package installation can remove or disable selected services on RPM-family
  systems, including PackageKit and firewalld.
- On Rocky systems, the installer provides an unversioned `python` command for
  EPICS build tooling.
- Package lists are tailored for this EPICS development environment and are not
  a generic baseline for all hosts.
- New distribution versions require explicit package-list review before they
  should be treated as supported targets.
