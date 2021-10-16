---
title: "Using a Service Broker in Cloud Foundry or Kubernetes"
description: The Open Service Broker API spec and what it's good for
tags: [osbapi,cloud foundry,service broker,kubernetes,app cloud]
author: Fabio Berchtold
date: 2019-12-31T11:23:54+02:00
draft: false
---

## OSBAPI?

The [Open Service Broker API](https://www.openservicebrokerapi.org/) (OSBAPI) is a specification that defines a common language for service providers that your cloud native applications can use to manage cloud services without lockin.

OSBAPI allows independent software vendors, service providers and developers to easily integrate and consume services for workloads running on cloud native platforms such as the [Swisscom Application Cloud](https://developer.swisscom.com/), which is based on [Cloud Foundry](https://cloudfoundry.org/) and [Kubernetes](https://kubernetes.io/). The specification describes a simple set of API endpoints which can be used to provision, access and manage various service offerings, and has been adopted by many different platforms and thousands of service providers by now.

The specification itself can be found on GitHub under https://github.com/openservicebrokerapi/servicebroker     
As you can see it is very simple and only has a handful of endpoints, each having to support only a couple of methods.

To use the OSBAPI and integrate a new service into your cloud platform you will need to implement it through a service broker.

### A Service Broker is what you need!

Service brokers manage the lifecycle of services, and platforms interact with service brokers to provision, get access to and manage the services they offer. OSBAPI defines these interactions, and therefore allows software providers to offer their services to anyone, regardless of the technology or infrastructure those software providers wish to utilise.

Service brokers compliant with the OSBAPI specification can provision new instances of services that they provide, and in turn provide all of the necessary information that your application needs to connect to it. Your application can directly connect to the service instance, regardless of how or where the service is running.

Service brokers implementing the OSBAPI specification usually provide some of these lifecycle commands:

- **Provide a catalog of services that the service broker offers**      
  The service catalog describes all of the services that can be provisioned through the service broker, and each of these services is made up of one or more plans. These plans typically represent the costs and benefits for a given variant of the service. Many services use plans to “T-Shirt size” the service offering (such as small, medium, and large for example).
- **Provision new service instances**       
  A service instance is a provisioned instance of a service and plan as described in the service brokers catalog. This could be anything, a database, a message queue, or a configuration server.
- **Bind those service instances to applications**      
  After a service instance is provisioned, you will want your application to connect to that instance. Such a service binding is done by returning all the necessary information back to your application that is required to be able to connect to and consume the service instance.
- **Deprovision service instances**     
  The service broker can delete and remove all the resources created upon initial provisioning of the service instance.

 
## What is Kubernetes Service Catalog?

As the OSBAPI specification is a platform agnostic way of delivering services it has also been adopted by the Kubernetes ecosystem via the Service Catalog project. [Service Catalog](https://svc-cat.io/) is a Kubernetes component that lets you provision services provided by OSBAPI compliant service brokers directly from the comfort of native Kubernetes tooling, just as you would in Cloud Foundry over the service marketplace. Service Catalog integrates the OSBAPI, letting you connect service brokers for any service providers to your Kubernetes cluster. Using Service Catalog, a Kubernetes cluster operator can browse the list of managed services offered by the service broker, provision instances of managed services, and bind them to make them available to applications running inside the cluster.

Review the Kubernetes [documentation on Service Catalog](https://kubernetes.io/docs/concepts/extend-kubernetes/service-catalog/) for further information on getting it up and running on your cluster, and how the overall architecture and interactions with a service broker are implemented.

![SVC](/images/svc.png)
 
## Brokers a-plenty

There is a multitude of service brokers already out there for a wide array of different types of services, all implementing the OSBAPI specification to make these services consumable by Cloud Foundry or Kubernetes. Through the OSBAPI specification it is possible to extend your service marketplace inside the Swisscom Application Cloud to any number of additional third-party service offerings.

Have a look at some of these examples:
- **Open Service Broker for Azure**     
  OSBA lets you provision Azure Cloud Services directly from Kubernetes or Cloud Foundry        
  https://osba.sh/
- **AWS Service Broker**        
  Allows native AWS services to be exposed directly through Cloud Foundry and Kubernetes        
  https://aws.amazon.com/partners/servicebroker/
- **ElephantSQL Broker** 🐘     
  A service broker for provisioning PostgreSQL databases on AWS, Azure or GCP via ElephantSQL managed PostgreSQL-as-a-Service       
  https://github.com/JamesClonk/elephantsql-broker
- **GCP Service Broker**        
  A service broker for Google Cloud Platform, to be used with Cloud Foundry and Kubernetes      
  https://github.com/GoogleCloudPlatform/gcp-service-broker
- **Compose.io Broker**     
  A service broker for Cloud Foundry and Kubernetes, provisioning managed services such as Redis, PostgreSQL, MySQL, Etcd, Elasticsearch, RethinkDB, ScyllaDB, etc.     
  https://github.com/JamesClonk/compose-broker
- **Kubernetes Minibroker**     
  A service broker that provisions services via Helm Charts on your Minikube Kubernetes cluster, supporting PostgreSQL, MySQL and MongoDB       
  https://github.com/kubernetes-sigs/minibroker

In particular the AWS, Azure and GCP service brokers immediately open up a huge array of databases and services to your platform, giving your developers a big toolbox to work with when developing new applications. ?️

 
## Using a custom service broker in Cloud Foundry

Lets take a closer look at the above mentioned *compose-broker* and *elephantsql-broker*, two very similar community written third-party service brokers for managing these public Database-as-a-Service offerings in your platform:
- **[Compose.io](https://compose.io/)**  
  offers developers hosting for managed databases, such as Redis, PostgreSQL, MySQL, Etcd, Elasticsearch, RethinkDB, ScyllaDB, RabbitMQ, etc.
- **[ElephantSQL](https://www.elephantsql.com/)**   
  offers fully managed and highly available PostgreSQL databases as a service on any AWS, Azure or GCP datacenter of your choice.

### The service catalog

Both of these service brokers come with a `catalog.yml` configuration file included, that specifies all their whole service catalog and lists all their service offerings and plans that they can integrate into the cf marketplace. You can freely modify these to adjust what service offerings you plan on using. Lets have a quick look at the elephantsql-broker's catalog:
https://github.com/JamesClonk/elephantsql-broker/blob/v1.0.1/catalog.yml
```yaml
services:
- id: 8ff5d1c8-c6eb-4f04-928c-6a422e0ea330
  name: elephantsql
  description: PostgreSQL as a Service
  bindable: true
```

The main catalog element is an array of [service offerings](https://github.com/openservicebrokerapi/servicebroker/blob/v2.15/spec.md#service-offering-object), with each element having an ID, name and various other properties as described in the OSBAPI spec.
A service offering also contains one or more [service plans](https://github.com/openservicebrokerapi/servicebroker/blob/v2.15/spec.md#service-plan-object). In our case there is only one service offering which contains a list of all plans, with each of them representing and corresponding directly to a database instance plan from [ElephantSQL.com/plans](https://www.elephantsql.com/plans.html), for example:
```yaml
plans:
- id: 6203b8e7-9ef4-44ef-bb0b-48b50409794d
  name: spider
  description: Simple Spider - shared instance
  free: false
  bindable: true
  metadata:
    displayName: Simple Spider
    imageUrl: https://www.elephantsql.com/images/spider_256.png
    costs:
    - amount:
        usd: 5.0
      unit: Monthly
    bullets:
    - Shared high performance server
    - 500 MB data
    - 10 concurrent connections
    dedicatedService: false
    highAvailability: false
```
 
### Deploying the service broker to Cloud Foundry

First you are going to need an account on one of these service providers you intend to use. For example for ElephantSQL you can just hop over to their [login page](https://customer.elephantsql.com/login) and sign-in with your GitHub account. Next you will need to create an API key that service broker can use for direct API access to provision and manage database instances. Create a new [API key](https://customer.elephantsql.com/apikeys) now and keep it for later.

In order to deploy the service broker onto the Swisscom Application Cloud then open and modify the included [manifest.yml](https://github.com/JamesClonk/elephantsql-broker/blob/v1.0.1/manifest.yml) to your liking and run `cf push`. You can either add the previously mentioned API key directly to your `manifest.yml`, or provide it via the cf-cli during pushing.

Deployment of these service brokers works just like any other app on Cloud Foundry:

![Deployment](/images/setup-min.gif)

Once the service broker application has been deployed you have to register it with Cloud Foundry. You do this by running the `cf create-service-broker` command, by giving it the `--space-scoped` flag. This will register the service broker for your current space and its services will be available from the marketplace when in that space. If you are not an administrator of your Cloud Foundry platform then all you can do is register space-scoped service brokers, but if by chance you are in fact an admin or know the admins then you could also [enable-service-access](https://docs.cloudfoundry.org/services/access-control.html#enable-access) or register the service broker globally to make its services available to specific orgs or even platform-wide to anyone.

Have a look at the documentation on [managing service brokers](https://docs.cloudfoundry.org/services/managing-service-brokers.html) on Cloud Foundry for further information on this topic.

 
### Provisioning new database services

Once the service broker has been registered on the Swisscom Application Cloud and its services are available to you in the marketplace, you can then proceed as if it were any other platform provided service and start to create, bind and consume service instances via `cf create-service` and `cf bind-service`:

![Provisioning](/images/provisioning-min.gif)

While looking at such a newly created service instance via `cf service <instance-name>` you will notice that it also displays a *dashboard* url. This will take you back to the admin dashboard of the service provider itself where you can inspect and also manage these database instances directly, in case of ElephantSQL for example it would allow you to manage backups, look at metrics, setup alarms, etc. Just be careful to not rename (or accidentally delete) them, as their GUID name is the reference for Cloud Foundry and the service broker to be able to identify them.

 
## Building your own

If you are interested in developing and providing your own service broker then you could also use one of the many already existing frameworks and libraries available out there to develop your own service broker in no time, instead of rolling your own implementation.

Here are a few example libraries:
- **Java**  
  The **Spring Cloud Open Service Broker** framework for building Spring Boot applications that implement the Open Service Broker API   
  https://spring.io/projects/spring-cloud-open-service-broker
- **Java / Groovy**     
  The **Swisscom Open Service Broker** enables platforms to provision and manage services, is built in a modular way, can be easily extended and host multiple services     
  https://github.com/swisscom/open-service-broker
- **Golang**  
  https://github.com/pmorie/osb-starter-pack  
  https://github.com/pivotal-cf/brokerapi
- **Python**  
  https://pypi.org/project/openbrokerapi/
- **.NET**  
  https://github.com/AXOOM/OpenServiceBroker

But even if you don't like to use one of these libraries, writing your own service broker should be a piece of cake given how simple the API specification actually is.

Happy brokering! 🥳
