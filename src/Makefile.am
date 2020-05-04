## Makefile.am
##
## Process this file with automake to produce Makefile.in

erl_DATA =	ngap.erl

ngap.erl:	$(top_srcdir)/asn_src/ngap.set.asn1
	$(ERLC) $(ERLCFLAGS) +noobj $<

CLEANFILES = $(erl_DATA) ngap.asn1db ngap.hrl

