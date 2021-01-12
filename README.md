## NAT64 on OpenWRT 

An IPv6 to IPv4 protocol translator for OpenWRT Chaos Calmer (15.05.1), LEDE 17.01.02, OpenWrt 18.06.1, and OpenWrt 19.07.x

### Why?

Although running dual stack is the preferred transition method for IPv6, it makes the network more complex, since two protocols need to be run (v4 & v6). A clear way to simplify the network is to only run one networking protocol. Since you will want to migrate to IPv6 eventually, the simple choice is to move to an IPv6-only network.

### Creating an IPv6-only network

It is actually quite easy, just disable the DHCPv4 server on the router. No clients will obtain an IPv4 address, and therefore the client nodes will *have* to use IPv6 to get out.

### It is Dark out there

But you will quickly discover that much of the world's content is still only served on the legacy, IPv4, protocol. This is where **NAT64** comes in. Although it is called NAT (Net Address Translation), it translates from IPv6 to IPv4 and back again, allowing IPv6-only clients to connect to all that legacy connected content.

### What is needed?

An OpenWRT-based router, preferably running the latest release, Chaos Calmer (15.05.1), or LEDE 17.01.02, or the latest OpenWrt (v19.07.x)
* A package from the past **tayga** (for OpenWrt available from 12.09)
* a little configuration, a script to start-up the **tayga** daemon
* Google's DNS64 service.

- - - 
## UPDATE: January 2021

THIS SCRIPT is **NO** longer necessary for OpenWrt

Rather than using `tayga` (below), an easier, more modern software package called **Jool** has been implemented on **OpenWrt v19.07.x**.

To install Jool:
```
opkg update
opkg install kmod-jool
```

To start the Jool NAT64 service:
```
/sbin/insmod jool pool6=64:ff9b::/96
```

To make the NAT64 service start when the router is rebooted, add the `insmod` line to your `/etc/rc.local`

**And you are done!** No need to create config files or change any existing ones. Recommend using `jool` over `tayga` for OpenWrt 19.07.x and newer.

- - -

### Getting Tayga for OpenWrt (v15.05) (Old Method)

The OpenWrt devs dropped the **tayga** package way back in 2012, but fortunately, it still works, *mostly*. My router is a **brcm47xx**-based, you will want to make sure you use the correct architecture for your router. You can find tayga in:
```
https://downloads.openwrt.org/attitude_adjustment/12.09/brcm47xx/generic/packages/
```
Download it to your computer, then `scp` it over to your router, preferable the /tmp/ directory (since it is writable). Once it is on the router, update the package list, install the tun device, and then install the `tayga` package with `opkg`
```
opkg update
opkg install kmod-tun
opkg install tayga
```

The tayga package will pull in the `ip` package as well, so make sure your router is connected to the internet.

### Getting Tayga for LEDE (v17.04) and OpenWrt (v18.06.x & 19.07.x)

Getting **tayga** for LEDE is even easier, as it is part of the distro, and can be installed directly.
```
opkg update
opkg install tayga-xxx.pkg
```
Because **tayga** is part of the disto, it will automatically pull in dependencies like the tun kernel module.

### Configuring OpenWRT for NAT64

You will need to edit the /etc/config/network and /etc/config/dhcp files. Add the following to /etc/config/network, which will show the nat64 interface in Luci properly:
```
config interface 'nat64'
	option proto 'tayga'
	option ifname 'nat64'

```

And edit the /etc/config/dhcp file to include RDNSS pointing to Google's DNS64 server:
```
config dhcp 'lan'
	option interface 'lan'
	option dhcpv6 'server'
	option ra_management '1'
	option ignore '1'
	option ra 'server'
	list domain 'mydomain.com'	#your search domain
	list dns '2001:db8:1d:583:211:24ff:fee1:dbc8'	#your internal DNS server
	list dns '2001:4860:4860::6464'	#Google DNS64 server
```

The DNS servers and search domain will be announced in the RA (Router Advertisement) as well as via DHCPv6. Android/ChomeOS don't do DHCPv6, and Apple/Windows do. **As of April 2017**, Windows 10 can work in a SLAAC-only network, as it now supports the RDNSS field in the RA.

#### DNS and ip6neigh
If you aren't running an internal DNS server, give some thought to doing so. And it is really easy with [ip6neigh](https://github.com/AndreBL/ip6neigh/) running on your OpenWrt router. It is a project, which *automatically* populates DNS on your router with IPv6 host names, making running a local DNS a snap, and it will make your IPv6 life *much* easier.

### Running your own DNS64 Server

It is easy to use Google's DNS64 server, but you may want to not be tracked by Google, or just want to have a DNS server closer to your network.

Setting up your own DNS64 server is not all that difficult if you have minimal experience with the ISC DNS server (**bind9**). First step is to install **bind9** using **apt-get** or **yum** (depending on your distro).

Once **bind9** is installed, edit ` /etc/bind/named.conf.options` file adding the following:

```
// DNS64 config
auth-nxdomain no;
listen-on-v6 { any; };
allow-query { any; };

// set to NAT64 prefix
dns64 64:ff9b::/96 {
    clients { any; };
};
```

Restart **bind9** and then test with:

```
$ host twitter.com localhost
twitter.com has IPv6 address 64:ff9b::68f4:2ac1
twitter.com has IPv6 address 64:ff9b::68f4:2a41
```

Once you have your own DNS64 server up and running, update the 'list DNS' address in `/etc/config/network` on your router to advertise your DNS64 server.

#### Running DNS64 on your OpenWrt Router

