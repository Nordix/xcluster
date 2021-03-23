# Generic makefile for DPDK examples.
# Example;
#   make -j$(nproc) DIR=$__dpdk_src/examples/l3fwd DST=/tmp

DIR ?= .
DST ?= .
TMP ?= /tmp/$(USER)/dpdk

S := $(shell readlink -f $(DIR))
X := $(DST)/l2lb
O := $(TMP)/$(notdir $(S))
SRC := $(wildcard $(S)/*.c) $(S)/../maglev.c
OBJ := $(SRC:$(S)/%.c=$(O)/%.o)
LIB := $(O)/liblb.a

CFLAGS += $(shell pkg-config --cflags libdpdk)
LDFLAGS += $(shell pkg-config --libs libdpdk)

.PHONY: clean

$(O)/%.o : $(S)/%.c
	$(CC) -Wall -c $(CFLAGS) -I$(S) -I$(S)/.. $< -o $@

$(X): $(O) $(OBJ)
	$(CC) -o $@ $(OBJ) $(LDFLAGS) -lrt
	strip $@

$(O):
	@mkdir -p $(O)

clean:
	@rm -fr $(O) $(X)

