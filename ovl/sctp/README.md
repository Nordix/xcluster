# Xcluster/ovl - sctp

Test and experiments with the
[SCTP](https://en.wikipedia.org/wiki/Stream_Control_Transmission_Protocol)
protocol ([rfc4960](https://datatracker.ietf.org/doc/html/rfc4960)).

There are user-space implementations of SCTP, for instance
[usrsctp](https://github.com/sctplab/usrsctp), but we focus mainly on
Linux kernel SCTP (lksctp).

The `go` language does not support sctp in standard packages. There
are 3rd party implementations that uses
[lksctp](https://github.com/ishidawataru/sctp) as well as in
[user-space](https://github.com/pion/sctp). But for now we stick to
`C` code.

All examples and tests are using multihoming because that's where the
problems are. The [ovl/network-topology](../network-topology) is used
with the `dual-path` setup;

<img src="../network-topology/dual-path.svg" alt="Dual-path network topology" width="80%" />



## References

* `man 7 sctp`
* https://github.com/sctp/lksctp-tools
* [usrsctp](https://github.com/sctplab/usrsctp)
* https://github.com/ishidawataru/sctp
* https://github.com/pion/sctp/
