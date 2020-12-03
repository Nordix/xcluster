
SYS := $(__dpdk_src)/build/sys
O ?= /tmp/tmp/$(USER)/dpdk

CFLAGS := $(shell pkg-config --cflags libdpdk)
LDFLAGS := $(shell pkg-config --libs libdpdk)
EXD := $(__dpdk_src)/examples

.PHONY: all clean hello

all: $(O) $(O)/helloworld $(O)/l2fwd $(O)/l3fwd

hello: $(O) $(O)/helloworld

$(O)/helloworld: $(EXD)/helloworld/main.c
	$(CC) -o $@ $(CFLAGS) $^ $(LDFLAGS)

$(O)/l2fwd: $(EXD)/l2fwd/main.c
	$(CC) -o $@ $(CFLAGS) $^ $(LDFLAGS)

$(O)/l3fwd: $(EXD)/l3fwd/main.c $(EXD)/l3fwd/l3fwd_em.c $(EXD)/l3fwd/l3fwd_lpm.c
	$(CC) -o $@ $(CFLAGS) $^ $(LDFLAGS)

$(O):
	@mkdir -p $(O)

clean:
	rm -rf $(O)
