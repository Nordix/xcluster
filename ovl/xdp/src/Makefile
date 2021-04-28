
ifndef __kobj
$(error __kobj is not set)
endif

LLC ?= llc
CLANG ?= clang
CC := gcc
LDIR := $(shell $(XCLUSTER) ovld test)/src
UTIL := $(LBDIR)/src/util

O ?= .
SRC := $(LDIR)/main.c $(wildcard cmd*.c) $(LDIR)/cmd.c
XDP_OBJ := $(O)/xdp_kern.o
KSRC := $(shell readlink -f $(__kobj)/source)
BPFD := $(KSRC)/tools/lib/bpf/build

CFLAGS := -I$(BPFD)/usr/include -I$(KSRC)/tools/include -I$(LDIR)
LDFLAGS := $(BPFD)/usr/lib64/libbpf.a -lrt -lelf -lz
BPF_CFLAGS ?= -I$(BPFD)/usr/include

all: $(O) $(O)/xdptest $(XDP_OBJ)

$(O)/xdptest: $(O) $(SRC)
	$(CC) -Wall -o $@ $(CFLAGS) $(SRC) $(LDFLAGS)

$(XDP_OBJ): $(O)/%.o: %.c
	$(CLANG) -S \
		-target bpf \
		-D __BPF_TRACING__ \
		$(BPF_CFLAGS) \
		-Wall \
		-Wno-unused-value \
		-Wno-pointer-sign \
		-Wno-compare-distinct-pointer-types \
		-Werror \
		-O2 -emit-llvm -c -g -o ${@:.o=.ll} $<
	$(LLC) -march=bpf -filetype=obj -o $@ ${@:.o=.ll}

$(O):
	mkdir -p $(O)

.PHONY: clean
clean:
	rm -f $(XDP_OBJ) ${XDP_OBJ:.o=.ll} $(O)/xdptest
