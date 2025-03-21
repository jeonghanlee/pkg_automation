# Package Installation Script for the EPICS environment and my personal environment.
[![Linux Build](https://github.com/jeonghanlee/pkg_automation/actions/workflows/linux.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/linux.yml)
[![Debian 13](https://github.com/jeonghanlee/pkg_automation/actions/workflows/debian13.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/debian13.yml)
[![Debian 12](https://github.com/jeonghanlee/pkg_automation/actions/workflows/debian12.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/debian12.yml)
[![Rocky Linux 9](https://github.com/jeonghanlee/pkg_automation/actions/workflows/rocky9.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/rocky9.yml)
[![Ubuntu 22 LTS](https://github.com/jeonghanlee/pkg_automation/actions/workflows/ubuntu22.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/ubuntu22.yml)
[![macOS build](https://github.com/jeonghanlee/pkg_automation/actions/workflows/macos.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/macos.yml)

It is the most cumbersome thing that is to install required packages for the EPICS base, modules, and other applications in different Linux flavors. This ugly script helps me to save my time to install many packages among many Linux distributions.
And it was tested with the following distributions:

## Tested

### Focus

* Debian 13 testing (Trixie)
* Debian 12 (Bookworm)
* Debian 11 (Bullseye)
* Rocky 9 (Blue Onyx)
* Rocky 8 (Green Obsidian)
* macOS 13 (Ventura, with brew)

### Eye

* Debian 10 (Buster)
* Ubuntu 22.04 LTS (Jammy Jellyfish)
* Fedora 32
* Ubuntu 18.04/20.04
* Raspbian GNU/Linux 10
* macOS 12.0.1 (21A559)
* macOS 11.1 (20C69)
* macOS 11

### Obsolete 
* ~~Scientific Linux 7~~
* ~~CentOS 8~~
* ~~CentOS 7~~
* ~~Alma 8~~


And sudo permission is needed. 

## Procedure

Note that there are various examples in the `.github/workflow` path.

```
$ bash pkg_automation.bash 
> This procedure could help to install
> required packages for EPICS installation
> and others.
>
> Rocky or Alma is detected as Rocky Linux 9.0 (Blue Onyx)
>> Do you want to continue (y/N)?
```
## Notice
* Note that it will remove several packages in CentOS (e.g., PackageIt, Firewalld). 
* Note that all packages are useful for my own environment, not for general purposes.
* Note that sometimes, it doesn't support the latest Linux distribution. In that case, please create an issue. 
