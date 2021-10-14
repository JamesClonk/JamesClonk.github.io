---
title: "Running WireGuard VPN (with adblocking) on Kubernetes"
description: Deploying a WireGuard VPN server and DNS ad-blocker on Kubernetes
tags: [kubernetes,vpn,wireguard,adblock]
author: Fabio Berchtold
date: 2021-10-14T17:19:41+02:00
draft: false
---

# WireGuard

...
https://www.wireguard.com
VPN
what is it?
how can it help me?

## WireGuard on Kubernetes

...
how to run: looked at many different images, *list*, ultimately decided on [masipcat/wireguard-go](https://github.com/masipcat/wireguard-go-docker), because its very simple and uncomplicated image, also directly provides a K8s example out of the box.

#### server.conf
```sh
# Server configuration
[Interface]
# The (internal) IP we want to give the VPN server itself
Address = 10.10.0.1/24

# The port the server should listen to, 51820 is the default for WireGuard
ListenPort = 51820

# The private key of the server
PrivateKey = 4N9FtwbtC9iY9P1C85l1QmM0OxlGRT0cHVjEuRbLuVA=

# Configure server private key and (de)initialize iptables rules for routing the VPN traffic
PostUp = wg set wg0 private-key /etc/wireguard/wg0.key && iptables -t nat -A POSTROUTING -s 10.10.0.0/24 -o eth0 -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -s 10.10.0.0/24 -o eth0 -j MASQUERADE

# Don't try to save WireGuard config file on shutdown (it gets overwritten by Kubernetes anyway)
SaveConfig = false


# Configure one or multiple VPN clients with a [Peer] entry for each.
# For this example we only configure 1 client
[Peer]
# The public key of the client you want to let connect to the server
PublicKey = 8EiAxqTGhKFJeLhDDaZcuEVqpGJK1qrq8Ht299J7Q2o=

# The (internal) IP we want this client to have
AllowedIPs = 10.10.0.5/32
```

As you can see from the server config example above we've chosen the network *`10.10.0.0/24`* to be our Wireguard VPN network. The server itself and all clients should be configured to IPs within that subnet. The server itself is defined as the gateway with *`10.10.0.1/24`*, and then for each client (peer) you configure a specific /32-IP in that subnet to be assigned. This IP will need to be reflected also in the client config file.


## AdGuard Home

...
https://github.com/AdguardTeam/AdGuardHome
Ad-blocker
What is it?
How can it help me?
DNS ad-blocking

## AdGuard Home on Kubernetes

...
https://hub.docker.com/r/adguard/adguardhome

## Use it with your Android phone

...
explain DNS of adguardhome.
qrencode example.
screenshot of wireguard app on phone.

#### client.conf
```sh
# Client configuration
[Interface]
# Assign the IP as configured on the server config for this peer
Address = 10.10.0.5/32

# The private key of this client (its corresponding public key is in the server config for this peer)
PrivateKey = wMq8AvPsaJSTaFEnwv+J535BGZZ4eWybs5x31r7bhGA=

# DNS server the VPN client should use once connected.
# In our case this is the ClusterIP of our AdGuard Home Kubernetes service
DNS = 10.0.15.31


# The VPN server we want to connect to
[Peer]
# The public key of the server you want to connect to
PublicKey = uJ0bUIe8Kc+vp27sJVDLH8lAmo4E3dfGtzRvOAGQZ0U=

# The IP that points to our WireGuard pod on Kubernetes, could be a K8s LoadBalancer IP, ClusterIP, etc..
# In our case it is the node IP directly as we used a NodePort
Endpoint = 1.2.3.4:31820

# What IPs/subnet should be routed through the VPN? Use "0.0.0.0/0, ::/0" for all traffic
AllowedIPs = 0.0.0.0/0, ::/0

# Keep the connection alive through NAT and firewalls by sending a keepalive packet every 25 seconds
PersistentKeepalive = 25
```

As you can see from the above client config example we've defined with the *`DNS`* entry which DNS server should be used by the client once the VPN connection is established. In this case it is the IP under which our AdGuard Home DNS server is reachable, and thus we have now DNS-based ad-blocking automatically included for all our VPN traffic/connections.

After importing the client configuration via QR code you can then simply connect to the VPN and enjoy an ad-free internet experience on your whole Android phone, be it in the browser or inside apps! 😃

![GitHub Pages](/images/wireguard-android.png)

WireGuard is *very fast*, stable and also handles reconnects gracefully, allowing you to basically have the VPN connection open 24/7.
