package main

import (
    "fmt"
    "github.com/vishvananda/netlink"
	"golang.org/x/sys/unix"
)

type netlinkHandle struct {
	netlink.Handle
}

// NewNetLinkHandle will crate a new NetLinkHandle
func NewNetLinkHandle() netlinkHandle {
	return netlinkHandle{netlink.Handle{}}
}


func main() {
	h := NewNetLinkHandle()

	routeFilter := &netlink.Route{
		Table:    unix.RT_TABLE_LOCAL,
		Type:     unix.RTN_LOCAL,
		Protocol: unix.RTPROT_KERNEL,
	}
	filterMask := netlink.RT_FILTER_TABLE | netlink.RT_FILTER_TYPE | netlink.RT_FILTER_PROTOCOL

	routes, err := h.RouteListFiltered(netlink.FAMILY_ALL, routeFilter, filterMask)
	if err != nil {
		fmt.Errorf("error list route table, err: %v", err)
	} else {
		for _, route := range routes {
			if route.Src != nil {
				fmt.Println(route.Src.String())
			} else if route.Dst.IP.To4() == nil {
				if ! route.Dst.IP.IsLinkLocalUnicast() {
					fmt.Println(route.Dst.IP.String())
				}
			}
		}
	}
}
