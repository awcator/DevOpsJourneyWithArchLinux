## Iptables list NAT rules 
```
iptables -t nat -L --line-numbers -v
iptables -t nat -L
```
## Delete IP table NAT rule
```diff
iptables -t nat -D PREROUTING 2
#removes the 2nd rule
```
## ADD IPTable NAT rule to Internal Port_forward
```
sudo iptables -t nat -I PREROUTING -p tcp --dport 80 -j REDIRECT --to-ports 3000
# or
sudo iptables -t nat -A OUTPUT -p tcp --dport 90 -j DNAT --to-destination 192.168.42.210:4444
```
[Refer](https://unix.stackexchange.com/questions/85932/how-can-i-redirect-outbound-traffic-to-port-80-using-iptables-locally)
[Refer](https://unix.stackexchange.com/questions/487949/iptables-blocking-local-traffic?noredirect=1&lq=1)

## Route outgoing traffic to internal
```
sudo iptables -t nat -I PREROUTING -p tcp -d 10.32.255.191 --dport 15672 -j DNAT --to-destination 127.0.0.1:15672
```

#### See all the rules defined from all the tabels
```diff
get the table names first:
cat /proc/net/ip_tables_names
cat /proc/net/ip6_tables_names
or
lsmod | grep ip_tables


echo "filter";
sudo iptables -vL -t filter;
sudo iptables-legacy -vL -t filter;
echo "nat";
sudo iptables -vL -t nat;
sudo iptables-legacy -vL -t nat;
echo "mangle";
sudo iptables -vL -t mangle;
sudo iptables-legacy -vL -t mangle;
echo "raw";
sudo iptables -vL -t raw;
sudo iptables-legacy -vL -t raw;
echo "security";
sudo iptables -vL -t security;
sudo iptables-legacy -vL -t security;
echo "normal";
sudo iptables -L ;
sudo iptables-legacy -L;

-#flush the tables
# -f for flush -x delte chains -z reset counter
sudo iptables -F;
sudo iptables -X;
sudo iptables -Z;
sudo iptables-legacy -F;
sudo iptables-legacy -X;
sudo iptables-legacy -Z;


echo "filter";
sudo iptables -t filter -F;
sudo iptables -t filter -F;
sudo iptables -t filter -X;
sudo iptables -t filter -Z;
sudo iptables-legacy -t filter -F;
sudo iptables-legacy -t filter -F;
sudo iptables-legacy -t filter -X;
sudo iptables-legacy -t filter -Z;
echo "nat";
sudo iptables -t nat -F;
sudo iptables -t nat -X;
sudo iptables -t nat -Z;
sudo iptables-legacy -t nat -F;
sudo iptables-legacy -t nat -X;
sudo iptables-legacy -t nat -Z;
echo "mangle";
sudo iptables -t mangle -F;
sudo iptables -t mangle -X;
sudo iptables -t mangle -Z;
sudo iptables-legacy -t mangle -F;
sudo iptables-legacy -t mangle -X;
sudo iptables-legacy -t mangle -Z;
echo "raw";
sudo iptables -t raw -F;
sudo iptables -t raw -X;
sudo iptables -t raw -Z;
sudo iptables-legacy -t raw -F;
sudo iptables-legacy -t raw -X;
sudo iptables-legacy -t raw -Z;
echo "security";
sudo iptables -t security -F;
sudo iptables -t security -X;
sudo iptables -t security -Z;
sudo iptables-legacy -t security -F;
sudo iptables-legacy -t security -X;
sudo iptables-legacy -t security -Z;
echo "normal";

```
