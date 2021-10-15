---
title: "Running WireGuard VPN (with ad-blocking) on Kubernetes"
description: How to deploy a WireGuard VPN server and DNS ad-blocker on Kubernetes
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

# (De)initialize iptables rules for routing the VPN traffic
PostUp = iptables -t nat -A POSTROUTING -s 10.10.0.0/24 -o eth0 -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -s 10.10.0.0/24 -o eth0 -j MASQUERADE


# Configure one or multiple VPN clients with a [Peer] entry for each.
# For this example we only configure 1 client
[Peer]
# The public key of the client you want to let connect to the server
PublicKey = 8EiAxqTGhKFJeLhDDaZcuEVqpGJK1qrq8Ht299J7Q2o=

# The (internal) IP we want this client to have
AllowedIPs = 10.10.0.5/32
```

As you can see from the server config example above we've chosen the network *`10.10.0.0/24`* to be our Wireguard VPN network. The server itself and all clients should be configured to IPs within that subnet. The server itself is defined as the gateway with *`10.10.0.1/24`*, and then for each client (peer) you configure a specific /32-IP in that subnet to be assigned. This IP will need to be reflected also in the client config file.

#### Kubernetes deployment

To deploy WireGuard with this configuration onto Kubernetes we have to prepare a few resources defined in a yaml file:

```yaml
---
#! Deployment definition for WireGuard for a single instance container.
#! Configuration data from a secret gets mounted as files into the container.
#! The init container ensures forwarding is enabled.
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wireguard
  namespace: wireguard
  labels:
    app: wireguard
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: wireguard
  template:
    metadata:
      labels:
        app: wireguard
    spec:
      restartPolicy: Always
      initContainers:
      - name: init
        image: busybox:1.32.0
        command:
        - sh
        - -c
        - sysctl -w net.ipv4.ip_forward=1 && sysctl -w net.ipv4.conf.all.forwarding=1
        securityContext:
          privileged: true
          capabilities:
            add:
            - NET_ADMIN
      containers:
      - name: wireguard
        image: masipcat/wireguard-go:latest
        securityContext:
          privileged: true
          capabilities:
            add:
            - NET_ADMIN
        ports:
        - containerPort: 51820
          protocol: UDP
        command:
        - sh
        - -c
        - /entrypoint.sh
        env:
        - name: LOG_LEVEL
          value: info
        resources:
          requests:
            memory: "64Mi"
            cpu: "150m"
          limits:
            memory: "128Mi"
        volumeMounts:
        - name: wireguard-config
          mountPath: /etc/wireguard/wg0.key
          subPath: wg0.key
          readOnly: true
        - name: wireguard-config
          mountPath: /etc/wireguard/wg0.conf
          subPath: wg0.conf
          readOnly: true
      volumes:
      - name: wireguard-config
        secret:
          secretName: wireguard

---
#! Secret containing all configuration data for WireGuard, to be mapped as volume/files into container
apiVersion: v1
kind: Secret
metadata:
  name: wireguard
  namespace: wireguard
  labels:
    app: wireguard
type: Opaque
stringData:
  wg0.key: 4N9FtwbtC9iY9P1C85l1QmM0OxlGRT0cHVjEuRbLuVA=
  wg0.conf: |
    [Interface]
    Address = 10.10.0.1/24
    ListenPort = 51820
    PostUp = wg set wg0 private-key /etc/wireguard/wg0.key && iptables -t nat -A POSTROUTING -s 10.10.0.0/24 -o eth0 -j MASQUERADE
    PostDown = iptables -t nat -D POSTROUTING -s 10.10.0.0/24 -o eth0 -j MASQUERADE
    SaveConfig = false

    [Peer]
    PublicKey = 8EiAxqTGhKFJeLhDDaZcuEVqpGJK1qrq8Ht299J7Q2o=
    AllowedIPs = 10.10.0.5/32

---
#! Service definition for WireGuard, exposes its UDP port as a NodePort service externally on <NodeIP:31820>
apiVersion: v1
kind: Service
metadata:
  name: wireguard
  namespace: wireguard
  labels:
    app: wireguard
