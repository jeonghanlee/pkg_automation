# Package Installation Script for the EPICS environment and my personal environment.

It is the most cumbersome thing that is to install required packages for the EPICS base, modules, and other applications in different Linux flavors. This ugly script helps me to save my time to install many packages among many Linux distributions.
And it was tested with the following distributions:

* CentOS 
* Debian 
* Ubuntu 
* LinuxMint
* Fedora
* Raspbian
* Rocky 8

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
