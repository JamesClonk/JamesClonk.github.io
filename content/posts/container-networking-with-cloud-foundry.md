---
title: "Container Networking with Cloud Foundry"
description: "Container-to-Container Networking on Cloud Foundry allows for secure and fast direct TCP and UDP communication between your applications"
tags: [cloud foundry,containers,networking,app cloud,service discovery,dns]
author: Fabio Berchtold
date: 2018-05-19T16:06:35+02:00
draft: false
---

> *Container-to-Container Networking on the Swisscom Application Cloud allows for secure and fast direct TCP and UDP communication between your applications. And thanks to its built in Application Service Discovery your app containers will easily be able to locate each other.*

![Cloud Foundry](/images/cf-logo.png)

The Swisscom Application Cloud uses the open-source distribution of [Cloud Foundry](https://www.cloudfoundry.org/) to provide you with a managed platform-as-a-service.
Ever since the platforms official release we've continually been adding and implementing new features, and one of these is the Container-to-Container Networking.

Container networking enables a policy-driven, direct communication between your application instances on Cloud Foundry.

Based on policies you can set through the CF CLI, your applications now have direct connectivity with each other, either through TCP or UDP. Your choice!
This of course provides many benefits like reduced latency and increased throughput thanks to direct communication instead of going through the GoRouter or an external load-balancer. It also enables you as a developer to set fine grained access controls through these app to app policies. Your apps become more secure with private communication between each other directly, using the container IPs instead of having to use a public route. This also gives you the option to hide applications from the outside and access them without adding a route to them.

Container-to-Container Networking internally uses an overlay network to manage and allow communication between your app instances. All app containers are assigned a unique private container IP address, which they then can use to talk to each other.
The overlay network is not externally routable, and traffic sent between your containers does not exit the overlay network.

You can get an in-depth look at the architecture behind the scenes here on GitHub:
https://github.com/cloudfoundry/cf-networking-release/blob/develop/docs/arch.md

## Great, how do I use this?

To use the Container-to-Container Networking feature you will have to create networking policies for your apps. These policies specify a source app, destination app, protocol, and port so that app instances can communicate directly without going through the GoRouter, a load-balancer, or a firewall. Container-to-Container Networking supports both TCP and UDP, and you can configure policies for multiple ports or port ranges. Networking policies apply immediately without having to restart or restage your app.

The diagram below illustrates how app instances communicate in a deployment with Container-to-Container Networking enabled and networking policies in place.
In this example, the app developer created policies to regulate the flow of traffic between **App A**, **B**, and **C**.

	- Allow traffic from App A to App B on TCP port range 7000-8000
	- Allow traffic from App A to App C  on UDP port 5053

If traffic and its direction is not explicitly allowed, it is denied by default. For example, App B cannot send traffic to App C.

![Container Networking](/images/c2c-apps.png)

Using the CF CLI the commands to setup these networking policies:
![Container Networking](/images/c2c-setup.png)

Of these three apps only App A is exposed to the outside world with a mapped route:
![Container Networking](/images/c2c-apps-running.png)

We can display the configured policies with the network-policies command:
![Container Networking](/images/c2c-display-networking.png)

Let's create an additional policy with add-network-policy to also enable direct TCP communication on port 4567 from App C to App B (but not vice-versa!):
![Container Networking](/images/c2c-add-networking.png)

If we later decide that granting App C to App B access was a mistake, we can simply remove the network policy again by using remove-network-policy:
![Container Networking](/images/c2c-remove-networking.png)

Now App C will no longer have direct communication access to App B as before.

That takes care of how to setup your private container network, but how do your apps figure out each others internal IP addresses?

In the past you would have to deploy your own service discovery, like Eureka, or write your own by for example using a Redis service instance where each app then posts its container IP to it. One such example of this technique between a frontend and a backend app can be seen here on GitHub: [c2cn_demo/redis_discovery](https://github.com/JamesClonk/c2cn_demo/tree/master/redis_discovery)

But recently we've added a better and much more simple way for service discovery, integrated into the platform itself and available to all apps by default.

## App Service Discovery

The Swisscom Application Cloud supports DNS-based service discovery that lets your apps find each others internal IP addresses. For example, a frontend app instance can use the service discovery mechanism to establish communications with a backend app instance.

Container-to-Container app service discovery does not provide client-side load-balancing or circuit-breaking. It just lets your apps publish service endpoints to each other, unbrokered and unmediated, ready for you to use.

With app service discovery your apps pushed to the Swisscom Application Cloud can establish direct container-to-container communications through a known route served by the internal DNS. The special domain `apps.internal` has been made available to you for this purpose:

![Cloud Foundry](/images/c2c-apps-internal-domain.png)

Using this domain allows your frontend apps to easily discover and connect with any backend apps it needs.
To establish container-to-container communications between a frontend and a backend app, all you have to do is:

- Push your backend app
- Map a route with the special `apps.internal` domain to it, for example `backend-app.apps.internal`
- Push the frontend app
- Create the relevant networking policies that allow direct traffic from the frontend to the backend app

The frontend app now will be able to discover the backend app by DNS resolving backend-app.apps.internal. The resulting IPs are the internal overlay IPs of all your backend app containers and can be used for direct communication.

Think of it like this:

![Container Networking](/images/c2c-app-sd.png)

You can find an example that's making use of app service discovery here, with [Cats and Dogs with Service Discovery](https://github.com/cloudfoundry/cf-networking-examples/blob/master/docs/c2c-with-service-discovery.md) on GitHub, that demonstrates communication between frontend and backend apps on Cloud Foundry.

If you follow along the example you'll end up with a situation similar to this:
![Cloud Foundry](/images/c2c-cats-and-dogs.png)

The apps are both deployed, have a networking policy that allows the frontend access to the backend of which there are 4 instances running, and the key element here being the special route dogs-backend.apps.internal that has been mapped to the backend app:
![Container Networking](/images/c2c-dogs-backend-route.png)

Through this route the frontend can now DNS query all container IPs of the backend app:
![Cloud Foundry](/images/c2c-dig.png)

Success! 😀

Here you can find some more information about the app service discovery:
https://www.cloudfoundry.org/blog/polyglot-service-discovery-container-networking-cloud-foundry/

![Party Parrot](/images/parrot.gif) Try it out now! https://developer.swisscom.com/ ![Party Parrot](/images/parrot.gif)
