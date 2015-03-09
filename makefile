INSTALL_DEST ?=/usr/local/bin/

.PHONY: install uninstall

all: install

install: net_cgroup.sh
	install -g root -o root -m 0744 -t $(INSTALL_DEST) $^

uninstall:
	rm -f $(INSTALL_DEST)/net_cgroup.sh
