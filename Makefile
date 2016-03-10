
BUILDDIR=$(HOME)/.le/dnsapi

install:
	install -m 750 dns-route53-python.sh $(BUILDDIR)
	install -m 640 dns-route53-python.conf $(BUILDDIR)
