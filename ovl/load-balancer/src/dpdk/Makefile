
DIR ?= .
DST ?= .

S := $(shell readlink -f $(DIR))
X := $(DST)/l2lb
SRC := $(S)/main.c $(S)/../maglev.c $(wildcard $(S)/../util/*.c)

CFLAGS := -I$(S) -I$(S)/.. -I$(S)/../util
CFLAGS += $(shell pkg-config --cflags libdpdk)
LDFLAGS += $(shell pkg-config --libs libdpdk)

.PHONY: clean

$(X): $(SRC)
	$(CC) -o $@ -Wall $(SRC) $(CFLAGS) $(LDFLAGS) -lrt
	strip $@

clean:
	@rm -f $(X)

