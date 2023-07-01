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
iptables /-t nat -I PREROUTING -p tcp --dport 80 -j REDIRECT --to-ports 3000
```
[Refer](https://unix.stackexchange.com/questions/85932/how-can-i-redirect-outbound-traffic-to-port-80-using-iptables-locally)
[Refer](https://unix.stackexchange.com/questions/487949/iptables-blocking-local-traffic?noredirect=1&lq=1)

## Route outgoing traffic to internal
```
sudo iptables -t nat -I PREROUTING -p tcp -d 10.32.255.191 --dport 15672 -j DNAT --to-destination 127.0.0.1:15672
```

#### See all the rules defined from all the tabels
```
get the table names first:
cat /proc/net/ip_tables_names
cat /proc/net/ip6_tables_names
or
lsmod | grep ip_tables


echo "filter";
sudo iptables -vL -t filter;
echo "nat";
sudo iptables -vL -t nat;
echo "mangle";
sudo iptables -vL -t mangle;
echo "raw";
sudo iptables -vL -t raw;
echo "security";
sudo iptables -vL -t security;
echo "normal";
sudo iptables -L ;
```
