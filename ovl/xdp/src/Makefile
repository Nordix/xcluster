##
## Make xdptest, an eXpress Data Path (XDP) test program
##

ifndef __kobj
$(error __kobj is not set)
endif

LLC ?= llc
CLANG ?= clang
CC := gcc

NFQLB_VER := 0.8.0
NFQLB_AR := $(HOME)/Downloads/nfqlb-$(NFQLB_VER).tar.xz
NFQLB_DIR := /tmp/$(USER)/nfqlb-$(NFQLB_VER)

O ?= /tmp/$(USER)/xdptest
X ?= $(O)/xdptest/xdptest
DIRS := $(O)/xdptest $(O)/lib/test
SRC := xdptest/main.c $(wildcard xdptest/cmd*.c)
OBJ := $(SRC:%.c=$(O)/%.o)

XDP_OBJ := $(O)/xdp_kern.o
KSRC := $(shell readlink -f $(__kobj)/source)
BPFD := $(KSRC)/tools/lib/bpf/build

CFLAGS := -I$(BPFD)/usr/include -I$(KSRC)/tools/include -I$(NFQLB_DIR)/include
LDFLAGS := -L$(BPFD)/usr/lib64 -L$(NFQLB_DIR)/lib -lrt -lelf -lz -lbpf -lnfqlb
BPF_CFLAGS ?= -I$(BPFD)/usr/include

all: $(NFQLB_DIR) $(X) $(XDP_OBJ)

$(O)/%.o : %.c
	$(CC) -c -Wall $(CFLAGS) $< -o $@

$(X): $(OBJ)
	$(CC) -o $(X) $(OBJ) $(LDFLAGS)
$(OBJ): | $(DIRS)

$(XDP_OBJ): $(O)/%.o: xdptest/%.c
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

$(DIRS):
	@mkdir -p $(DIRS)

$(NFQLB_DIR): $(NFQLB_AR)
	@mkdir -p /tmp/$(USER)
	tar -C /tmp/$(USER) -xf $(NFQLB_AR)
	@touch $(NFQLB_DIR)

.PHONY: clean
clean:
	rm -f $(X) $(OBJ) $(XDP_OBJ) ${XDP_OBJ:.o=.ll}
