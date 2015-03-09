INSTALL_DEST ?=/usr/local/bin/
SYSTEMD_SERVICE_DEST ?=/usr/lib/systemd/system/

.PHONY: install uninstall install_services

all: install

install: net_cgroup.sh
	install -g root -o root -m 0744 -t $(INSTALL_DEST) $^

install_services: transmission-ns.service net_cgroup.service
	install -g root -o root -m 0644 -t $(SYSTEMD_SERVICE_DEST) $^

uninstall:
	rm -f $(INSTALL_DEST)/net_cgroup.sh
