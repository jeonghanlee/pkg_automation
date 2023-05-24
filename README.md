# Package Installation Script for the EPICS environment and my personal environment.
[![Linux Build](https://github.com/jeonghanlee/pkg_automation/actions/workflows/linux.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/linux.yml)
[![Debian 12 testing](https://github.com/jeonghanlee/pkg_automation/actions/workflows/debian12.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/debian12.yml)
[![Rocky Linux 9](https://github.com/jeonghanlee/pkg_automation/actions/workflows/rocky9.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/rocky9.yml)
[![Ubuntu 22 LTS](https://github.com/jeonghanlee/pkg_automation/actions/workflows/ubuntu22.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/ubuntu22.yml)
[![macOS build](https://github.com/jeonghanlee/pkg_automation/actions/workflows/macos.yml/badge.svg)](https://github.com/jeonghanlee/pkg_automation/actions/workflows/macos.yml)

It is the most cumbersome thing that is to install required packages for the EPICS base, modules, and other applications in different Linux flavors. This ugly script helps me to save my time to install many packages among many Linux distributions.
And it was tested with the following distributions:

* CentOS 7/8 (Github Action)
* Debian 10/11 (Github Action)
* Ubuntu 20 (Github Action)
* LinuxMint
* Fedora
* Raspbian
* Rocky 8/9(WIP) (Github Action)
* Alma 8 (Github Action)
* macOS 11 (Github Action runner with brew)
* macOS 12 (with brew)

And sudo permission is needed. 

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
