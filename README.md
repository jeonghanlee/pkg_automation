# pkg_automation

It is the most cummbersome thing that is to install required packages for the EPICS base, modules, and other applications in different Linux flavors. Most frequent used Linux flavors are CentOS and Debian. Thus, this script covers only these Linux one. 

It is tested with CentOS 7, and Debain 8. And sudo permission is needed. 

```
$ bash pkg_automation.bash 

>>>> CentOS is detected as CentOS Core 7.4.1708
>>>> Do you want to continue (y/n)?

```

```
$ bash pkg_automation.bash

>>>> Debian is detected as Debian jessie 8.9
>>>> Do you want to continue (y/n)?
```

## Notice

Please run twice in CentOS due to epel packages...
