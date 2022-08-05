---
title: "IP-whitelisting with a Cloud Foundry Route-Service"
description: "Route-services allow you to apply transformation or preprocessing of HTTP requests before they reach a target application, with common examples of use cases being rate limiting, authentication and authorization, and caching services"
tags: [cloud foundry,app cloud,networking]
author: Fabio Berchtold
date: 2020-06-28T10:13:15+02:00
draft: false
---


As an app developer using the [Swisscom Application Cloud](developer.swisscom.com) (which is based on the open source platform-as-a-service "[Cloud Foundry](https://www.cloudfoundry.org/)") you might have run into the situation already where you'd want to stop your applications from being accessible to everybody. More specifically you want to restrict access to them only for certain IPs.

Luckily for you Cloud Foundry has a feature that can do exactly that (and much more!): **Route-Services**

## Route-Services?

Route-services allow you to apply transformation or preprocessing of HTTP requests before they reach a target application. Common use cases include rate limiting, authentication and authorization, and caching services. A route service may reject requests or, after some transformation, pass requests to your application. Route-services are a special kind of service that you can use to apply various transformations to requests by binding an applications route to a route-service instance. You can bind this service instance to your applications route, and then automatically all requests for that route are being preprocessed by the route-service instance.

## Deploy a Route-Service

Let's have a look and go through the example project here: https://github.com/swisscom/ip-whitelisting-route-service-demo-app

First clone the repository:
```shell
$ git clone https://github.com/swisscom/ip-whitelisting-route-service-demo-app.git
$ cd ip-whitelisting-route-service-demo-app
```

Then edit the IP whitelist configuration file and the manifest:
```shell
$ vim ip-whitelist.conf
$ vim manifest.yml
```
In the `ip-whitelist.conf` file you will have to add all individual IPs or whole IP ranges that you want to be able to access your applications from.
For the `manifest.yml` make sure to edit the preconfigured `route` to where you want your route-service app to be.

Let's push the route-service app now and then create an actual route-service via the [CF CLI](https://docs.cloudfoundry.org/cf-cli/getting-started.html):
```shell
$ cf push my-route-service-app -f manifest.yml
...

Instances starting...

name:              my-route-service-app
requested state:   started
routes:            my-route-service-app.scapp.swisscom.com
stack:             cflinuxfs3

type:            web
instances:       1/1
memory usage:    64M
start command:   ./bin/ip-whitelisting-route-service-demo-app
```
```shell
$ cf create-user-provided-service my-route-service -r https://my-route-service-app.scapp.swisscom.com
Creating user provided service my-route-service in org sandbox / space test as admin...
OK
```
We are creating a *user-provided* route-service here and specifying the route you configured in your `manifest.yml` with the `-r` flag, this will tell Cloud Foundry the URL to the route-service. See the [documention for route-services](https://docs.cloudfoundry.org/services/route-services.html#user-provided) for additional information.

Check to make sure the route-service is there:
```shell
$ cf service my-route-service
Showing info of service my-route-service in org sandbox / space test as admin...

name:                my-route-service
service:             user-provided
route service url:   https://my-route-service-app.scapp.swisscom.com

There are no bound apps for this service.
```

Now this where the magic happens. Where are going to bind the new route-service to our other apps that we want to protect:
```shell
$ cf bind-route-service scapp.swisscom.com my-route-service --hostname my-other-app
Binding route my-other-app.scapp.swisscom.com to service instance my-route-service in org sandbox / space test as admin...
OK
```

This will cause all traffic going through the route of `my-other-app.scapp.swisscom.com` to be intercepted and routed to be first processed by our route-service app.
See the [documention for route-service-bindings](https://docs.cloudfoundry.org/devguide/services/route-binding.html) for additional information.

Depending on whether or not you correctly added your own IP to `ip-whitelist.conf` you will now be able to access `my-other-app.scapp.swisscom.com`, or not anymore. Since all requests going to `my-other-app.scapp.swisscom.com` are first being rerouted to go through the bound route-service it is not possible anymore to access `my-other-app` without the ingress traffic getting past the route-service app.

## How do Route-Services work exactly?

The exact specification details you need to pay attention to when implementing a route-service can be found here:
https://docs.cloudfoundry.org/services/route-services.html#how-it-works

Basically the route-service app will receive proxied requests for the target applications, with the additional header `X-CF-Forwarded-Url` being added to the requests. This `X-CF-Forwarded-Url` header contains the originally requested URL.

The route-service app must then handle those requests by either:
- Accept the request by making a new request to the originally requested URL (`X-CF-Forwarded-Url`) and then respond to the originating requestor
- Reject the request by responding with a non 2xx HTTP status code

When forwarding a request to the originally requested URL, the route-service app must forward the `X-CF-Forwarded-Url`, `X-CF-Proxy-Signature` and `X-CF-Proxy-Metadata` headers along with the request or it will be rejected.

You can see an implementation of this in our example IP-whitelisting route-service from above: https://github.com/swisscom/ip-whitelisting-route-service-demo-app/blob/14d5074f940f93e342e330acee08fffb9411d50c/main.go#L75-L90
```go
	// X-CF-Forwarded-Url is required to determine the target of the request after it has been passed the route service
	// https://docs.cloudfoundry.org/services/route-services.html#headers
	targetURL := req.Header.Get("X-CF-Forwarded-Url")
	if len(targetURL) == 0 {
		rw.WriteHeader(http.StatusBadRequest)
		_,_ = rw.Write([]byte("Bad Request"))
		return
	}

	target, err := url.Parse(targetURL)
	...

	// setup a reverse proxy and forward the original request to the target
	proxy := httputil.NewSingleHostReverseProxy(target)
```

---

### Video demonstration!

If you want to see another example of route-services in action then check out this video:
{{< youtube VaaZJE2E4jI >}}
