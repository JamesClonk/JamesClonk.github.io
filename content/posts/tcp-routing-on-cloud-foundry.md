---
title: "TCP-Routing on Cloud Foundry"
description: "The Swisscom Application Cloud, which is based on the open source industry standard Cloud Foundry, offers an exciting new feature for its users. TCP routing, the ability to support and expose any TCP-based, non-HTTP application to the world. Let's have a closer look and learn how to use TCP routing."
tags: [cloud foundry,containers,networking,routing,app cloud]
author: Fabio Berchtold
date: 2018-04-15T10:33:42+02:00
draft: false
---

> *The Swisscom Application Cloud, which is based on the open source industry standard Cloud Foundry, offers an exciting new feature for its users. TCP routing, the ability to support and expose any TCP-based, non-HTTP application to the world. Let's have a closer look and learn how to use TCP routing.*

The [Swisscom Application Cloud](https://developer.swisscom.com/) is based on [Cloud Foundry](https://www.cloudfoundry.org/), the leading open source industry standard for building your own platform-as-a-service.

![Devportal](/images/tcp-devportal.png)

One of the many great features Cloud Foundry offers is TCP routing, the ability to route and expose any TCP-based traffic from your application to the outside world.
TCP routing in Cloud Foundry is based on reserving ports on a TCP router group for an application, mapped to a TCP-route and domain which is then exposed by a frontend load-balancer like our F5. Incoming traffic from a Client on that port will be forwarded to your application container instances using a round-robin load-balancing policy. TCP router groups are a collection of multiple Cloud Foundry TCP routers, ensuring high availability.

![Devportal](/images/tcp-route-ports.png)

TCP Routing allows you to push applications onto the Application Cloud you previously would not have thought of.

For example you could push [Memcached](https://memcached.org/) as an app, an in-memory cache that communicates via TCP:

```shell
$ cf push -o memcached memcached
Creating app memcached in org swisscom / space examples as user1...
OK

...

Showing health and status for app memcached in org swisscom / space examples as user1...
OK

requested state: started
instances: 1/1
usage: 1G x 1 instances
urls: memcached.scapp.io
state since cpu memory disk details
#0 running 2018-03-05 12:31:31 PM 0.0% 0 of 1G 0 of 1G
```

And all you need to do now to expose it over TCP would be to simply bind a TCP-route to it, specifying the port by which it is going to be exposed to the outside world:

```shell
$ cf map-route memcached tcp.scapp.io --port 35666
Creating route tcp.scapp.io:35666 for org swisscom / space examples as user1...
OK

Adding route tcp.scapp.io:35666 to app memcached in org  swisscom / space examples as user1...
OK
```

Your application should now be exposed over TCP port *35666* on the domain `tcp.scapp.io`.
Let's verify that this actually works, by using telnet to open up a TCP connection to our app on that domain and port:

```shell
$ telnet tcp.scapp.io 35666
Trying 211.222.233.100...
Connected to tcp.scapp.io.
Escape character is '^]'.

set greeting 1 0 11
Hello World
STORED

quit
Connection closed by foreign host.

$ telnet tcp.scapp.io 35666
Trying 211.222.233.100...
Connected to tcp.scapp.io.
Escape character is '^]'.

get greeting
VALUE greeting 1 11
Hello World
END

quit
Connection closed by foreign host.
```

Works like a charm! 😃

Another interesting type of application possible thanks to TCP routing would be to deploy a game server that communicates also over TCP only.
Let's try that out with [Minecraft](https://minecraft.net/):

![Devportal](/images/tcp-routing.png)
```shell
$ cf push minecraft -o itzg/minecraft-server -i 1 -m 1536M --no-start
$ cf create-route examples tcp.scapp.io --port 28888
$ cf map-route mcs tcp.scapp.io --port 28888
$ cf set-env mcs EULA true
$ cf set-env mcs MOTD 'Minecraft powered by Swisscom Application Cloud'
$ cf start minecraft

$ cf app minecraft
Showing health and status for app minecraft in org  swisscom / space examples as user1...

name:              minecraft
requested state:   started
instances:         1/1
usage:             1.5G x 1 instances
routes:            tcp.scapp.io:28888
last uploaded:     Mon 12 Feb 15:26:23 UTC 2018
stack:             cflinuxfs2
docker image:      itzg/minecraft-server

     state     since                  cpu    memory           disk          details
#0   running   2018-03-28T22:44:18Z   1.2%   959.5M of 1.5G   35.2M of 1G
```

There you go, Minecraft running on the Application Cloud:
![Devportal](/images/tcp-minecraft.png)

Running a Minecraft server on the Application Cloud would previously not have been possible due to its TCP only nature.

Now of course we would still be missing a persistent filesystem here, so your world will be lost once your app gets restarted. But that is a problem hopefully soon being fixed too by adding [Volume Services](https://docs.cloudfoundry.org/running/deploy-vol-services.html) to Cloud Foundry.

To use the TCP routing feature on the Swisscom Public Application Cloud offering, simply send a support request detailing your intended use for it to get an appropriate quota setting for your organization enabled so you can start pushing TCP-based apps onto the Cloud. 👍 

For more details on how to use the TCP routing from an end-user perspective you can consult the documentation for further information:
https://docs.developer.swisscom.com/devguide/deploy-apps/routes-domains.html#create-route-with-port
