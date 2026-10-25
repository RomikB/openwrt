CC ?= gcc
CFLAGS ?= -Wall -Wextra -O2
LDFLAGS ?=

all: nvram-env

nvram-env: nvram-env.o
	$(CC) $(LDFLAGS) -o $@ $^

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f nvram-env *.o

.PHONY: all clean
