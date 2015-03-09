#!/bin/bash

logging=0
block_eth=eth0
ping_test_ip=8.8.8.8
test_ping=1

ping=/usr/bin/ping
iptables=/usr/local/sbin/iptables
mount=/usr/bin/mount
mkdir=/usr/bin/mkdir
cgexec=/usr/bin/cgexec
iptables_tag=transmission
add_tag="-m comment --comment $iptables_tag"

remove_rules (){
    rules=`mktemp`
    iptables -S -t mangle | grep "\--comment $iptables_tag" | sed 's/^-A/-D/' > "$rules"
    if [ `wc -l < $rules` -gt 0 ]; then
	cat "$rules" | xargs -l iptables -t mangle
    fi
    rm -f "$rules"
}

if [ "$1" = "-r" ]; then
    echo "removing iptables rules"
    remove_rules
    exit
fi

# seconds to wait for ping response
ping_timeout=5

#!@todo check if mounted; seems to fail gracefully anyway
# mount net_cls cgroup subsystem
"$mount" -t cgroup -onet_cls net_cls /sys/fs/cgroup/net_cls
test -d /sys/fs/cgroup/net_cls || (>&2 echo "Unable to mount net_cls cgroup"; exit 1)

# create new child cgroup
"$mkdir" -p /sys/fs/cgroup/net_cls/vpn

# set cgroup packet id
echo 1 > /sys/fs/cgroup/net_cls/vpn/net_cls.classid

# allow any user to add a process to the cgroup. Super dangerous?
chmod go+w /sys/fs/cgroup/net_cls/vpn/{cgroup.procs,tasks}

# /etc/iproute2/rt_tables entry 11 is vpn
"$iptables" -t mangle -A OUTPUT -m cgroup --cgroup 1 -j MARK --set-mark 11 $add_tag
"$iptables" -t mangle -A OUTPUT -m mark --mark 11 -p tcp --sport 9091 -j ACCEPT $add_tag
if [ "$logging" != 0 ]; then
    "$iptables" -t mangle -A OUTPUT -m mark --mark 11 -o "$block_eth" -j LOG $add_tag
fi
"$iptables" -t mangle -A OUTPUT -m mark --mark 11 -o "$block_eth" -j DROP $add_tag

# drop packets destined for the transmission port coming in on the
# main interface
if [ "$logging" != 0 ]; then
    "$iptables" -t mangle -A INPUT -p tcp --dport 51413 -i "$block_eth" -j LOG $add_tag
    "$iptables" -t mangle -A INPUT -p udp --dport 51413 -i "$block_eth" -j LOG $add_tag
fi
"$iptables" -t mangle -A INPUT -p tcp --dport 51413 -i "$block_eth" -j DROP $add_tag
"$iptables" -t mangle -A INPUT -p udp --dport 51413 -i "$block_eth" -j DROP $add_tag

if [ -n "$test_ping" ]; then
    # test outgoing packet from cgroup on blocked interface.
    "$cgexec" -g net_cls:vpn "$ping" -c 1 -I "$block_eth" -W "$ping_timeout" "$ping_test_ip"
    blocked_status=$?

    if [ "$blocked_status" = 0 ]; then
	>&2 echo "Ping from cgroup succeeded! Failed to block cgroup from $block_eth. "
	exit 1
    fi

    # this will only succeed if you have a route through another interface
    # defined; e.g. vpn
    "$ping" -c 1 -W "$ping_timeout" "$ping_test_ip"
    unblocked_status=$?
    if [ "$unblocked_status" != 0 ]; then
	>&2 echo "Unblocked ping error. Maybe your network is down?"
    fi
fi
