
ASN1		=	NGAP-CommonDataTypes.asn1 \
			NGAP-Constants.asn1 \
			NGAP-Containers.asn1 \
			NGAP-IEs.asn1 \
			NGAP-PDU-Contents.asn1 \
			NGAP-PDU-Descriptions.asn1

ERLC			= erlc
ASNC			= $(ERLC) 
ASNCFLAGS	= -W +debug_info

../src/%.erl:%.set.asn1 ${ASN1}
	$(ASNC) $(ASNCFLAGS) +noobj -o ../src $<

.PHONY:	default
default:	all

.PHONY:	all
all:		../src/ngap.erl

.PHONY:	clean
clean:

