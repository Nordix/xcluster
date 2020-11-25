
SYS := $(__dpdk_src)/build/sys
O ?= /tmp/tmp/$(USER)/dpdk

CFLAGS := -I$(SYS)/usr/local/include
LIBD := $(SYS)/usr/local/lib/x86_64-linux-gnu
LIBS := $(shell PKG_CONFIG_PATH=$(LIBD)/pkgconfig pkg-config --libs-only-l libdpdk)
EXD := $(__dpdk_src)/examples

.PHONY: all clean hello

all: $(O) $(O)/helloworld $(O)/l2fwd $(O)/l3fwd

hello: $(O) $(O)/helloworld

$(O)/helloworld: $(EXD)/helloworld/main.c
	$(CC) -o $@ $(CFLAGS) $< -L$(LIBD) $(LIBS)

$(O)/l2fwd: $(EXD)/l2fwd/main.c
	$(CC) -o $@ $(CFLAGS) $< -L$(LIBD) $(LIBS)

$(O)/l3fwd: $(EXD)/l3fwd/main.c $(EXD)/l3fwd/l3fwd_em.c $(EXD)/l3fwd/l3fwd_lpm.c
	$(CC) -o $@ $(CFLAGS) -mavx $^ -L$(LIBD) $(LIBS)

$(O):
	@mkdir -p $(O)

clean:
	rm -rf $(O)
