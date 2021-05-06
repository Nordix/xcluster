
LIBD ?= /tmp/$(USER)/lib
O ?= .
TESTD := $(shell $(XCLUSTER) ovld test)
SRC := $(wildcard *.c) $(TESTD)/src/main.c
X := $(O)/nfqueuelb
CFLAGS := -I.. -I../util
LDFLAGS := -L$(LIBD) -llbutil -lrt

$(X): $(SRC)
	$(CC) -Wall -o $@ $(CFLAGS) $^ $(LDFLAGS)

$(O):
	mkdir -p $@

.PHONY: clean
clean:
	rm -f $(X)
