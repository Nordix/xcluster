O ?= .
CFLAGS := -I.

.PHONY: all clean
all: $(O) $(O)/template

$(O)/template: main.c cmd.c cmdTemplate.c
	$(CC) -o $@ $(CFLAGS) $^
	@strip $@

clean:
	rm -f $(O)/template

$(O):
	mkdir -p $(O)
