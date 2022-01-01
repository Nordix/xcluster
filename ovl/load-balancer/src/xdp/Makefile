
ifndef __kobj
$(error __kobj is not set)
endif

LLC ?= llc
CLANG ?= clang
CC ?= gcc

NFQLB_VER := 0.6.0
NFQLB_AR := $(HOME)/Downloads/nfqlb-$(NFQLB_VER).tar.xz
NFQLB_DIR := /tmp/$(USER)/nfqlb-$(NFQLB_VER)

O ?= .
SRC := main.c ../util/util.c
XDP_OBJ := $(O)/xdp_vip_kern.o
KSRC := $(shell readlink -f $(__kobj)/source)
BPFD := $(KSRC)/tools/lib/bpf/build

CFLAGS := -I$(BPFD)/usr/include -I$(KSRC)/tools/include -I$(NFQLB_DIR)/include
LDFLAGS := $(BPFD)/usr/lib64/libbpf.a -L$(NFQLB_DIR)/lib -lrt -lelf -lz -lnfqlb
BPF_CFLAGS ?= -I$(BPFD)/usr/include

all: $(NFQLB_DIR) $(O) $(O)/xdplb $(XDP_OBJ)

$(O)/xdplb: $(SRC)
	$(CC) -Wall -o $@ $(CFLAGS) $^ $(LDFLAGS)

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

$(NFQLB_DIR): $(NFQLB_AR)
	@mkdir -p /tmp/$(USER)
	tar -C /tmp/$(USER) -xf $(NFQLB_AR)
	@touch $(NFQLB_DIR)

.PHONY: clean
clean:
	rm -f $(XDP_OBJ) ${XDP_OBJ:.o=.ll} $(O)/xdplb
