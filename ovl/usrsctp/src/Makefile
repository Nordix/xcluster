##
## Make usrsctpt, an SCTP test program
##
## Targets;
##  help - This printout
##  all (default) - Build the lib and the executable
##  clean - Remove built files
##
## Beside the usual CFLAGS and LDFLAGS some usable variables;
##  O - The output directory. Default /tmp/$USER/usrsctpt
##  X - The executable.  Default $(O)/usrsctpt
##
## Examples;
##  make -j8
##  make -j8 clean
##  make -j8 CFLAGS=-DSANITY_CHECK test
##  make -j8 X=/tmp/usrsctpt/usrsctpt
##  make -j8 O=.       # (you *can*, but don't do that!)
##

O ?= /tmp/$(USER)/usrsctpt
X ?= $(O)/usrsctpt/usrsctpt

DIRS := $(O)/usrsctpt $(O)/lib/test
SRC := $(wildcard usrsctpt/*.c lib/*.c)
OBJ := $(SRC:%.c=$(O)/%.o)

NFQLB_DIR ?= $(HOME)/tmp/nfqlb
USRSCTP_DIR ?= $(HOME)/tmp/usrsctp/

$(O)/%.o : %.c
	$(CC) -c $(CFLAGS) -pthread -Wall -Ilib -I$(NFQLB_DIR)/include -I$(USRSCTP_DIR)/include $< -o $@

.PHONY: all static
all: $(X)
static: $(X)
static: LDFLAGS := -static -Wl,--whole-archive -lpthread -Wl,--no-whole-archive

$(X): $(OBJ)
	$(CC) -o $(X) $(OBJ) $(LDFLAGS) -pthread -L$(NFQLB_DIR)/lib -L$(USRSCTP_DIR)/lib -lnfqlb -lsctp -lusrsctp -lrt
$(OBJ): | $(DIRS)

.PHONY: test test_progs
LIB_SRC := $(wildcard lib/*.c)
LIB_OBJ := $(LIB_SRC:%.c=$(O)/%.o)
$(O)/lib/test/% : lib/test/%.c
	$(CC) $(CFLAGS) -Wall -Ilib -pthread $< $(LIB_OBJ) -o $@ -L$(NFQLB_DIR)/lib -lnfqlb
TEST_SRC := $(wildcard lib/test/*-test.c)
TEST_PROGS := $(TEST_SRC:%.c=$(O)/%)
test_progs: $(TEST_PROGS)
test: $(TEST_PROGS)
	@$(foreach p,$(TEST_PROGS),echo $(p);$(p);)

$(DIRS):
	@mkdir -p $(DIRS)

.PHONY: clean
clean:
	rm -rf $(X) $(OBJ)

.PHONY: help
help:
	@grep '^##' $(lastword $(MAKEFILE_LIST)) | cut -c3-
	@echo "Binary:"
	@echo "  $(X)"
