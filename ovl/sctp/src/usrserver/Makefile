
USRSCTPD ?= /tmp/$(USER)/usrsctp/usr/local
O ?= /tmp/$(USER)/sctp
SRC := $(wildcard *.c)
OBJ := $(SRC:%.c=$(O)/%.o)
X := $(O)/usrserver

$(O)/%.o : %.c
	$(CC) -c $(CFLAGS) -pthread -I$(USRSCTPD)/include -Wall $< -o $@

.phony: all clean
all: $(X)

$(X): $(OBJ)
	$(CC) -static -pthread -o $@ $(OBJ) -L$(USRSCTPD)/lib -lusrsctp

clean:
	rm -f $(OBJ) $(X)

$(OBJ): | $(O)

$(O):
	@mkdir -p $@
