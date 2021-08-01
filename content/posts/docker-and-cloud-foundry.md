---
title: "Docker and Cloud Foundry"
description: "Cloud Foundry is the leading open source industry standard for a Platform-as-a-Service. With the next version of the Cloud Foundry scheduler, the user is now able to run his Docker images with a full PaaS experience on the Swisscom Application Cloud."
tags: [cloud foundry,containers,docker,app cloud]
authors: []
author: Fabio Berchtold
date: 2016-05-04T14:35:57+02:00
draft: false
---

> *Cloud Foundry is the open source industry standard for a Platform-as-a-Service. With the next version of the Cloud Foundry scheduler, the user is now able to run his Docker images with a full PaaS experience on the Swisscom Application Cloud. Find out how to deploy your Docker images now!*

## **"Docker! Docker! Docker!"** – What is it?

![Docker](/images/docker-docker.png)

From https://www.docker.com/what-docker:

> Docker allows you to package an application with all of its dependencies into a standardized unit for software development.

> Docker containers wrap up a piece of software in a complete filesystem that contains everything it needs to run: code, runtime, system tools, system libraries – anything you can install on a server. This guarantees that it will always run the same, regardless of the environment it is running in.

By now probably anyone has heard of [Docker](https://www.docker.com/), the container technology that allows you to package your apps into images and automate the deployment of them inside containers that providing resource isolation by using Linux kernel features such as [cgroups](https://en.wikipedia.org/wiki/Cgroups) and [namespaces](https://en.wikipedia.org/wiki/Linux_namespaces).

Docker makes it easier to build, deploy, and run apps by using Docker images. They allow a developer to ship their apps with all of the parts it needs, such as libraries and other dependencies, packaged into such images as one complete package. And thanks to these container images the app runs on any other Linux host, regardless of what distribution it is or what software and libraries in which versions it has installed. All that's needed is a runtime that knows how to containerize and run such an image. Usually this would be Docker itself.

But there are other alternatives out there that understand and can run apps with the Docker image format, for example [Cloud Foundry](https://www.cloudfoundry.org/).

## And what is **Cloud Foundry**?

![Cloud Foundry](/images/cf-logo.png)

Cloud Foundry is an open source cloud [Platform-as-a-Service](https://en.wikipedia.org/wiki/Platform_as_a_service) on which developers can deploy, run and scale their apps. Unlike most other cloud computing platforms, which are tied to a particular provider, like Amazons AWS, Cloud Foundry through its nature of being open source is available as a stand-alone software package for anyone to setup on its own infrastructure.

Apps deployed on Cloud Foundry can then access external resources like for example databases via [services](https://docs.developer.swisscom.com/devguide/services/) offered by the platform itself. All external dependencies such as databases, messaging systems, files systems and so on are made available through such services. When an app gets pushed on to Cloud Foundry, for these services it can then be specified through a manifest or via a command line tool which ones to use.

The deployed app gets distributed on the Cloud Foundry backend infrastructure and is running inside a container. The Cloud Foundry platform supports many different languages and frameworks already out of the box, including Java, Node.js, Ruby, PHP, Python, and Go. Many other languages are available through the use of additional [buildpacks](https://docs.developer.swisscom.com/buildpacks/index.html).

Swisscom uses Cloud Foundry for its PaaS offering, the [Swisscom Application Cloud](http://developer.swisscom.com/).

![Devportal](/images/tcp-devportal.png)

## So how can I use **Docker** with **Cloud Foundry**?

Let's say we have an app, split into a frontend and backend part and built two Docker [images](https://docs.docker.com/engine/userguide/containers/dockerimages/) with these parts. Once these images are built and uploaded to any Docker registry, mostly likely [Docker Hub](https://hub.docker.com/), they can be deployed on the Swisscom Application Cloud.

For this blog I prepared two such images on Docker Hub in my personal repository space.
[jamesclonk/guestbook-frontend](https://hub.docker.com/r/jamesclonk/guestbook-frontend/) and [jamesclonk/guestbook-backend](https://hub.docker.com/r/jamesclonk/guestbook-backend/).
The source code for these is available in this [GitHub repository](https://github.com/JamesClonk/cloudfoundry-samples/tree/master/docker-guestbook).

We are now going to deploy these two Docker images on the Swisscom Application Cloud, through using its CLI tool `cf`. If you have not yet installed or used it before, please consult the documentation available here: https://docs.developer.swisscom.com/cf-cli/index.html

First we push the frontend app:

```shell
$ cf push guestbook-frontend --docker-image jamesclonk/guestbook-frontend --hostname docker-guestbook
```

We specify the name of our application guestbook-frontend, the Docker image to use jamesclonk/guestbook-frontend and the hostname guestbook. This means once the app is running it will be available under the subdomain docker-guestbook.scapp.io on the Swisscom Application Cloud. The docker image will be pulled from Docker Hub, assembled into a Cloud Foundry app droplet and deployed through the Cloud Foundry Diego runtime. This app droplet will not be running inside a Docker container though, as currently Diego uses Garden / Garden-Linux containers.

We could also decide upfront how much instances, memory and diskpace should be allocated for our app when deploying.
Let's do this for the second app:

```shell
$ cf push guestbook-backend --docker-image jamesclonk/guestbook-backend --hostname docker-guestbook-backend -i 2 -m 256M -k 32M
```

This will start our backend application with 2 instances, and a limit of 256MB RAM and 64MB diskspace. We don't need a lot of diskspace for the backend as it has no public assets to serve and basically only interacts with MongoDB as its datastore and our frontend-app. No need for a filesystem. 😉

We can then check the status and number of instances of our app:

```shell
$ cf app guestbook-backend
```

This shows us how many instances are currently running, and how their cpu usage, memory and disk space consumption is:
![Scale](/images/docker-app-backend.png)

It is also possible to change these settings even if the app is already running:

```shell
$ cf scale guestbook-backend -m 128M -i 4
```
![Scale](/images/docker-more-backend.png)

Now the backend-app of course also wants to have a database to store all its data. In our case this would be a MongoDB. Let's check the services marketplace to see what the Swisscom Application Cloud offers:

```shell
$ cf marketplace
```
![Marketplace](/images/docker-marketplace.png)

We are going to create a MongoDB service instance now for our app to use and then bind to it:

```shell
$ cf create-service mongodb small guestbook-db
$ cf bind-service guestbook-backend guestbook-db
```

You can find more details on how to use these services and how to attach them to your app in our documentation: https://docs.developer.swisscom.com/service-offerings/index.html

The app will now be able to read the connection string and credentials it needs through ENV variables available to it. We can check these by running the following command:

```shell
$ cf env guestbook-backend
```
![MongoDB](/images/docker-mongodb.png)

Now we have our app running on the Cloud Foundry platform, where we can can easily scale it out if we ever need to, it's highly available and we don't need to take care of monitoring or operations. It just runs by itself.

Go to https://developer.swisscom.com and try it out right now for yourself! 
