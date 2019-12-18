# lpkglib

Core library of functions and configuration for the Linux Package system from AltimatOS.

To install, run the following commands:

```sh
git clone git@github.com:AltimatOS/lpkglib
cd lpkglib
sudo make install
```

Note, the tools for AltimatOS do not conform to the traditional Linux FHS layout. Most
tools are installed in /System, and notably use /System/cfg instead of /etc. While /etc
exists as a symbolic link to /System/cfg, this is mostly for compatibility with software
originally designed for GNU and other Unix-like systems.
