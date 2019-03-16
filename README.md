A Script of several packages installation for EPICS and personal environment.
---

[![Build Status](https://travis-ci.org/jeonghanlee/pkg_automation.svg?branch=master)](https://travis-ci.org/jeonghanlee/pkg_automation)

It is the most cumbersome thing that is to install required packages for the EPICS base, modules, and other applications in different Linux flavors. Most frequent used Linux flavors are CentOS and Debian. Thus, this script covers only these Linux one. 

It is tested with
* CentOS 
* Debian 
* Ubuntu 
* LinuxMint
* Fedora
* Raspbian

And sudo permission is needed. 

```
$ bash pkg_automation.bash 

>>>> CentOS is detected as CentOS Core 7.4.1708
>>>> Do you want to continue (y/n)?

```
## Notice
* Note that it will remove several packages in CentOS (e.g., PackageIt, Firewalld). 
* Note that all packages are useful for my own environment, not for general purposes.
* Note that sometimes, it doesn't support the latest Linux distribution. In that case, please create an issue. 
