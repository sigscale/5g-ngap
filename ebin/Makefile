
ERLC			= erlc
ERLCFLAGS	= -W -v +debug_info

%.beam:../src/%.erl
	$(ERLC) $(ERLCFLAGS) $<

.PHONY:	default
default:	all

.PHONY:	all
all:		ngap

.PHONY:	ngap
ngap:		ngap.beam

.PHONY:	clean
clean:
	- @rm -f ngap.beam

