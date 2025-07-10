---
title: "Providing DNSSD Service on Infrastructure"
abbrev: "DNSSD on Infrastructure"
category: std

docname: draft-tlmk-infra-dnssd-latest
submissiontype: IETF
number:
date:
consensus: false
v: 3
area: INT
workgroup: DNSSD
keyword:
 - DNSSD
 - mDNS
 - DNS
venue:
  group: DNSSD
  type: Working Group
  mail: dnssd@ietf.org
  arch: https://mailarchive.ietf.org/arch/browse/dnssd/
  github: https://github.com/Abhayakara/draft-tlmk-infra-dnssd

author:
 -
    fullname: Ted Lemon
    organization: Apple Inc
    email: mellon@fugue.com

 -
    fullname: Mathieu Kardous
    organization: Silicon Labs
    email: somebody@example.com


normative:

informative:

...

--- abstract

DNS Service Discovery provides several mechanisms whereby hosts can discover and advertise services on an IP network. Such discovery can be done using Multicast DNS (mDNS) or DNS, and advertising can be done with DNSSD Service Registration Protocol (SRP) or mDNS. This document describes a way to provide a unified DNSSD proxy service that allows hosts to advertise services using SRP and discover services using unicast DNS via a Discovery Proxy rather than using of mDNS, in scenarios where mDNS is currently the only option.

--- middle

# Introduction

DNS Service Discovery (DNS-SD) [RFC6763] is a general mechanism for advertising and discovering services on IP networks. mDNS is a commonly used transport for DNS-SD. However, it has several shortcomings: it relies entirely on multicast, which works somewhat poorly on WiFi networks. Devices publishing services have to always be available to answer mDNS queries, which can have significant battery impact. When doing service discovery, such devices may do WiFi beacon skipping to save power, and in so doing, miss a large percentage of multicast traffic, making mDNS unreliable.

To address this, this document describes a way of combining several existing technologies to reduce reliance on multicast. This can be done in, for example, a CE router [RFC7084], or a SNAC Router [draft-ietf-snac-simple]. It can actually be done in any device that is expected to be continuously operational on a network link and has sufficient resources to provide the service.

There are four logical parts to the service:
- The DNS [RFC1035] zone in which DNSSD information will be stored
- The SRP [RFC9665] service, which is used to add and update services in the DNS zone
- The Advertising Proxy [draft-ietf-dnssd-advertising-proxy] service, which advertises the contents of the zone using mDNS on the infrastructure link
- The Discovery Proxy [RFC8766], which enables discovery of local services that are advertised using mDNS using the unicast DNS protocol.

In addition, the service must be advertised so that devices that would like to make use of it can discover it.

This protocol is not constrained to operation on a single IP link, but supporting multiple links is more complicated, and is not covered here.

# Conventions and Definitions

{::boilerplate bcp14-tagged}


# Modes of deployment

This service can be deployed either as a centralized service provided by infrastructure, or as an ad-hoc service that takes advantage of infrastructure but is not part of infrastructure. An example of the first would be a Customer Edge router (CE Router) [RFC7084]. CE routers are typically autonomously operating devices--although they can be configured by the end user, this is not typical. However, since they are the basis for the network infrastructure of a home network, we think of DNSSD service provided by a CE router as network infrastructure.

An example of a device that ad-hocally provides full DNSSD service would be a SNAC router. SNAC routers ad-hocally connect infrastructure networks to stub networks and provide all four of the services required for DNSSD service to the SNAC network, but only provide Advertising Proxy service to the infrastructure network. This enables devices on infrastructure to discover devices on the stub network, but not to register with SRP service nor use the SNAC advertising proxy.

# Content of Service Advertisement

The goal of advertising the service is to provide sufficient information that, having resolved the service advertisement, a user of the service has all the information needed to use the service. This includes at least:

* Name of the domain to use for service discovery
* Name of the domain to use for service registration
* Name of the host providing the DNSSD service
* Ports to use for the UDP DNS protocol when communicating with the service

## Service Advertisement on Infrastructure

Service advertisement on infrastructure is provided using the 'dnssd.service.arpa.' domain. This is a locally-served domain [RFC6303]. The local DNS resolver on infrastructure MUST answer authoratively for queries in the dnssd.service.arpa zone. Because this is an infrastructure-provided service, infrastructure advertises only one service instance, with the service instance name "infrastructure." Therefore, an infrastructure-provided DNSSD service advertises the infrastructure service instance in dnssd.service.arpa as follows:

~~~~
infrastructure.<service-name>.dnssd.service.arpa IN SRV <data>
infrastructure.<service-name>.dnssd.service.arpa IN TXT <data>
~~~~

