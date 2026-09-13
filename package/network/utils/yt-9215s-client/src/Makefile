CC ?= gcc
CFLAGS ?= -Wall -Wextra -O2

all: switch_ctl

switch_ctl: switch_ctl.o
	$(CC) $(LDFLAGS) -o $@ $^

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f switch_ctl *.o
