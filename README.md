## To install (as root)
    make install

## To uninstall (also as root)
    make uninstall

## To run (as root)
    net_cgroup.sh

## To remove `iptables` rules (did you notice a theme?)
    net_cgroup.sh -r

## What does it do?
The `net_cgroup.sh` script creates a cgroup and prevents processes in the 
cgroup from accessing a specific network interface. It is designed for 
[Transmission](http://www.transmissionbt.com/), a BitTorrent client that lacks 
built-in proxy support. The intended use case is to force Transmission to use a 
VPN network interface. You could also accomplish most of this with a new 
routing table for the marked packets, but this method has the disadvantage of 
being disabled upon `openvpn` exit.

When run in the created cgroup, Transmission will be blocked from sending and 
receiving packets over the specified interface (eth0 by default), with some 
exceptions for the web interface.

I prefer this method of restricting network access over other options for the 
following reasons:
 - I don't have to bother recompiling Transmission, so I can use precompiled 
packages
 - There's no easy way (that I know of) to bind to a specific network interface 
in Linux
 - Binding to an IP address only works as long as the address is available

## Dependencies:
- `bash`
- cgroup support
    - Check `/proc/filesystems` for cgroup
    - net_cls

      Check with `lssubsys -a`. Your kernel probably does not have this. Why? Who knows. You can enable it with `CONFIG_CGROUP_NET_CLASSID` [since Linux 3.14](http://cateee.net/lkddb/web-lkddb/CGROUP_NET_CLASSID.html).
- `iptables`
     - modules
        - comment
        - cgroup
        - udp
        - tcp
        - mark (currently used, but could be replaced with cgroup)
- if test_ping=1, `cgexec` from libcgroup

