# Package Automation for EPICS Environments

[![Ubuntu 26 LTS](https://github.com/jeonghanlee/pkg_automation/actions/workflows/ubuntu26.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/ubuntu26.yml)
[![Ubuntu 24 LTS](https://github.com/jeonghanlee/pkg_automation/actions/workflows/ubuntu24.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/ubuntu24.yml)
[![Ubuntu 22 LTS](https://github.com/jeonghanlee/pkg_automation/actions/workflows/ubuntu22.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/ubuntu22.yml)
[![Debian 14](https://github.com/jeonghanlee/pkg_automation/actions/workflows/debian14.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/debian14.yml)
[![Debian 13](https://github.com/jeonghanlee/pkg_automation/actions/workflows/debian13.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/debian13.yml)
[![Debian 12](https://github.com/jeonghanlee/pkg_automation/actions/workflows/debian12.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/debian12.yml)
[![Rocky Linux 8](https://github.com/jeonghanlee/pkg_automation/actions/workflows/rocky8.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/rocky8.yml)
[![Rocky Linux 9](https://github.com/jeonghanlee/pkg_automation/actions/workflows/rocky9.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/rocky9.yml)
[![Rocky Linux 10](https://github.com/jeonghanlee/pkg_automation/actions/workflows/rocky10.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/rocky10.yml)
[![macOS 26](https://github.com/jeonghanlee/pkg_automation/actions/workflows/macos26.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/macos26.yml)

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
- `build_epics_within_pkg_automation.bash` builds and installs EPICS through
  the external `EPICS-env` workflow from a Docker build context.
- `pkg-*` directories hold package-list fragments grouped by operating system
  family and functional category.

## Supported Targets

- Ubuntu 26.04 LTS (Resolute Raccoon), standard support through 2031-04
- Ubuntu 24.04 LTS (Noble Numbat), standard support through 2029-04
- Ubuntu 22.04 LTS (Jammy Jellyfish), standard support through 2027-04
- Debian 14 testing (Forky)
- Debian 13 (Trixie)
- Debian 12 (Bookworm)
- Rocky Linux 8 (Green Obsidian)
- Rocky Linux 9 (Blue Onyx)
- Rocky Linux 10 (Red Quartz)
- macOS 26 Tahoe with Homebrew

The Homebrew package path is available for macOS 11 Big Sur through macOS 15
Sequoia and macOS 26 Tahoe. macOS installs are not covered by the GitHub
Actions workflow set except for macOS 26 Tahoe.

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

Use `-v` to verify at the end of supported Debian package paths that
`python` resolves to Python 3.

```bash
bash pkg_automation.bash -y -v
```

The installer uses `/etc/os-release` as parsed data and does not source it as
shell code. Package lists are read line by line, comments are skipped, Windows
carriage returns are stripped, and package names are installed through quoted
Bash arrays.

At startup, the installer unsets `BASH_ENV` and `ENV`, sets `umask 022`, and
exports a constrained command `PATH`. The macOS branch keeps Homebrew command
directories ahead of `/usr/bin` so Homebrew-managed tools are selected where
the package path expects them.

## EPICS Build Helper

`build_epics_within_pkg_automation.bash` expects to run from a directory that
contains the Docker build context. The optional first argument sets the
installation prefix; `/usr/local` is used when no argument is provided.

```bash
bash build_epics_within_pkg_automation.bash /usr/local
```

The helper clones `EPICS-env`, writes `CONFIG_SITE.local`, runs the EPICS-env
initialization and build targets, then creates the versioned EPICS symlinks.
It unsets `BASH_ENV` and `ENV` and sets `umask 022`, but it preserves the
caller `PATH` so compiler, cross-toolchain, and ccache selections inherited by
the EPICS build are not discarded.

## Rocky Python Command

The project selects `/usr/bin/python3` as the unversioned `python` interpreter
on Rocky 8, 9, and 10. `ROCKY_PYTHON_TARGET` declares this selection, and the
package lists install `python3-devel` to provide the interpreter.

The installer registers `/usr/local/bin/python` in the dedicated
`pkg-automation-python` alternatives group and explicitly selects the target
in manual mode. This command takes precedence on the installer's PATH and
remains separate from Python RPM scriptlets that manage `/usr/bin`.

Rocky 8 also selects the target in the distribution's existing `python`
alternatives group, which manages `/usr/bin/unversioned-python` and its
`/usr/bin/python` slave. Rocky 9 and 10 retain the package-owned command from
`python-unversioned-command`. The selected target is therefore available
through `python` with or without `/usr/local/bin` on PATH.

Existing `/usr/local/bin/python` symlinks to `/usr/bin/python`,
`/usr/bin/unversioned-python`, or `/usr/bin/python3` are converted to the
dedicated alternatives group. Other files and symlinks at that path are
preserved, and installation fails with an explicit error.

Each Rocky installation verifies both the resolved command path and its
Python 3 interpreter before returning. Re-running installation restores the
configured selection if the dedicated group points elsewhere.

## Debian Python Command

Debian 12, Debian 13, and Debian 14 (testing) keep the unversioned `python`
command package-based through `python-dev-is-python3`, which depends on
`python-is-python3`. When
`-v` is supplied, the installer verifies the package result with
`command -v python` and `python --version` after package installation.

## Validation

The Bash sources are expected to pass:

```bash
bash -n pkg_automation.bash
bash -n build_epics_within_pkg_automation.bash
bash -n tests/rocky-python.bash
```

```bash
shellcheck -x pkg_automation.bash build_epics_within_pkg_automation.bash tests/rocky-python.bash
```

Run the Rocky integration test as root inside a disposable Rocky 8, 9, or 10
container:

```bash
bash tests/rocky-python.bash
```

The test runs the complete installer and actual RPM transactions. It checks
interpreter identity on normal and system-only PATHs, additional Python
installation on Rocky 8, provider reinstallation, manual selection with a
higher-priority candidate, selection repair, legacy symlink migration, and
preservation of unmanaged commands. Logs, native installer statuses, and
source hashes are retained in `pkg-python.*` under `${TMPDIR:-/tmp}`. Rocky
CI runs this test and uploads its evidence even when a check fails.

## Operational Notes

- Package installation can remove or disable selected services on RPM-family
  systems, including PackageKit and firewalld.
- On Rocky systems, the installer provides an unversioned `python` command for
  EPICS build tooling.
- Package lists are tailored for this EPICS development environment and are not
  a generic baseline for all hosts.
- New distribution versions require explicit package-list review before they
  should be treated as supported targets.