You don't need to run a different DNS server, if you aren't already running one for DNS64. You can actually run bind9 (aka `named`) on the OpenWrt router. By doing the following you will have DNS64/NAT64 running all on one router.

 * Install bind9 on the router `opkg install bind-server bind-tools`
 * Disable `dnsmasq` on the router, as it conflicts with `named` <br>
	`/etc/init.d/dnsmasq disable`
 * Apply the bind9 config (above) to `/etc/bind/named.conf` file
 * Start the bind9 daemon `/etc/init.d/named start`

If you have your own DNS server at home, you can point to it using bind-config. at the bottom of `/etc/bind/named.conf` add:

```
// point to your house DNS Domain e.g. myHouseDNS.net         
zone "myhousedns.net" IN {         
    type forward;               
    forwarders {  
        // The address of your House DNS server              
        2001:db8:8011:fd11::1;       
    };                          
};                               
```

Now any DNS requests to your local domain (e.g. myhousedns.net) will be directed to your in-house DNS server, and the rest of the requests, will be served with Synthesized IPv6 addresses (for IPv4-only servers out on the internet).

After adding your house DNS server forwarding lines, remember to restart `named` with `/etc/init.d/named restart`

Note: `ip6neigh **does not** work with bind9.



#### Restart networking

Once the UCI configuration files are edited, restart networking with:

```
/etc/init.d/networking restart
```


### A little knowledge

In a perfect world, the old version of tayga would read the UCI configuration file, and be started. Alas, it is from a past release, and for some reason doesn't read the UCI config. So we'll use a script to setup and start `tayga`. This is a little hack to get NAT64 up and running on OpenWrt & LEDE Routers (15.05 thru to the cutrent 19.07.x).

But before we run the script, we need to know what is the WAN interface? Usually `eth1` or `eth0.2`

You can find this by looking at `ip addr` on your router and seeing what interface has the outside/public IPv4 address.

As of version 1.1, the `nat64_start.sh` will automatically detect your `WAN` interface, except for PPPoE WANs.

### Starting tayga

`scp` the `nat64_start.sh` script to the router, and store it in /root, so it will be there on the next reboot.

Run the nat64_start.sh script. If using PPPoE for your ISP connection, then feed the PPPoE WAN interface via a command line parameter `-w`, and sit back and let the script to its work.
```
/root/nat64_start.sh -w eth0.2
=== Check that WAN interface is present and up
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
=== Collected address info:
=== WAN4 107.190.20.37
=== WAN6 2001:470:ebad::221:29ff:fec3:6cb0
=== LAN6 2001:470:ebad:8::1
=== NAT64 Prefix 64:ff9b::/96
killall: tayga: no process killed
=== Making tun device: nat64
Created persistent tun device nat64
=== Testing tayga
PING 64:ff9b::8.8.4.4 (64:ff9b::808:404): 56 data bytes
64 bytes from 64:ff9b::808:404: seq=0 ttl=54 time=16.104 ms
64 bytes from 64:ff9b::808:404: seq=1 ttl=54 time=15.813 ms
64 bytes from 64:ff9b::808:404: seq=2 ttl=54 time=16.953 ms

--- 64:ff9b::8.8.4.4 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 15.813/16.290/16.953 ms
Pau!

```

### Testing NAT64

At the end of the script, it will ping6 Googles IPv4 DNS server 8.8.4.4. If you see echo returns, then NAT64 is up and running, congratulations! Enjoy the simplicity of an IPv6-only network, and all the legacy attached content.

### Rebooting with NAT64

If you want NAT64 to be up and running the next time you reboot the router, you will need to add it to the start up items in Luci under System->Startup (at the bottom). Add the following **before** the `exit 0`:
```
# Start tayga NAT64 daemon
/root/nat64_start.sh 

```
For those who prefer CLI, add the above two lines to `/etc/rc.local` 

Now when your router reboots, NAT64 will be automatically enabled!

- - -
### Background info

#### So how does NAT64 work?

**NAT64** relies on **DNS64** to provide a *fake* address to the client when it requests a DNS lookup. The *fake* address starts with the prefix `64:ff9b::/96` and the last 32 bits of the address are actually the IPv4 address of the DNS Query.

The client (e.g. your laptop) then attempts to open a connection to the *fake* address, which your router will pickup, *see* the real IPv4 address embedded, and make a connection to the legacy connected site. It reverses the process for any data returned by the legacy connected site.

You don't have to use Google's **DNS64** service, you can roll your own, but that is beyond the scope of this little nat64 start script. (see *Running your own DNS64 server* for more info)

#### More info about tayga

If you wish to know more about `tayga` please look at the official [tayga website](http://www.litech.org/tayga/).

### Limitations

Dang those Limiations!

It has been called to my attention that the forked project, LEDE, of OpenWrt does **not** support the older OpenWrt packages. Fortunately, the LEDE Dev team have ported **tayga** package. However it still requires some setup to run, and the `nat64_start.sh` script has been updated to support LEDE routers as well as OpenWrt. Update 2018: As OpenWrt and LEDE re-merge, this script has been tested to ensure it works with version of OpenWrt 18.04 & 19.07

Some Topologies do not use a WAN GUA (Global Unique Address), and instead relay on link-local. This is also a correct topology. As of version 1.0, the script has been updated to support non-GUA-WAN topologies.



### About the Script Author

Craig Miller has been an IPv6 advocate since 1998 when he then worked for Bay Networks. He has been working professionally in Telecom/Networking ever since. Look for his other OpenWRT projects, [v6 Brouter](https://github.com/cvmiller/v6brouter) a script to extend a /64 network (when upstream won't give you your own /64), [v6disc](https://github.com/cvmiller/v6disc) an IPv6 discovery script, and running a [Virtual OpenWrt in a Linux Container LXD](https://github.com/cvmiller/openwrt-lxd).





