---
title: "Using Knative Serving on Kubernetes"
description: "How to use Knative Serving for your applications"
tags: [kubernetes,knative,containers]
author: Fabio Berchtold
date: 2021-03-13T13:54:27
draft: false
---

## Serverless Computing?

We probably all heard of AWS Lambda, [Function-as-a-Service](https://en.wikipedia.org/wiki/Function_as_a_service) (FaaS) or [Serverless Computing](https://en.wikipedia.org/wiki/Serverless_computing) in general before. And while I find the term "serverless" rather silly, its actual meaning of executing compute processes or containers only on-demand in the cloud and allow for a simplified, no capacity planning required, pay-only-what-you-use model of running your applications or code is not to be easily dismissed and can be quite valuable.

Since allowing yourself to be captured and locked  into any particular vendor, escpecially like going for AWS Lambda, is a big mistake however, what options are there if we want to avoid such folly? Are there any self-hosted serverless computing or Function-as-a-Service solutions out there?

Well yes, of course there are! 😄

The two most well known in this area are:
- [OpenFaaS](https://www.openfaas.com/)
- [Knative](https://knative.dev)

Both are open source projects, can provide you with event-driven Function-as-a-Service and Serverless Computing functionality, are installed on top of Kubernetes, and allow you to build, deploy and manage modern cloud-native serverless workloads.

I highly recommend you to check out at least one (if not both) of these two, install them in a playground environment and tinker a bit with them to learn about their use cases. Both are relatively easy to install on Kubernetes and have extensive documentation to get you started.

OpenFaaS is mainly focused on providing you with the event-driven Function-as-a-Service experience, and requires you to adapt your code specifically to use it. It is directly comparable to AWS Lambda.

Knative on the other hand while providing the same event-driven concepts, also offers a more generalistic approach in running any code or containers on its platform, not just "functions". Thus it can be used in a more Platform-as-a-Service fashion and run your normal web applications too.

## Knative Serving

Knative itself is split up into major components or areas:
- [Knative Serving](https://knative.dev/docs/serving/)
- [Knative Eventing](https://knative.dev/docs/eventing/)

Knative Eventing is the more Function-as-a-Service oriented side of Knative. It provides you with a collection of APIs that enable you to use an event-driven architecture with your applications.

But for this blog post lets have a closer look at Knative Serving, the more traditional PaaS-like parts of Knative.

With the components it provides you are able to easily deploy your application containers, have autoscaling for them from zero to many instances on-demand, integrate with various networking layers such as Contour or Istio and have automatic "route" creation and management, and you can even rollback your deployed applications to previous revisions and do A/B testing easily via customized routing.

### Knative Serving resources

From https://knative.dev/docs/serving/#serving-resources
> *Knative Serving defines a set of objects as Kubernetes Custom Resource Definitions (CRDs). These objects are used to define and control how your serverless workload behaves on the cluster:*

>   - [**Service**](): The `service.serving.knative.dev` resource automatically manages the whole lifecycle of your workload. It controls the creation of other objects to ensure that your app has a route, a configuration, and a new revision for each update of the service. Service can be defined to always route traffic to the latest revision or to a pinned revision.
>   - [**Route**](): The `route.serving.knative.dev` resource maps a network endpoint to one or more revisions. You can manage the traffic in several ways, including fractional traffic and named routes.
>   - [**Configuration**](): The `configuration.serving.knative.dev` resource maintains the desired state for your deployment. It provides a clean separation between code and configuration and follows the Twelve-Factor App methodology. Modifying a configuration creates a new revision.
>   - [**Revision**](https://github.com/knative/specs/blob/main/specs/serving/knative-api-specification-1.0.md#revision): The `revision.serving.knative.dev` resource is a point-in-time snapshot of the code and configuration for each modification made to the workload. Revisions are immutable objects and can be retained for as long as useful. Knative Serving Revisions can be automatically scaled up and down according to incoming traffic.

![Diagram that displays how the Serving resources coordinate with each other.](https://github.com/knative/serving/raw/main/docs/spec/images/object_model.png)

### Installation

For installing Knative on your Kubernetes cluster you can follow the ["Installing Knative Serving using YAML files"](https://knative.dev/docs/install/yaml-install/serving/install-serving-with-yaml/) guide. You will need to install the CRDs, the core of Knative Serving itself, and an appropriate networking and routing layer for your cluster (Kourier, Istio or Contour). Once that's done you will also have to configure DNS entries under which domain name Knative Serving will automatically manage and provide routes for your applications. If you follow the guide closely the installation shouldn't prove too difficult.

Just make sure you don't forget about the DNS configuration step, its important to get automatic route management working correctly.

Another possibility to install and play around with Knative Serving would be to use the [Quickstart guide](https://knative.dev/docs/install/quickstart-install/). For this all you need is the Knative CLI and a local [kind](https://kind.sigs.k8s.io/) cluster. It's perfect for getting your feet wet and experimenting with Knative before installing it on a production Kubernetes cluster.

### Deploy a web app

Deploying your first web application with it once you have Knative Serving up and running is super easy. If you are using the [Knative CLI](https://knative.dev/docs/client/install-kn/), all you need to do is run one simple command:

```bash
$ kn service create my-first-app --image gcr.io/knative-samples/helloworld-go -n default
```

We can also list all running Knative Serving applications with the CLI:

```bash
$ kn service list

NAME           URL                                          LATEST               AGE     CONDITIONS   READY   REASON
my-first-app   http://my-first-app.default.my-domain.com    my-first-app-00001   1m39s   3 OK / 3     True
```

As you can see, the web app container is up and running. Knative also automatically assigned it a public route, `http://my-first-app.default.my-domain.com`, based on the app name and namespace it is located, combined with the aforementioned domain name you configured in your DNS entries.

Of course you don't have to use the Knative CLI if you don't want to. Here's an example of a full yaml manifest for deploying an application:

```yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: hello-world
  namespace: demo
spec:
  template:
    spec:
      containers:
      - image: gcr.io/knative-samples/helloworld-go
        ports:
        - containerPort: 8080
        env:
        - name: TARGET
          value: "World"
```

A quick `kubectl -n demo apply -f <filename>.yaml` and this is the result:

```bash
$ kn -n demo service list

NAME          URL                                      LATEST              AGE   CONDITIONS   READY   REASON
hello-world   https://hello-world.demo.my-domain.com   hello-world-00001   12m   3 OK / 3     True
```

### Autoscaling

One of the many other benefits Knative Serving provides is the on-demand "serverless" nature of these containers it manages for you. You can provide Knative with additional autoscaling parameters, fine-tuning how it should automatically scale-up and down the number of container instances for your applications:

```yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: autoscaling-demo
  namespace: demo
spec:
  template:
    metadata:
      annotations:
        # Initial target scale immediately after app is created
        autoscaling.knative.dev/initialScale: "3"
        # Disable scale to zero with a minScale of 1+
        autoscaling.knative.dev/minScale: "0"
        # Limit scaling maximum to 10 pods
        autoscaling.knative.dev/maxScale: "5"
        # Time window which must pass before a scale-down decision is applied
        autoscaling.knative.dev/scaleDownDelay: "10m"
        # Target 15 requests in-flight per pod
        autoscaling.knative.dev/target: "15"
    spec:
      containers:
      - image: gcr.io/knative-samples/helloworld-go
        env:
        - name: TARGET
          value: "World!"
```

See the [Autoscaling](https://knative.dev/docs/serving/autoscaling/) documentation for detailed information on these and many more additional annotations controlling the autoscaling behaviour of your applications.

Let's quickly cleanup after we are done with our demo:

```bash
$ kn service delete hello-world

Service 'hello-world' successfully deleted in namespace 'demo'.

$ kn service list hello-world

No services found.
```

Easy, isn't it? 😉

Check out the provided [code samples](https://knative.dev/docs/samples/serving/) from the documentation to learn more about using Knative Serving.
