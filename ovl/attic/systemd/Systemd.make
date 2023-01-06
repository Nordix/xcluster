#
##
## Makefile for "systemd"
##

S := $(HOME)/work/systemd/systemd-236/src
O := /tmp/$(USER)/systemd-obj
C := $(HOME)/work/systemd/config.h
CC := gcc

# Main targets
BLIB = $(O)/libbasic.a
SLIB = $(O)/libsystemd.so
SYSTEMD = $(O)/sbin/systemd
SYSTEMCTL = $(O)/sbin/systemctl
SYSRUN = $(O)/sbin/systemd-run

I := -I$(O) -I$(S)/systemd -I$(S)/basic -I$(S)/shared
DIRS = $(O)/sbin
GENTOOL := $(S)/basic/generate-gperfs.py
#GENTOOL := $(S)/../tools/generate-gperfs.py

# systemd
CSRCall = $(wildcard $(S)/core/*.c)
CSRC = $(filter-out %/shutdown.c, $(CSRCall))
COBJgen = $(O)/load-fragment-gperf.o $(O)/load-fragment-gperf-nulstr.o
COBJ = $(patsubst $(S)/%.c, $(O)/%.o, $(CSRC)) $(COBJgen)
DIRS += $(O)/core
$(COBJ): I += -I$(S)/libsystemd/sd-bus -I$(S)/libudev -I$(S)/udev \
	-I$(S)/libsystemd/sd-netlink -I$(S)/libsystemd/sd-id128

# systemctl
TOBJ = $(O)/systemctl/systemctl.o
DIRS += $(O)/systemctl
$(TOBJ): I += -I$(S)/libsystemd/sd-bus -I$(S)/libudev -I$(S)/udev \
	-I$(S)/libsystemd/sd-netlink -I$(S)/libsystemd/sd-id128

# systemd-run
SYSRUNOBJ = $(O)/run/run.o
DIRS += $(O)/run
$(SYSRUNOBJ): I += -I$(S)/libsystemd/sd-bus

# Library code; basic, shared, libsystemd, libudev, journal
BSRC = $(wildcard $(S)/basic/*.c)
BOBJ = $(patsubst $(S)/%.c, $(O)/%.o, $(BSRC))
DIRS += $(O)/basic
LIBOBJ += $(BOBJ)

SSRCall = $(wildcard $(S)/shared/*.c)
SSRC = $(filter-out %/acl-util.c %/firewall-util.c %/seccomp-util.c \
	%/utmp-wtmp.c, $(SSRCall))
SOBJ = $(patsubst $(S)/%.c, $(O)/%.o, $(SSRC))
$(SOBJ): I += -I$(S)/libsystemd/sd-bus -I$(S)/libsystemd/sd-id128 \
	-I$(S)/libudev -I$(S)/udev -I$(S)/journal
DIRS += $(O)/shared
LIBOBJ += $(SOBJ)

LSRCall = $(wildcard $(S)/libsystemd/sd-bus/*.c $(S)/libsystemd/sd-hwdb/*.c \
	$(S)/libsystemd/sd-event/*.c $(S)/libsystemd/sd-netlink/*.c \
	$(S)/libsystemd/sd-device/*.c $(S)/libsystemd/sd-id128/*.c \
	$(S)/libsystemd/sd-daemon/*.c $(S)/libsystemd/sd-path/*.c \
	$(S)/libsystemd/sd-login/*.c)
LSRCtest = $(wildcard $(S)/libsystemd/*/test-*.c)
LSRC = $(filter-out $(LSRCtest), $(LSRCall))
LOBJ = $(patsubst $(S)/%.c, $(O)/%.o, $(LSRC))
DIRS += $(O)/libsystemd/sd-bus $(O)/libsystemd/sd-hwdb \
	$(O)/libsystemd/sd-event $(O)/libsystemd/sd-netlink \
	$(O)/libsystemd/sd-device $(O)/libsystemd/sd-id128 \
	$(O)/libsystemd/sd-daemon $(O)/libsystemd/sd-path \
	$(O)/libsystemd/sd-login
#LIBOBJ += $(LOBJ)

