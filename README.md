# 3GPP TS 38.413 NG Application Protocol (NGAP) V16.1.0 (2020-03)

## 3GPP TS 38.410 5G; NG-RAN; NG General Aspects and Principles
NGAP services are divided into two groups:
* Non UE-associated services
* UE-associated services

![stack-diagram](https://raw.githubusercontent.com/sigscale/5g-ngap/master/doc/ngap-stack.png)
https://raw.githubusercontent.com/sigscale/5g-ngap/master/doc/ngap-stack.png

## 3GPP TS 38.412 NG Signalling Transport
SCTP (RFC4960) shall be supported as the transport layer of NG-C signaling bearer.
* A single stream shall be reserved for non UE-associated signaling.
* At least one stream shall be reserved for UE-associated signaling.
* All UE-associated signaling for a UE shall use the same stream stream.

