
DIR ?= .
DST ?= .

NFQLB_VER := 0.6.0
NFQLB_AR := $(HOME)/Downloads/nfqlb-$(NFQLB_VER).tar.xz
NFQLB_DIR := /tmp/$(USER)/nfqlb-$(NFQLB_VER)

S := $(shell readlink -f $(DIR))
X := $(DST)/l2lb
SRC := $(S)/main.c $(S)/../util/util.c

CFLAGS := -I$(S) -I$(NFQLB_DIR)/include
CFLAGS += $(shell pkg-config --cflags libdpdk)
LDFLAGS += $(shell pkg-config --libs libdpdk)
LDFLAGS += -L$(NFQLB_DIR)/lib -lnfqlb

.PHONY: clean

$(X): $(NFQLB_DIR) $(SRC)
	$(CC) -o $@ -Wall $(SRC) $(CFLAGS) $(LDFLAGS) -lrt
	strip $@

$(NFQLB_DIR): $(NFQLB_AR)
	@mkdir -p /tmp/$(USER)
	tar -C /tmp/$(USER) -xf $(NFQLB_AR)
	@touch $(NFQLB_DIR)

clean:
	@rm -f $(X)