The infrastructure DNSSD service MUST support [draft-ietf-dnssd-multi-qtypes]. Therefore, this query can be done as a single multi-qtype query. Typical DNS servers will, when answering an SRV query, include additional data containing address [RFC2782 pp 4-5]. In such situations, if the DNSSD service is provided by infrastructure, all of the information required to discover it will be returned in response to a single query.

## Ad-Hoc Service Advertisement

Ad-Hoc servers do not have control of the local DNS resolver, and therefore cannot be discovered using DNS, and must instead be discovered using mDNS. Because there is no coordination, it is possible (and in some cases likely) that there will be more than one such server, so the service instance name should be handled normally [RFC6763 section 4.1.1].

Therefore, when advertising with mDNS, the service instance will be advertised as follows:

~~~~
<instance-name>.<service-name>.local IN SRV <data>
<instance-name>.<service-name>.local IN TXT <data>
~~~~

## Content of SRV record

mDNS APIs typically do not provide a way of setting the priority and weight of the SRV record, and the infrastructure service always has the highest priority. Therefore, these fields SHOULD be set to zero, and MUST be ignored. The reason they MUST be ignored is that since they SHOULD be zero, and most devices will not be able to set them to any other value, treating them as described in [RFC2782] presents an opportunity for an attack by advertising a service with a weight of 65535.

The port field should be set to the UDP port on which SRP service is provided.

The target is the hostname of the host providing the service.

## Content of the TXT record

TXT records are made up of a series of name=value pairs. The following names are defined:

srp-tcp=<port>: the port number to use for SRP registrations using the DNS Protocol over TCP. If not present, this service is assumed to be available on the port provided in the SRV record.

dns-tcp=<port>: the port number to use for DNSSD queries using the DNS protocol over TCP. If not present, this service is assumed to be available on the port provided in the SRV record.

srv-tls=<port>: the port number to use for SRP registrations using TLS. If not present, port 853 is assumed.

dns-tls=<port>: the port number to use for DNSSD queries using the DNS protocol over TLS. If not present, port 853 is assumed.

reg-dn=<domain>: the domain name to use in SRP registrations. If not present, default.service.arpa is assumed.

domains=<domain-list>: a comma-separated list of domains in which service discovery is available. If not present, dnssd.service.arpa and local are assumed to be the only domains.

<domain>=<ip-subnet-list>: a link-specific domain that can be used to query services on that specific IP link. The link is identified by a comma-separated list of IPv4 and/or IPv6 prefixes that are present on that link. See {{interface-domain}}.

priority=<priority>: a priority for this service. See {{service-priority}}

### Interface-specific domains {#interface-domains}

A DNSSD service may support link-specific discovery proxy service. In such cases, each IP link must have its own unique domain, which is specific to the individual DNSSD service. Each such domain must have an name=value entry in the TXT record. This entry has as its name a domain name. Its value is a comma-separated list of IP prefixes that are on-link for the IP link identified by the domain.

IP subnets are in the form <IP address>/<prefix-length>. IP addresses are represented according to the IP address family. IPv4 addresses are in the dotted-decimal format as defined in [RFC952] in the section titled GRAMMATICAL HOST TABLE SPECIFICATION, in subsection A under <address>. IPv6 addresses are represented as described in [RFC5952].

As a special case, if the service only provides discovery proxy for a single link, and that is the link on which the DNSSD service is advertised, discovery of services on that link can use the "local" domain. In this case, no domains will be listed in the TXT record; if "local" discovery is to be supported alongside other domains, then the "local" domain must be included in the TXT record.

### Service Priority {#service-priority}

Infrastructure service is always the highest priority, and there can be only one such service, so the infrastructure service MUST NOT include a priority. Ad-hoc servers SHOULD include a priority. If a priority is not included, the priority of the Ad-Hoc service is assumed to be 65535.

Services should choose a priority based on their capabilities. The following priorities are defined:

0: Server is not constrained and is connected to a high-speed wired network link (that is, not WiFi, probably Ethernet or a fiber optic network).

100: Server is not constrained and is connected to a WiFi link

200: Server is constrained, but otherwise well able to provide service.

65535: Server can provide service if needed, but should not be preferred.

# Discovering the DNSSD service

A host that wishes to use the DNSSD service must first discover it. Discovery follows a series of steps:

1. Attempt to discover an infrastructure-provided DNSSD service
2. Failing that, browse for a list of Ad-Hoc services.
3. If one or more Ad-Hoc services are returned by the browse, choose one using the priority specified in the TXT record.
4. If no server is discovered, or if no discovered server appears to work, fall back to mDNS-based DNSSD service

# Security Considerations

TODO Security


# IANA Considerations

ALlocate <service-name>, "dnssd-server" is preferred

--- back

# Acknowledgments
{:numbered="false"}

TODO acknowledge.
