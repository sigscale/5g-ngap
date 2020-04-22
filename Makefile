
.PHONY:	default
default:	all

.PHONY:	all
all:
	cd asn_src && $(MAKE)
	cd src && $(MAKE)
	cd ebin && $(MAKE)

.PHONY:	clean
clean:
	cd asn_src && $(MAKE) $@
	cd src && $(MAKE) $@
	cd ebin && $(MAKE) $@