spec:
  type: NodePort
  selector:
    app: wireguard
  ports:
  - port: 51820
    targetPort: 51820
    nodePort: 31820
    protocol: UDP
```

I'm using [ytt](https://carvel.dev/ytt/) to do all my templating and then deploy and manage all my Kubernetes resources with [kapp](https://carvel.dev/kapp/). The templates I wrote for deploying WireGuard onto Kubernetes are available here on GitHub: [WireGuard ytt templates](https://github.com/JamesClonk/k8s-deployments/tree/master/wireguard/templates)
```sh
$ ytt ...
$ kapp ...
```
Your own personal WireGuard VPN server should now be up and running, reachable on the NodePort IP and port 31820 as per our Kubernetes service definition.

```sh
$ nc -vz 1.2.3.4 31820
Connection to 1.2.3.4 31820 port [udp/wireguard] succeeded!
```

## AdGuard Home

AdGuard Home is a network-wide software for blocking ads and tracking. When using it as your main DNS server it allows you to take advantage of system-wide ad-blocking on all your devices and you don't need any client-side software.
It operates as a DNS server that blocks predefined ad and tracker domains using the "DNS sinkholing" method, thus preventing your devices from ever connecting to those servers.

In terms of functionality it is very similar to the well-known [Pi-Hole](https://pi-hole.net/) but much easier to setup and operate, especially in regards to Kubernetes.

AdGuard Home is open source and can be found on GitHub: https://github.com/AdguardTeam/AdGuardHome

## AdGuard Home on Kubernetes

...
https://hub.docker.com/r/adguard/adguardhome

#### Kubernetes deployment

AdGuard Home is available as a ready-to-use image on Docker Hub: https://hub.docker.com/r/adguard/adguardhome

In order to deploy it on Kubernetes we again have to prepare a yaml file with a few resources defined:

```yaml
---
#! Deployment definition for AdGuard Home for a single instance container,
#! storing configuration data on a persistent volume claim.
#! The management web interface on port 3000 and the DNS port 53
#! are be made accessible via Kubernetes service definition, see further below.
apiVersion: apps/v1
kind: Deployment
metadata:
  name: adguardhome
  namespace: adguardhome
  labels:
    app: adguardhome
spec:
  replicas: 1
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 0
  selector:
    matchLabels:
      app: adguardhome
  template:
    metadata:
      labels:
        app: adguardhome
    spec:
      containers:
      - name: adguardhome
        image: adguard/adguardhome:v0.106.3
        securityContext:
          privileged: false
          allowPrivilegeEscalation: false
        ports:
        - containerPort: 3000
          protocol: TCP
        - containerPort: 53
          protocol: UDP
        resources:
          requests:
            memory: "128Mi"
            cpu: "200m"
          limits:
            memory: "256Mi"
        readinessProbe:
          httpGet:
            path: /
            port: 3000
        livenessProbe:
          httpGet:
            path: /
            port: 3000
        volumeMounts:
        - name: adguardhome-config
          mountPath: /opt/adguardhome/conf
        - name: adguardhome-logs
          mountPath: /opt/adguardhome/work
      volumes:
      - name: adguardhome-config
        persistentVolumeClaim:
          claimName: adguardhome
      - name: adguardhome-logs
        emptyDir: {}

---
#! Persistent volume claim to store all AdGuard Home configuration data
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: adguardhome
  namespace: adguardhome
  labels:
    app: adguardhome
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi

---
#! Service definition for the AdGuard Home web interface and DNS port
apiVersion: v1
kind: Service
metadata:
  name: adguardhome
  namespace: adguardhome
  labels:
    app: adguardhome
spec:
  type: ClusterIP
  selector:
    app: adguardhome
  ports:
  - port: 3000
    targetPort: 3000
    protocol: TCP
  - port: 53
    targetPort: 53
    protocol: UDP

