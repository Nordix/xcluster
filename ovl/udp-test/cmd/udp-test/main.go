// go build -ldflags "-extldflags '-static' -X main.version=$(date +%F:%T)" -o /tmp/udp-test ./main.go

// https://github.com/miekg/dns/blob/master/udp.go
// https://stackoverflow.com/questions/65285074/how-to-get-real-local-address-for-udp-connection


package main

import (
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"time"

	"golang.org/x/net/ipv4"
	"golang.org/x/net/ipv6"
)

var version = "unknown"


type config struct {
	isServer      *bool
	addr          *string
	src           *string
	version       *bool
	timeout       *time.Duration
	size          *int
}

func main() {
	var cmd config
	cmd.isServer = flag.Bool("server", false, "Act as server")
	cmd.addr = flag.String("address", ":6001", "Server address")
	cmd.src = flag.String("src", "", "Source to use")
	cmd.version = flag.Bool("version", false, "Print version and quit")
	cmd.timeout = flag.Duration("timeout", time.Second, "Timeout")
	cmd.size = flag.Int("size", 1024, "Packet size")

	flag.Parse()
	if len(os.Args) < 2 {
		flag.PrintDefaults()
		os.Exit(0)
	}

	if *cmd.version {
		fmt.Println(version)
		os.Exit(0)
	}

	if *cmd.isServer {
		os.Exit(cmd.server())
	} else {
		os.Exit(cmd.client())
	}
}

func (c *config) server() int {
	serverAddr, err := net.ResolveUDPAddr("udp", *c.addr)
	if err != nil {
		log.Fatal(err)
	}	
	conn, err := net.ListenUDP("udp", serverAddr)
	if err != nil {
		log.Fatal(err)
	}
	log.Println("Listen on UDP address; ", *c.addr)

	if err := setUDPSocketOptions(conn); err != nil {
		log.Fatal(err)
	}
	buf := make([]byte, 64 * 1024)
	oob := make([]byte, 2048)

	for {
		//n, oobn, flags, addr, err
		n, oobn, _, addr, err := conn.ReadMsgUDP(buf, oob)
		if err != nil {
			log.Fatal(err)
		}
		oobd := oob[:oobn]
		fmt.Printf("Read %d bytes from %s to %s\n", n, addr, parseDstFromOOB(oobd))

		n, _, err = conn.WriteMsgUDP(buf[:n], correctSource(oobd), addr)
		if err != nil {
			log.Fatal(err)
		}		
		fmt.Printf("Wrote %d bytes (buf %d)\n", n, len(buf))
	}
}

func (c *config) client() int {

	var saddr *net.UDPAddr
	if *c.src != "" {
		sadr := fmt.Sprintf("%s", *c.src)
		var err error
		if saddr, err = net.ResolveUDPAddr("udp", sadr); err != nil {
			log.Fatal(err)
		}
	}

	daddr, err := net.ResolveUDPAddr("udp", *c.addr)
	if err != nil {
		log.Fatal(err)
	}

	conn, err := net.DialUDP("udp", saddr, daddr)
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()

	buf := make([]byte, *c.size)
	n, err := conn.Write(buf)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Sent bytes %d\n", n)

	// Set a read timeout
	deadline := time.Now().Add(*c.timeout)
	err = conn.SetReadDeadline(deadline)
	if err != nil {
		log.Fatal(err)
	}

	n, addr, err := conn.ReadFrom(buf)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Read bytes %d from %s\n", n, addr)

	return 0
}

/*
  Taken from;
   https://github.com/miekg/dns/blob/master/udp.go
  License;
   https://github.com/miekg/dns/blob/master/LICENSE
 */

func setUDPSocketOptions(conn *net.UDPConn) error {
	// Try setting the flags for both families and ignore the errors unless they
	// both error.
	err6 := ipv6.NewPacketConn(conn).SetControlMessage(ipv6.FlagDst|ipv6.FlagInterface, true)
	err4 := ipv4.NewPacketConn(conn).SetControlMessage(ipv4.FlagDst|ipv4.FlagInterface, true)
	if err6 != nil && err4 != nil {
		return err4
	}
	return nil
}

// parseDstFromOOB takes oob data and returns the destination IP.
func parseDstFromOOB(oob []byte) net.IP {
	// Start with IPv6 and then fallback to IPv4
	// TODO(fastest963): Figure out a way to prefer one or the other. Looking at
	// the lvl of the header for a 0 or 41 isn't cross-platform.
	cm6 := new(ipv6.ControlMessage)
	if cm6.Parse(oob) == nil && cm6.Dst != nil {
		return cm6.Dst
	}
	cm4 := new(ipv4.ControlMessage)
	if cm4.Parse(oob) == nil && cm4.Dst != nil {
		return cm4.Dst
	}
	return nil
}

// correctSource takes oob data and returns new oob data with the Src equal to the Dst
func correctSource(oob []byte) []byte {
	dst := parseDstFromOOB(oob)
	if dst == nil {
		return nil
	}
	// If the dst is definitely an IPv6, then use ipv6's ControlMessage to
	// respond otherwise use ipv4's because ipv6's marshal ignores ipv4
	// addresses.
	if dst.To4() == nil {
		cm := new(ipv6.ControlMessage)
		cm.Src = dst
		oob = cm.Marshal()
	} else {
		cm := new(ipv4.ControlMessage)
		cm.Src = dst
		oob = cm.Marshal()
	}
	return oob
}
