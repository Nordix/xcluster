
LIBD ?= /tmp/$(USER)/lib
O ?= .
TESTD := $(shell $(XCLUSTER) ovld test)
SRC := $(wildcard *.c) $(TESTD)/src/main.c
X := $(O)/nfqueuelb
CFLAGS := -I.. -I../util
LDFLAGS := -L$(LIBD) -llbutil -lrt -lmnl -lnetfilter_queue

$(X): $(SRC) $(LIBD)/liblbutil.a
	$(CC) -Wall -o $@ $(CFLAGS) $(SRC) $(LDFLAGS)

$(O):
	mkdir -p $@

.PHONY: clean
clean:
	rm -f $(X)
