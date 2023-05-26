# MPTCP demo

```
./mptcp.sh build_ko
./mptcp.sh test start_empty systemtap > $log
# On vm-002
ip ro
ping -c1 -W1 192.168.2.221
ping -c1 -W1 192.168.6.221
# On vm-221
ip ro

# Many examples/tutorials uses source based routing, but that is not
# necessary. The important thing is that the endpoints has
# connectivity to the peer


# On host. "mptcp.c" is a simple mptcp aware client/server test program
les src/mptcp.c  # Only difference is IPPROTO_TCP -> IPPROTO_MPTCP
man ip-mptcp

# On vm-002
ip mptcp limits set subflow 2 add_addr_accepted 2
ip mptcp endpoint add 192.168.4.2 dev eth2 signal
# "signal" means that the peers negotiate to setup mptcp
ip mptcp endpoint
mptcp server
ss -nltM | grep 7000  # (in another shell)
# Note the 2 server sockets. One tcp and one mptcp


# On vm-221
ip mptcp limits set subflow 2 add_addr_accepted 2
ip mptcp endpoint add 192.168.6.221 dev eth2 signal
mptcp client 192.168.1.2 7000

# Back on vm-002
ss -ntM | grep 7000
# The 2 subflows can be seen as indivitual tcp sockets

# On vm-201 and vm-202
tcpdump -ni eth1 port 7000
# On vm-201. Force failover!
iptables -A FORWARD -j DROP
iptables -D FORWARD -j DROP   # restore connectivity


# Use mptcpize
#sudo apt install mptcpize

# On vm-002
mptcpize run ncat -lk 0.0.0.0 6000
ss -nltM | grep 6000
ss -ntM | grep 6000

# On vm-221
mptcpize run nc 192.168.1.2 6000
# (type something)

# On vm-201 and vm-202
tcpdump -ni eth1 port 6000
# On vm-201
iptables -A FORWARD -j DROP

# The "nc" pitfall. Not all programs work with mptcp
# On vm-002
mptcpize run nc -s :: -p 6000 -lk
# On vm-221
mptcpize run nc 192.168.1.2 6000
# On vm-002
ss -nltM | grep 6000 # Listener port closed!
ss -ntM | grep 6000  # Only one subflow!




# Use systemtap to enforce mptcp on ctraffic
# On host
les mptcp-app.stp      # Corrected to work with newer kernels an go programs
./mptcp.sh build_ko

# On vm-201 and vm-202
tcpdump -ni eth1 port 5003

# On vm-002
staprun mptcpapp.ko                     # (will hang)
ctraffic -server -address 0.0.0.0:5003
ss -nltM | grep 5003
ss -ntM | grep 5003 
# On vm-221
staprun mptcpapp.ko                     # (will hang)
ctraffic -address 192.168.1.2:5003 -monitor -rate 10 --nconn 1 --timeout 5m

# On vm-201
# failover causes retransmits. Seen as "drop" in ctraffic
iptables -A FORWARD -j DROP

```
