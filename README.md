## To install (as root)
    make install

## To uninstall (also as root)
    make uninstall

## Dependencies:
- bash
- cgroup support
    - Check `/proc/filesystems` for cgroup
    - net_cls

      Check with `lssubsys -a`. Your kernel probably does not have this. Why? 
Who knows. You can enable it with `CONFIG_CGROUP_NET_CLASSID`.
- iptables
     - modules
        - comment
        - cgroup
        - udp
        - tcp
- if test_ping=1, cgexec from libcgroup

