##
## Make sctpt, an SCTP test program
##
## Targets;
##  help - This printout
##  all (default) - Build the lib and the executable
##  clean - Remove built files
##
## Beside the usual CFLAGS and LDFLAGS some usable variables;
##  O - The output directory. Default /tmp/$USER/sctpt
##  X - The executable.  Default $(O)/sctpt
##
## Examples;
##  make -j8
##  make -j8 clean
##  make -j8 CFLAGS=-DSANITY_CHECK test
##  make -j8 X=/tmp/sctpt/sctpt
##  make -j8 O=.       # (you *can*, but don't do that!)
##


O ?= /tmp/$(USER)/sctpt
X ?= $(O)/sctpt/sctpt

DIRS := $(O)/sctpt $(O)/lib/test
SRC := $(wildcard sctpt/*.c lib/*.c)
OBJ := $(SRC:%.c=$(O)/%.o)

NFQLB_VER := 0.1.1
NFQLB_AR := $(HOME)/Downloads/nfqlb-$(NFQLB_VER).tar.xz
NFQLB_DIR := $(O)/nfqlb-$(NFQLB_VER)

$(O)/%.o : %.c
	$(CC) -c $(CFLAGS) -pthread -Wall -I$(NFQLB_DIR)/include -Ilib $< -o $@

.PHONY: all static
all: $(NFQLB_DIR) $(X)
static: $(NFQLB_DIR) $(X)
static: LDFLAGS := -static -Wl,--whole-archive -lpthread -Wl,--no-whole-archive

$(X): $(OBJ)
	$(CC) -o $(X) $(OBJ) $(LDFLAGS) -pthread -L$(NFQLB_DIR)/lib -lnfqlb -lsctp -lrt
$(OBJ): | $(DIRS)

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
