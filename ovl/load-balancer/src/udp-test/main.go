// go build -ldflags "-extldflags '-static' -X main.version=$(date +%F:%T)" -o /tmp/udp-test ./main.go


package main

import (
	//"context"
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"time"
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

	pc, err := net.ListenPacket("udp", *c.addr)
	if err != nil {
		log.Fatal(err)
	}
	log.Println("Listen on UDP address; ", *c.addr)

	buf := make([]byte, 64 * 1024)
	for {
		n, addr, err := pc.ReadFrom(buf)
		if err != nil {
			log.Fatal(err)
		}
		fmt.Printf("Read %d bytes from %s\n", n, addr)
		n, err = pc.WriteTo(buf[:n], addr)
		if err != nil {
			log.Fatal(err)
		}		
		fmt.Printf("Wrote %d bytes (buf %d)\n", n , len(buf))
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