---
#! Ingress resource, used for HTTP(S) access to the AdGuard Home web interface via Kubernetes ingress-controller
#! https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: adguardhome
  namespace: adguardhome
  labels:
    app: adguardhome
  annotations:
    #! Modify "cert-manager.io/cluster-issuer" to match your certificate ClusterIssuer if you are using cert-manager,
    #! otherwise remove it entirely
    cert-manager.io/cluster-issuer: letsencrypt-prod
    #! Modify "kubernetes.io/ingress.class" to match your ingress-controller
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    #! Configure the hostname for the AdGuard Home web interface
    - adguardhome.my-example-domain.com
    secretName: adguardhome-tls
  rules:
  #! Configure the hostname for the AdGuard Home web interface
  - host: adguardhome.my-example-domain.com
    http:
      paths:
      - backend:
          serviceName: adguardhome
          servicePort: 3000
```
Same as before with WireGuard I'm using a collection of ytt template files and do my deployment with kapp. The set of templates can be found here: [AdGuard Home ytt templates](https://github.com/JamesClonk/k8s-deployments/tree/master/adguardhome/templates)
```sh
ytt ...
kapp ...
```
And now we've got an DNS ad-blocker deployment up and running! 🥳

## Use it with your Android phone

WireGuard clients exist for a large variety of operating systems and devices.
It's easy to use it as your VPN on any Windows, Linux, OSX, iOS or Android device. Simply download and install a client for the platform of your choice: https://www.wireguard.com/install/

One of the more interesting use-cases would be to use it as a VPN for your mobile phone. For Android the best way is to use the official client, maintained by the WireGuard devs themselves: the [Android WireGuard app](https://play.google.com/store/apps/details?id=com.wireguard.android)

#### What are the benefits of doing this?

So at this point you might wonder why doing all of this in the first place, why would you run your own VPN server and DNS ad-blocker on the internet? Why connect to it with your phone?

There are various reasons for running this on my Kubernetes cluster (besides it being a fun project to thinker with), but the two most important one are these:
- Secure network traffic in "foreign" networks, wifi, etc. for your phone
  - All traffic will go through the VPN connection and exit on your "trusted" Kubernetes cluster, instead of being at the mercy of whatever hotel or office Wi-Fi you are currently using with your phone for example.
- System-wide ad-blocking via DNS on Android!
  - Having a DNS server that does ad-blocking being used as the sole DNS for the VPN connection means that you automatically get a system-wide ad-blocker for your Android phone. No more pesky ads in the browser or even within any apps themselves!

Let's get started on preparing a client configuration file for your phone:

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

As you can see in the example above with the *`DNS`* entry we've defined which DNS server should be used by the client once the VPN connection is established. In this case it is the IP under which our AdGuard Home DNS server is reachable, and thus we have now DNS-based ad-blocking automatically included for all our VPN traffic/connections.

### qrencode

Once we have the client config file ready our next step is to import it into the [WireGuard app](https://play.google.com/store/apps/details?id=com.wireguard.android) on your phone.

The easiest way to do this is with a QR-code. We'll install **`qrencode`** for this:

```sh
# pacman -S qrencode
resolving dependencies...
looking for conflicting packages...

Packages (1) qrencode-4.1.1-1

Total Installed Size:  0.10 MiB
Net Upgrade Size:      0.00 MiB

:: Proceed with installation? [Y/n] Y
(1/1) checking keys in keyring                            [##############################] 100%
(1/1) checking package integrity                          [##############################] 100%
(1/1) loading package files                               [##############################] 100%
(1/1) checking for file conflicts                         [##############################] 100%
(1/1) checking available disk space                       [##############################] 100%
:: Processing package changes...
(1/1) installing qrencode                                 [##############################] 100%
:: Running post-transaction hooks...
(1/1) Arming ConditionNeedsUpdate...
```

Now let's use it to generate a QR-code picture of our config file, displaying it either directly in the terminal:
```sh
$ qrencode -t ANSIUTF8 -r client.conf
[QR CODE in terminal]
```

Or by writing it to a PNG file to display:
```sh
$ qrencode -t PNG -r client.conf -o client_conf.png
```
![GitHub Pages](/images/wireguard-qrcode.png)

Simply scan the resulting QR-code with the WireGuard app on your phone to import the client configuration.

After importing you can then connect to the VPN and enjoy an ad-free internet experience on your whole Android phone, be it in the browser or inside apps! 😃

![GitHub Pages](/images/wireguard-android.png)

WireGuard is *very fast*, stable and also handles reconnects gracefully, allowing you to basically have the VPN connection open 24/7.
