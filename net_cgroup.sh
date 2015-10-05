#!/bin/bash

logging=0
block_eth=eth0
ping_test_ip=8.8.8.8
ping_test_ip6=2001:4860:4860::8888
test_ping=1

#!@todo get transmission port from config file
#!@todo get config file from command line

iptables_tag=transmission
add_tag="-m comment --comment $iptables_tag"

remove_rules (){
    rules=`mktemp`
    iptables-save -t mangle | grep -v "\--comment $iptables_tag" | iptables-restore
    ip6tables-save -t mangle | grep -v "\--comment $iptables_tag" | ip6tables-restore
}

if [ "$1" = "-r" ]; then
    echo "removing iptables rules"
    remove_rules
    exit
fi

#!@todo protect against multiple copies of rules in iptables

# seconds to wait for ping response
ping_timeout=5

#!@todo check if mounted; seems to fail gracefully anyway
# mount net_cls cgroup subsystem
mount -t cgroup -onet_cls net_cls /sys/fs/cgroup/net_cls
test -d /sys/fs/cgroup/net_cls || (>&2 echo "Unable to mount net_cls cgroup"; exit 1)

# create new child cgroup
mkdir -p /sys/fs/cgroup/net_cls/vpn

# set cgroup packet id
echo 1 > /sys/fs/cgroup/net_cls/vpn/net_cls.classid

# allow any user to add a process to the cgroup. Super dangerous?
chmod go+w /sys/fs/cgroup/net_cls/vpn/{cgroup.procs,tasks}

# /etc/iproute2/rt_tables entry 11 is vpn
iptables -t mangle -A OUTPUT -m cgroup --cgroup 1 -j MARK --set-mark 11 $add_tag
iptables -t mangle -A OUTPUT -m mark --mark 11 -p tcp --sport 9091 -j ACCEPT $add_tag
if [ "$logging" != 0 ]; then
    iptables -t mangle -A OUTPUT -m mark --mark 11 -o "$block_eth" -j LOG $add_tag
fi

# this prevents all outgoing packets from the affected cgroup from reaching the interface.
iptables -t mangle -A OUTPUT -m mark --mark 11 -o "$block_eth" -j DROP $add_tag

# drop packets destined for the transmission port coming in on the
# main interface
if [ "$logging" != 0 ]; then
    iptables -t mangle -A INPUT -p tcp --dport 51413 -i "$block_eth" -j LOG $add_tag
    iptables -t mangle -A INPUT -p udp --dport 51413 -i "$block_eth" -j LOG $add_tag
fi
iptables -t mangle -A INPUT -p tcp --dport 51413 -i "$block_eth" -j DROP $add_tag
iptables -t mangle -A INPUT -p udp --dport 51413 -i "$block_eth" -j DROP $add_tag

iptables-save -t mangle | egrep "\--comment $iptables_tag|&*mangle|COMMIT" | ip6tables-restore -nT mangle

if [ "$test_ping" != 0 ]; then
    # test outgoing packet from cgroup on blocked interface.
    # -r: bypass routing
    cgexec -g net_cls:vpn ping -c 1 -r -I "$block_eth" -W "$ping_timeout" "$ping_test_ip"
    blocked_status=$?

    if [ "$blocked_status" = 0 ]; then
	>&2 echo "Ping from cgroup succeeded! Failed to block cgroup from $block_eth. "
	exit 1
    fi

    cgexec -g net_cls:vpn ping6 -c 1 -r -I "$block_eth" -w "$ping_timeout" "$ping_test_ip6"   
    blocked_status6=$?
    
    if [ "$blocked_status6" = 0 ]; then
	>&2 echo "Ping6 from cgroup succeeded! Failed to block cgroup from $block_eth. "
	exit 1
    fi
    # cgexec -g net_cls:vpn ping -c 1 -r I eth0 -W 5 8.8.8.8

    # this will only succeed if you have a route through another interface
    # defined; e.g. vpn
    ping -c 1 -W "$ping_timeout" "$ping_test_ip"
    unblocked_status=$?
    if [ "$unblocked_status" != 0 ]; then
	>&2 echo "Unblocked ping error. Maybe your network is down?"
    fi

    ping6 -c 1 -w "$ping_timeout" "$ping_test_ip6"
    unblocked_status6=$?
    if [ "$unblocked_status6" != 0 ]; then
	>&2 echo "Unblocked ping6 error. Maybe your network is down?"
    fi    

fi
