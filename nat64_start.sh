#!/bin/sh

##################################################################################
#
#  Copyright (C) 2016 Craig Miller
#
#  See the file "LICENSE" for information on usage and redistribution
#  of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#  Distributed under GPLv2 License
#
##################################################################################


#
# Script to start tayga (NAT 64) server on OpenWRT
#
# Craig Miller 9 July 2016
#

#
# Define interfaces
#
# get WAN interface from UCI
WAN=$(/sbin/uci get network.wan.ifname)
WAN6=""

# Define files
tayga_conf="/etc/tayga.conf"

# Devine Vars
NAT64_PREFIX="64:ff9b::/96"
#NAT64_PREFIX="2001:470:ebbd:ff9b::/96"

# script version
VERSION=1.0


usage () {
	# show help
	echo "help is here"
	echo "	$0 - sets up tayga.conf, creates tun device, and starts tayga (NAT64)"
	echo "	-w <int>   WAN interface of the router, typically eth1 or eth0.2"
	echo "	-6 <int>   IPv6 WAN interface, if different from above"
	echo "	-h         this help"
	echo "  "
	echo " By Craig Miller - Version: $VERSION"
	exit 1
}



# default options values
DEBUG=0
numopts=0
# get args from CLI
while getopts "?hdw:6:" options; do
  case $options in
    w ) WAN=$OPTARG
    	numopts=$((numopts+2));;
    6 ) WAN6="$OPTARG"
        numopts=$((numopts+2));;	
    d ) DEBUG=1
		numopts=$((numopts+1));;
    h ) usage;;
    \? ) usage	# show usage with flag and no value
         exit 1;;
    * ) usage		# show usage with unknown flag
    	 exit 1;;
  esac
done

# remove the options as cli arguments
shift $((numopts))

# check that there are no arguments left to process
if [ $# -ne 0 ]; then
	usage
	exit 1
fi

# if no IPv6 WAN interface specified, use the normal WAN interface
if [ -z "$WAN6" ]; then
        WAN6="$WAN"
fi

echo "=== Check that WAN interface is present and up"
i=0
max=5
while true; do
	i=$((i+1))
	if [ $i -gt $max ]; then 
		echo "=== Is $WAN the correct WAN interface?" 
		# exit the script
		exit 1 
	fi
	
	# is $WAN present and UP?
        ip link show dev "$WAN" | grep 'state UP'
        if [ $? -eq 0 ]; then
                break
        fi
	
	# sleep if not invoked from terminal
	if [ ! -t 1 ]; then
		sleep 10
	fi
done



# get some IP addresses from Router
i=0
max=5
while true; do
        i=$((i+1))
        if [ $i -gt $max ]; then
                break
        fi
 
        # Are all required IP addresses available?
        LAN_IP6=$(ip -6 addr | grep '::1' | grep noprefixroute | grep -v 'deprecated' | grep -v 'inet6 fd' | awk '{print $2}' | cut -f 1 -d '/')
        WAN_IP4=$(ip -4 addr show dev "$WAN" | grep 'inet' | awk '{print $2}' | cut  -f 1 -d '/')
        WAN_IP6=$(ip -6 addr show dev "$WAN6" | grep -v 'deprecated' | grep 'global' | head -1| awk '{print $2}' | cut  -f 1 -d '/')
        if [ -n "$WAN_IP4" ] && [ -n "$WAN_IP6" ] && [ -n "$LAN_IP6" ]; then
                break
        fi

        # sleep if not invoked from terminal
        if [ ! -t 1 ]; then
                echo "Waiting for IP address..."
                sleep 10
        fi
done

echo "=== Collected address info:"
echo "=== WAN4 $WAN_IP4"
echo "=== WAN6 $WAN_IP6"
echo "=== LAN6 $LAN_IP6"
echo "=== NAT64 Prefix $NAT64_PREFIX"

# test no GUA on WAN
#WAN_IP6=""


# check that the addresses have been collected
if [ -z "$LAN_IP6" ]; then
	echo "ERROR: LAN GUA IPv6 not detected. NAT64 requires end to end IPv6 connectivity"
	exit 1
fi
if [ -z "$WAN_IP6" ]; then
	echo "WARNING: WAN GUA IPv6 not detected. NAT64 requires end to end IPv6 connectivity, NAT64 may not work properly"
	#exit 1
fi
if [ -z "$WAN_IP4" ]; then
	echo "ERROR: WAN GUA IPv4 not detected. NAT64 requires WAN IPv4 connectivity"
	exit 1
fi


# remove old NAT64 firewall entries
iptables -D forwarding_rule -i nat64 -j ACCEPT
ip6tables -D forwarding_rule -o nat64 -j ACCEPT


# tayga info from tayga website http://www.litech.org/tayga/

# kill any existing tayga to clean up
killall tayga

# make tayga db dir
msg=$(mkdir -p /tmp/db/tayga 2>&1)

# create tayga config file
msg=$(mv $tayga_conf $tayga_conf.old 2>&1)

touch $tayga_conf
echo "tun-device nat64" >> $tayga_conf
echo "ipv4-addr 192.168.2.1 " >> $tayga_conf	 
echo "prefix  $NAT64_PREFIX  " >> $tayga_conf	 
echo "ipv6-addr $LAN_IP6" >> $tayga_conf
echo "dynamic-pool 192.168.2.0/24" >> $tayga_conf
echo "data-dir /tmp/db/tayga" >> $tayga_conf

if [ $DEBUG -eq 1 ]; then echo "=== tayga.conf file"; cat $tayga_conf; fi

# configure tun interface and start tayga
echo "=== Making tun device: nat64"
tayga --mktun
ip addr flush nat64
ip link set nat64 up

# clear nat64 dynamic map
[ -s /tmp/db/tayga/dynamic.map ] && rm /tmp/db/tayga/dynamic.map

ip addr add "$WAN_IP4" dev nat64	   		
#ip addr add "$WAN_IP6" dev nat64
#ip addr add "192.168.2.1" dev nat64	   		
#ip addr add $LAN_IP6 dev nat64
ip route add 192.168.2.0/24 dev nat64
ip route add $NAT64_PREFIX dev nat64

# add NAT64 firewall entries (required for LEDE)
iptables -A forwarding_rule -i nat64 -j ACCEPT
ip6tables -A forwarding_rule -o nat64 -j ACCEPT

# start NAT64
tayga &

# test connection
echo "=== Testing tayga"
NAT64_FRONT=$(echo $NAT64_PREFIX | cut -d '/' -f 1)
ping6 -c3 $NAT64_FRONT"8.8.4.4"

echo "Pau!"




