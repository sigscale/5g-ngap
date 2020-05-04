## Makefile.am
##
## Process this file with automake to produce Makefile.in

erl_DATA =	ngap_codec.erl

ngap_codec.erl:	$(top_srcdir)/asn_src/ngap_codec.set.asn1
	$(ERLC) $(ERLCFLAGS) +noobj $<

CLEANFILES = $(erl_DATA) ngap_codec.asn1db ngap_codec.hrl

