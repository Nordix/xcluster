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

USRSCTPD ?= /tmp/$(USER)/usrsctp/usr/local
O ?= /tmp/$(USER)/usrsctpt
X ?= $(O)/usrsctpt/usrsctpt

DIRS := $(O)/usrsctpt $(O)/lib/test
SRC := $(wildcard usrsctpt/*.c lib/*.c)
OBJ := $(SRC:%.c=$(O)/%.o)

NFQLB_VER := 0.6.0
NFQLB_AR := $(ARCHIVE)/nfqlb-$(NFQLB_VER).tar.xz
NFQLB_DIR := $(O)/nfqlb-$(NFQLB_VER)

$(O)/%.o : %.c
	$(CC) -c $(CFLAGS) -pthread -Wall -I$(NFQLB_DIR)/include -I$(USRSCTPD)/include -Ilib $< -o $@

.PHONY: all static
all: $(NFQLB_DIR) $(X)
static: $(NFQLB_DIR) $(X)
static: LDFLAGS := -static -Wl,--whole-archive -lpthread -Wl,--no-whole-archive

$(X): $(OBJ)
	$(CC) -o $(X) $(OBJ) $(LDFLAGS) -pthread -L$(NFQLB_DIR)/lib -L$(USRSCTPD)/lib -lnfqlb -lsctp -lusrsctp -lrt
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

$(NFQLB_DIR): $(NFQLB_AR)
	@mkdir -p $(O)
	tar -C $(O) -xf $(NFQLB_AR)
	@touch $(NFQLB_DIR)

.PHONY: clean
clean:
	rm -rf $(X) $(OBJ)

.PHONY: help
help:
	@grep '^##' $(lastword $(MAKEFILE_LIST)) | cut -c3-
	@echo "Binary:"
	@echo "  $(X)"

.PHONY: ver
ver:
	@echo "NFQLB_VER=$(NFQLB_VER)"
	@echo "NFQLB_DIR=$(NFQLB_DIR)"