USRC = $(wildcard $(S)/libudev/*.c)
UOBJ = $(patsubst $(S)/%.c, $(O)/%.o, $(USRC))
DIRS += $(O)/libudev
$(UOBJ): I += -I$(S)/libsystemd/sd-device -I$(S)/libsystemd/sd-hwdb
#LIBOBJ += $(UOBJ)

JSRCall = $(wildcard $(S)/journal/*.c)
JSRCtest = $(wildcard $(S)/journal/test-*.c)
JSRC = $(filter-out $(JSRCtest) %/audit-type.c %/journal-authenticate.c \
	%/journalctl.c 	%/journal-qrcode.c %/journald.c, $(JSRCall))
JOBJ = $(patsubst $(S)/%.c, $(O)/%.o, $(JSRC))
DIRS += $(O)/journal
$(JOBJ): I += -I$(S)/libsystemd/sd-bus -I$(S)/libudev -I$(S)/udev \
	-I$(S)/libsystemd/sd-id128
LIBOBJ += $(JOBJ)

# Custom config. Mostly setting the I and L variables (probably).
-include $(dir $(C))/config.make


$(O)/%.o: $(S)/%.c
	$(CC) -c -std=gnu99 -fPIC -include $(C) $(I) $(CFLAGS) -o $@ $<
$(O)/%.o: $(O)/%.c
	$(CC) -c -std=gnu99 -fPIC -include $(C) $(I) $(CFLAGS) \
	-I$(S)/core -o $@ $<

.PHONY: all clean

all: $(shell mkdir -p $(DIRS)) $(SYSTEMD) $(SYSTEMCTL) $(SYSRUN) $(SLIB)

clean:
	rm -r $(O)

$(SYSTEMD): $(BLIB) $(COBJ) $(SLIB)
	$(CC) -o $@ $(COBJ) $(L) $(LDFLAGS) -L$(O) \
	-lpthread -lrt -lmount -lsystemd -lbasic -lcap

$(SYSTEMCTL): $(BLIB) $(TOBJ) $(SLIB)
	$(CC) -o $@ $(TOBJ) $(L) $(LDFLAGS) -L$(O) -lsystemd \
	-lpthread -lcap -lrt -lbasic -lmount

$(SYSRUN): $(BLIB) $(SYSRUNOBJ) $(SLIB)
	$(CC) -o $@ $(SYSRUNOBJ) $(L) $(LDFLAGS) -L$(O) \
	-lsystemd -lbasic -lcap -lpthread -lmount

$(BLIB): $(LIBOBJ)
	rm -f $@
	$(AR) rcs $@ $^

$(SLIB): $(LOBJ) $(UOBJ) $(BLIB)
	gcc -shared -fPIC -o $@ $^ -L$(O) -lbasic



# Generated code;

# af-list
$(O)/basic/af-list.o: $(O)/af-from-name.h $(O)/af-to-name.h
$(O)/af-from-name.h: $(O)/af.txt
	$(GENTOOL) af "" $< | \
	gperf -L ANSI-C -t --ignore-case -N lookup_af -H hash_af_name -p -C > $@
$(O)/af-to-name.h: $(O)/af.txt
	awk -f $(S)/basic/af-to-name.awk < $< > $@
$(O)/af.txt:
	$(S)/basic/generate-af-list.sh cpp /dev/null /dev/null > $@

# arphrd-list
$(O)/basic/arphrd-list.o: $(O)/arphrd-from-name.h $(O)/arphrd-to-name.h
$(O)/arphrd-from-name.h: $(O)/arphrd.txt
	$(GENTOOL) arphrd ARPHRD_ $< | \
	gperf -L ANSI-C -t --ignore-case -N lookup_arphrd \
	 -H hash_arphrd_name -p -C > $@
$(O)/arphrd-to-name.h: $(O)/arphrd.txt
	awk -f $(S)/basic/arphrd-to-name.awk < $< > $@
$(O)/arphrd.txt:
	$(S)/basic/generate-arphrd-list.sh cpp /dev/null /dev/null > $@

# cap-list
$(O)/basic/cap-list.o: $(O)/cap-from-name.h $(O)/cap-to-name.h
$(O)/cap-from-name.h: $(O)/cap.txt
	$(GENTOOL) capability "" $< | \
	gperf -L ANSI-C -t --ignore-case -N lookup_capability \
	 -H hash_capability_name -p -C > $@
$(O)/cap-to-name.h: $(O)/cap.txt
	awk -f $(S)/basic/cap-to-name.awk < $< > $@
$(O)/cap.txt:
	$(S)/basic/generate-cap-list.sh cpp $(C) $(S)/basic/missing.h > $@

# errno-list
$(O)/basic/errno-list.o: $(O)/errno-from-name.h $(O)/errno-to-name.h
$(O)/errno-from-name.h: $(O)/errno.txt
	$(GENTOOL) errno "" $< | \
	gperf -L ANSI-C -t --ignore-case -N lookup_errno \
	 -H hash_errno_name -p -C > $@
$(O)/errno-to-name.h: $(O)/errno.txt
	awk -f $(S)/basic/errno-to-name.awk < $< > $@
$(O)/errno.txt:
	$(S)/basic/generate-errno-list.sh cpp > $@

# socket-protocol-list
$(O)/basic/socket-protocol-list.o: $(O)/socket-protocol-from-name.h $(O)/socket-protocol-to-name.h
$(O)/socket-protocol-from-name.h: $(O)/socket-protocol.txt
	$(GENTOOL) socket_protocol "IPPROTO_" $< | \
	gperf -L ANSI-C -t --ignore-case -N lookup_socket_protocol \
	 -H hash_socket_protocol_name -p -C > $@
$(O)/socket-protocol-to-name.h: $(O)/socket-protocol.txt
	awk -f $(S)/basic/socket-protocol-to-name.awk < $< > $@
$(O)/socket-protocol.txt:
	$(S)/basic/generate-socket-protocol-list.sh cpp > $@

# load-fragment
$(O)/load-fragment-gperf.gperf: $(S)/core/load-fragment-gperf.gperf.m4
	m4 -P $< > $@
$(O)/load-fragment-gperf.c: $(O)/load-fragment-gperf.gperf
	gperf $< --output-file $@
$(O)/load-fragment-gperf-nulstr.c: $(O)/load-fragment-gperf.gperf
	awk -f $(S)/core/load-fragment-gperf-nulstr.awk $< > $@

