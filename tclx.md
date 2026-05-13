# TclX Source Installation

## Scope

This document covers the manual TclX source installation path used when the
distribution package set does not provide the required TclX layout.

**Out of scope:** General Tcl/Tk installation policy and EPICS module build
configuration.

## Procedure

Install the Tcl and Tk development packages, build TclX from the FlightAware
source repository, and expose the installed TclX directory through the expected
Tcl 8.6 package path.

```bash
sudo yum install tcl-devel tk-devel
```

```bash
git clone https://github.com/flightaware/tclx
```

```bash
cd tclx
```

```bash
git checkout tags/v8.4.3
```

```bash
./configure
```

```bash
make
```

```bash
sudo make install
```

```bash
sudo ln -sf /usr/lib/tclx8.6/ /usr/share/tcl8.6/tclx8.6
```

## Scripted Path

`pkg_automation.bash` retains `install_tclx_centos8` for the same source-build
path. The function uses a dedicated workspace under `$HOME/.tclx`, checks for
an existing TclX package directory, and removes only the immediate contents of
that workspace before cloning the source repository.
