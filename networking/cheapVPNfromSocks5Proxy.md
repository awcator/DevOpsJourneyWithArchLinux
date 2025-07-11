# What is this
Suppose you have a VPN session on Windows and want to connect to this existing, valid VPN session from another machine where you don't have VPN credentials or setup.

here I'm creating port 4444 on Windows, port 4445 on WSL, for socks5 proxy, refer [this](https://github.com/awcator/DevOpsJourneyWithArchLinux/blob/master/networking/wsl_portfoward.ps1)
Once ports are opened, follow these on the other machine
```
                         [ Linux App ]
                         +--------------------+
                         |  Connects to       |
                         |  localhost:4444    |
                         +---------+----------+
                                   |
                                   v
                      +--------------------------+
                      |   iptables REDIRECT rule |
                      |  (Port 4444 → REDSOCKS)  |
                      +------------+-------------+
                                   |
                                   v
                      +--------------------------+
                      |         redsocks         |
                      |  Listens on 127.0.0.1:12345 |
                      |  Forwards using SOCKS5   |
                      |  To: WSL_IP:4445         |
                      +------------+-------------+
                                   |
                                   v
                      +--------------------------+
                      |   WSL2 Instance (on Win) |
                      |  Service on port 4445    |
                      +------------+-------------+
                                   |
                                   v
                +----------------------------------------+
                | Windows Host with Active VPN Session   |
                |  All outbound WSL traffic exits here   |
                |  VPN handles DNS + secure routing      |
                +----------------+-----------------------+
                                 |
                                 v
                    [ Internet via VPN Provider ]
sudo pacman -S redsocks iptables        # Arch

```
/etc/redsocks.conf
```
base {
	// debug: connection progress & client list on SIGUSR1
	log_debug = on;

	// info: start and end of client session
	log_info = on;

	/* possible `log' values are:
	 *   stderr
	 *   "file:/path/to/file"
	 *   syslog:FACILITY  facility is any of "daemon", "local0"..."local7"
	 */
	// log = stderr;
	// log = "file:/path/to/file";
	log = "stderr";

	// detach from console
	daemon = off;

	/* Change uid, gid and root directory, these options require root
	 * privilegies on startup.
	 * Note, your chroot may requre /etc/localtime if you write log to syslog.
	 * Log is opened before chroot & uid changing.
	 */
	user = redsocks;
	group = redsocks;
	// chroot = "/var/chroot";

	/* possible `redirector' values are:
	 *   iptables   - for Linux
	 *   ipf        - for FreeBSD
	 *   pf         - for OpenBSD
	 *   generic    - some generic redirector that MAY work
	 */
	redirector = iptables;
}

redsocks {
	/* `local_ip' defaults to 127.0.0.1 for security reasons,
	 * use 0.0.0.0 if you want to listen on every interface.
	 * `local_*' are used as port to redirect to.
	 */
	local_ip = 127.0.0.1;
	local_port = 12345;

	// listen() queue length. Default value is SOMAXCONN and it should be
	// good enough for most of us.
	// listenq = 128; // SOMAXCONN equals 128 on my Linux box.

	// `max_accept_backoff` is a delay to retry `accept()` after accept
	// failure (e.g. due to lack of file descriptors). It's measured in
	// milliseconds and maximal value is 65535. `min_accept_backoff` is
	// used as initial backoff value and as a damper for `accept() after
	// close()` logic.
	// min_accept_backoff = 100;
	// max_accept_backoff = 60000;

	// `ip' and `port' are IP and tcp-port of proxy-server
	// You can also use hostname instead of IP, only one (random)
	// address of multihomed host will be used.
	ip = 192.168.29.172;
	port = 4445;


	// known types: socks4, socks5, http-connect, http-relay
	type = socks5;

	// login = "foobar";
	// password = "baz";
}

redudp {
	// `local_ip' should not be 0.0.0.0 as it's also used for outgoing
	// packets that are sent as replies - and it should be fixed
	// if we want NAT to work properly.
	local_ip = 127.0.0.1;
	local_port = 10053;

	// `ip' and `port' of socks5 proxy server.
	ip = 127.0.0.1;
	port = 4711;

	// login = username;
	// password = pazzw0rd;

	// kernel does not give us this information, so we have to duplicate it
	// in both iptables rules and configuration file.  By the way, you can
	// set `local_ip' to 127.45.67.89 if you need more than 65535 ports to
	// forward ;-)
	// This limitation may be relaxed in future versions using contrack-tools.
	dest_ip = 8.8.8.8;
	dest_port = 53;

	udp_timeout = 30;
	udp_timeout_stream = 180;
}

dnstc {
	// fake and really dumb DNS server that returns "truncated answer" to
	// every query via UDP, RFC-compliant resolver should repeat same query
	// via TCP in this case.
	local_ip = 127.0.0.1;
	local_port = 5300;
}

// you can add more `redsocks' and `redudp' sections if you need.
```
Create the chain and forward the traffic
```
sudo iptables -t nat -N REDSOCKS
# Do not proxy local or proxy IP
sudo iptables -t nat -A REDSOCKS -d 127.0.0.0/8 -j RETURN
sudo iptables -t nat -A REDSOCKS -d 192.168.0.0/16 -j RETURN

# Redirect other TCP traffic to redsocks
sudo iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports 12345

# Apply to outbound traffic
sudo iptables -t nat -A OUTPUT -p tcp -j REDSOCKS
```

#cleanup
```
# Delete the OUTPUT chain redirection
sudo iptables -t nat -D OUTPUT -p tcp -j REDSOCKS

# Flush and delete the REDSOCKS chain
sudo iptables -t nat -F REDSOCKS
sudo iptables -t nat -X REDSOCKS

```
