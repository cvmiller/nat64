## NAT64 on OpenWRT 

An IPv6 to IPv4 protocol translator for OpenWRT Chaos Calmer (15.05.1).

### Why?

Although running dual stack is the preferred transition method for IPv6, it makes the network more complex, since two protocols need to be run (v4 & v6). A clear way to simply the network is to only run one networking protocol. Since you will want to migrate to IPv6 eventually, the simple choice is to move to an IPv6-only network.

### Creating an IPv6-only network

It is actually quite easy, just disable the DHCPv4 server on the router. No clients will obtain an IPv4 address, and therefore the client nodes will *have* to use IPv6 to get out.

### It is Dark out there

But you will quickly discover that much of the world's content is still only served on the legacy, IPv4, protocol. This is where **NAT64** comes in. Although it is called NAT (Net Address Translation), it translates from IPv6 to IPv4 and back again, allowing IPv6-only clients to connect to all that legacy connected content.

### What is needed?

An OpenWRT-based router, preferably running the latest release, Chaos Calmer (15.05.1). 
* A package from the past **tayga** (available from 12.09)
* a little configuration, a script to start-up the **tayga** daemon
* Google's DNS64 service.

### Getting Tayga

The devs dropped the **tayga** package way back in 2012, but fortunately, it still works, *mostly*. My router is a **brcm47xx**-based, you will want to make sure you use the correct architecture for your router. You can find tayga in:
```
https://downloads.openwrt.org/attitude_adjustment/12.09/brcm47xx/generic/packages/
```
Download it to your computer, then `scp` it over to your router, preferable the /tmp/ directory (since it is writable). Once it is on the router, update the package list, install the tun device, and then install the `tayga` package with `opkg`
```
opkg update
opkg install kmod-tun
opkg install tayga-xxx.pkg
```

The tayga package will pull in the `ip` package as well, so make sure your router is connected to the internet.

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

If you aren't running an internal DNS server, give some thought to doing so, it will make managing IPv6 *much* easier. The DNS servers and search domain will be announced in the RA (Router Advertisement) as well as via DHCPv6. Android/ChomeOS don't do DHCPv6, and Apple/Windows do.

Once the UCI configuration files are edited, restart networking with:
```
/etc/init.d/networking restart
```

### A little knowledge

In a perfect world, the old version of tayga would read the UCI configuration file, and be started. Alas, it is from a past release, and for some reason doesn't read the UCI config. So we'll use a script to setup and start `tayga`. This is a little hack to get NAT64 up and running on Chaos Calmer (15.05.1).

But before we run the script, we need to know what is the WAN interface? Usually `eth1` or `eth0.2`

You can find this by looking at `ip addr` on your router and seeing what interface has the outside/public IPv4 address.

### Starting tayga

`scp` the `nat64_start.sh` script to the router, and store it in /root, so it will be there on the next reboot.

Feed the WAN interface via a command line parameter `-w`, and sit back and let the script to its work.
```
/root/nat64_start.sh -w eth0.2
```

### Testing NAT64

At the end of the script, it will ping6 Googles IPv4 DNS server 8.8.4.4. If you see echo returns, then NAT64 is up and running, congratulations! Enjoy the simplicity of an IPv6-only network, and all the legacy attached content.

### Rebooting with NAT64

If you want NAT64 to be up and running the next time you reboot the router, you will need to add it to the start up items in Luci under System->Startup (at the bottom). Add the following **before** the `exit 0`:
```
# Start tayga NAT64 daemon
/root/nat64_start.sh -w eth0.2

```
For those who prefer CLI, add the above two lines to /etc/rc.local 

Now when your router reboots, NAT64 will be automatically enabled!

- - -
### Background info

#### So how does NAT64 work?

**NAT64** relies on **DNS64** to provide a *fake* address to the client when it requests a DNS lookup. The *fake* address starts with the prefix `64:ff9b::/96` and the last 32 bits of the address are actually the IPv4 address of the DNS Query.

The client (e.g. your laptop) then attempts to open a connection to the *fake* address, which your router will pickup, *see* the real IPv4 address embedded, and make a connection to the legacy connected site. It reverses the process for any data returned by the legacy connected site.

You don't have to use Google's **DNS64** service, you can roll your own, but that is beyond the scope of this little nat64 start script.

#### More info about tayga

If you wish to know more about `tayga` please look at the official [tayga website](http://www.litech.org/tayga/).

### About the Script Author

Craig Miller has been an IPv6 advocate since 1998 when he then worked for Bay Networks. He has been working professionally in Telecom/Networking ever since. Look for his other OpenWRT projects, [v6 Brouter](https://github.com/cvmiller/v6brouter) a script to extend a /64 network (when upstream won't give you your own /64) and [v6disc](https://github.com/cvmiller/v6disc) an IPv6 discovery script.






