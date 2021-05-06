LIBD ?= /tmp/$(USER)/lib
LIB := $(LIBD)/liblbutil.a

SRC := $(wildcard *.c)
OBJ := $(SRC:%.c=$(LIBD)/%.o) $(LIBD)/maglev.o

CPPFLAGS := -I..
CFLAGS ?= -Wall

$(LIBD)/%.o : %.c
	$(CC) -c $(CFLAGS) $(CPPFLAGS) $< -o $@

$(LIB): $(OBJ)
	@rm -f $(LIB)
	ar rcs $@ $(OBJ)

$(LIBD)/maglev.o: ../maglev.c
	$(CC) -c $(CFLAGS) $(CPPFLAGS) $< -o $@

$(LIBD):
	mkdir -p $@

.PHONY: clean
clean:
	rm -f $(LIB) $(OBJ)
