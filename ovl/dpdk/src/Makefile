# Generic makefile for DPDK examples and own programs.
# Example;
#   make -j$(nproc) DIR=$__dpdk_src/examples/l3fwd DST=/tmp

DIR ?= .
DST ?= .
TMP ?= /tmp/$(USER)/dpdk

S := $(shell readlink -f $(DIR))
X := $(DST)/$(notdir $(S))
O := $(TMP)/$(notdir $(S))
SRC := $(wildcard $(S)/*.c)
OBJ := $(SRC:$(S)/%.c=$(O)/%.o)

CFLAGS += $(shell pkg-config --cflags libdpdk)
LDFLAGS += $(shell pkg-config --libs libdpdk)

.PHONY: clean

$(O)/%.o : $(S)/%.c
	$(CC) -c $(CFLAGS) -I$(DIR) $< -o $@

$(X): $(O) $(OBJ)
	$(CC) -o $@ $(OBJ) $(LDFLAGS)
	strip $@

$(O):
	@mkdir -p $(O)

clean:
	@rm -r $(O) $(X)

