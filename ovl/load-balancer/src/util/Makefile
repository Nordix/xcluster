##
## Make xcluster ovl/load-balancer utils.
##
## Targets;
##  help - This printout
##  all (default) - Build liblbutil.a in $(LIBD) (/tmp/$(USER)/lib)
##  clean - Remove files from $(LIBD)
##  test - Build the lib and test programs, run unit-tests
##
## Example;
##  make -j8 LIBD=/tmp/lib test
##

LIBD ?= /tmp/$(USER)/lib
LIB := $(LIBD)/liblbutil.a

SRC := $(wildcard *.c)
OBJ := $(SRC:%.c=$(LIBD)/%.o) $(LIBD)/maglev.o

CPPFLAGS := -I..
CFLAGS += -Wall

$(LIBD)/%.o : %.c
	$(CC) -c $(CFLAGS) $(CPPFLAGS) $< -o $@

.PHONY: all
all: $(LIB)
$(LIB): $(LIBD) $(OBJ)
	@rm -f $(LIB)
	ar rcs $@ $(OBJ)

$(LIBD)/maglev.o: ../maglev.c
	$(CC) -c $(CFLAGS) $(CPPFLAGS) $< -o $@

$(LIBD):
	mkdir -p $@

.PHONY: test
TEST_SRC := $(wildcard test/*-test.c)
TEST_PROGS := $(TEST_SRC:test/%.c=$(LIBD)/%) $(LIBD)/lbtest
$(TEST_PROGS): $(LIB)
$(LIBD)/% : test/%.c
	$(CC) -o $@ -I. -I.. $(CFLAGS) $< -L$(LIBD) -llbutil -lrt
test: $(TEST_PROGS)
	@$(foreach p,$(TEST_PROGS),echo $(p);$(p);)
	@touch $(LIB)				# prevent re-build of $(LIB)
TMAIN := $(shell $(XCLUSTER) ovld test)/src/main.c
$(LIBD)/lbtest: $(TEST_SRC) $(TMAIN)
	$(CC) -o $@ -I. -I.. -DCMD $(CFLAGS) $^ -L$(LIBD) -llbutil -lrt

.PHONY: clean
clean:
	rm -f $(LIB) $(OBJ) $(TEST_PROGS) $(LIBD)/lbtest

.PHONY: help
help:
	@grep '^##' $(lastword $(MAKEFILE_LIST)) | cut -c3-

