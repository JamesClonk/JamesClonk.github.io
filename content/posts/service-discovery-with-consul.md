---
title: "Service Discovery with Consul"
description: "Consul provides automatic service discovery in a cloud-native world of microservices"
tags: [service discovery,consul,unbound,dns]
author: Fabio Berchtold
date: 2015-06-11T14:40:58
draft: false
---

## What is Service Discovery?

In a cloud environment applications can change often, containers can move around, and VMs can be shutdown and recreated at any time. How do you keep track of where your databases or other services or applications are located and what their IP addresses are?
Modern microservices architecture requires the introduction of "Service Discovery".

Service discovery is the means to provide a way for automatic detection of applications and services in the cloud, to keep track of the location of service instances with dynamically assigned IP address.

## What is Consul?

[Consul](https://www.consul.io/docs/intro) is a fully integrated service discovery solution with a service registry, providing a web UI dashboard and API access for service discovery, configuration, leader election and a key/value store. It allows you to discover, register and lookup services or applications for all kinds of workloads across VMs and networks. Entries in the service catalog can be added or removed automatically based on health checks.

It enables services to discover each other by storing location information such as IP addresses in a single centralized service registry.

![Consul](/images/consul-service-registry.png)

The goal of service discovery is to provide a catalog of available services or applications. Via a local Consul agent applications can provide a service definition to declare their availability to associate themselves with a health check. Such services can be defined in a configuration file or added at runtime over an HTTP API.


Consul servers provide a strong consistency guarantee as they replicate their state using the [Raft consensus protocol](https://www.consul.io/docs/architecture/consensus). The Raft protocol allows the servers in a Consul cluster to coordinate with each through leader elections and a quorum. If for example the Consul server currently being the leader were to suddenly fail this would trigger a new leader election and the quorum would vote and decide on a new cluster leader.

### How can I use it?

The main interface for Consul service discovery is DNS. Via simple DNS requests applications can make use of service discovery without needing any libraries or other code integration tied directly to Consul.

For example an application could lookup its database backend by making a DNS query for `postgres-instance-2.service.consul`. Consul translates this query automatically into a lookup of all nodes that are registered to provide the postgres service `postgres-instance-2` and have no failing health checks, with the returning result being their *current* IP addresses that the application then can use to connect to the database servers.

Assuming a Consul agent is currently running on the local VM you could query the location of a particular service for example simply like this:
```shell
$ dig @127.0.0.1 -p 8600 my-mongodb.service.consul
...

;; ANSWER SECTION:
my-mongodb.service.consul. 0   IN  A   192.168.1.77

...

;; Query time: 1 msec
;; SERVER: 127.0.0.1#8600(127.0.0.1)
```

### Integrate it into your DNS

Now of course we could program our applications to go and query the Consul servers themselves directly whenever they need to resolve the location of a particular service, but an even better way than having to hard-code any such behaviour would be to integrate the Consul DNS resolution within your default DNS provider.
If you are using for example *dnsmasq* or *[unbound](https://www.nlnetlabs.nl/projects/unbound/about/)* in your infrastructure you can easily configure a forward zone for `*.service.consul` to delegate any such request that your normal DNS server receives to be forwared along to the Consul DNS.
Let's say you also have a local Consul agent running on your unbound VMs and that agent is part of your Consul cluster, then you can simply define stub-zones like these in the unbound configuration files:
```yaml
stub-zone:
 name: "service.consul"
 stub-addr: 127.0.0.1@8600  # forward ".service.consul" queries to local Consul agent
 
stub-zone:
 name: "node.consul"
 stub-addr: 127.0.0.1@8600  # forward ".node.consul" queries to local Consul agent
```

This way any DNS query your applications do within your network will be able to resolve and locate services from the Consul service catalog. 😀
