---
title: "Setting up NSX-T Distributed Firewall with Terraform"
description: "How to setup NSX-T DFW rules with Terraform, the Infrastructure-as-Code way"
tags: [terraform,nsx-t,vmware,firewall,kubernetes,exoscale]
author: Fabio Berchtold
date: 2022-07-31T12:33:24+02:00
draft: false
---

## NSX-T

> _[NSX-T](https://docs.vmware.com/en/VMware-NSX-T-Data-Center/) is a [software-defined networking](https://en.wikipedia.org/wiki/Software-defined_networking) (SDN) platform by VMware to build and connect environments together. It can be used for any cloud-native workload, bare metal or hypervisor, public, private or multi-cloud environments. It allows you to abstract your phyiscal network and to create and define networks for your workloads entirely in software._

One of the features in NSX-T is the so-called "[Distributed Firewall](https://docs.vmware.com/en/VMware-NSX-T-Data-Center/3.2/administration/GUID-6AB240DB-949C-4E95-A9A7-4AC6EF5E3036.html)" (DFW), with which you can configure firewall rules for all your east-west traffic inside an NSX-T network.

Now why is this so interesting? Well, because a few weeks ago I needed to create a bunch of DFW policies and rules in NSX-T, and was wondering about what would probably be the best approach to do that.

Trying to figure out the overly complicated NSX-T API to try and automate any such rule creation that way unfortunately only resulted in frustration and ultimately resignation. But I explicitly wanted to have everything automated, there's no way I'm going to manually maintain a set of firewall rules in a UI via _ClickOps_.

Hmm, what can we do?

## Infrastructure-as-Code (IaC)

[Infrastructure-as-Code](https://www.redhat.com/en/topics/automation/what-is-infrastructure-as-code-iac) is the process of defining, provisioning and managing infrastructure resources like VMs, networks, load-balancers, Kubernetes clusters, disks and storage, etc. through code, rather than manual work or interactive configuration tools.
With IaC you write configuration files, or code, that then can repeatably be run to create all your infrastructure resources in a 100% reproducible and idempotent way. These configuration files are usually also store in a version control repository, like git, and can then further be used to setup automated GitOps deployment pipelines that will update your infrastructure everytime there is a new commit or change in the configuration files. It is best practice to not _ever_ manually manage any infrastructure like for example VMs through any manual interaction or tampering with them in any way, all work should be done through the automated deployment and provisioning process only.

One of the most popular and commonly used tools for IaC is HashiCorp [Terraform](https://www.terraform.io/).

## Terraform

[Terraform](https://www.terraform.io/) is (arguably) the most popular open-source Infrastructure-as-Code tool out there. It allows to easily define, provision and manage your entire infrastructure using a declarative configuration language. It works out-of-the-box with most of the well-known infrastructure provider like GCP, AWS, Azure, etc. and all of their services.

Terraform functionality and support for different infrastructure platforms and resources can also easily be extended by installing additional Terraform [provider plugins](https://www.terraform.io/language/providers).

Here's a quick example of using the [Exoscale provider plugin](https://registry.terraform.io/providers/exoscale/exoscale/latest), to provision and manage an entire Kubernetes cluster on [Exoscale](https://www.exoscale.com/):

```terraform
########################################################################################################################
# Exoscale Terraform provider plugin
########################################################################################################################
terraform {
  required_providers {
    exoscale = {
      source  = "exoscale/exoscale"
      version = "~> 0.40.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "exoscale" {
  key    = "EXOcbdef9755bd4fce8bfc5e2a5"
  secret = "xFh2vZcXyASGuZ-rEW272hiz-b8Xu75DLH5ef7Y2MhB"
}

########################################################################################################################
# Security groups
########################################################################################################################
data "exoscale_security_group" "default" {
  name = "default"
}

resource "exoscale_security_group" "sks_security_group" {
  name = "sks-k8s-security-group"
}

resource "exoscale_security_group_rule" "kubelet" {
  security_group_id      = exoscale_security_group.sks_security_group.id
  description            = "Kubelet"
  type                   = "INGRESS"
  protocol               = "TCP"
  start_port             = 10250
  end_port               = 10250
  user_security_group_id = exoscale_security_group.sks_security_group.id
}

resource "exoscale_security_group_rule" "calico_vxlan" {
  security_group_id      = exoscale_security_group.sks_security_group.id
  description            = "VXLAN (Calico)"
  type                   = "INGRESS"
  protocol               = "UDP"
  start_port             = 4789
  end_port               = 4789
  user_security_group_id = exoscale_security_group.sks_security_group.id
}

resource "exoscale_security_group_rule" "nodeport_tcp" {
  security_group_id = exoscale_security_group.sks_security_group.id
  description       = "Nodeport TCP services"
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 30000
  end_port          = 32767
  cidr              = "0.0.0.0/0"
}

resource "exoscale_security_group_rule" "nodeport_udp" {
  security_group_id = exoscale_security_group.sks_security_group.id
  description       = "Nodeport UDP services"
  type              = "INGRESS"
  protocol          = "UDP"
  start_port        = 30000
  end_port          = 32767
  cidr              = "0.0.0.0/0"
}

########################################################################################################################
# SKS cluster and nodepool
########################################################################################################################
resource "exoscale_sks_cluster" "sks_cluster" {
  zone           = "ch-dk-2"
  name           = "sks-k8s-cluster"
  description    = "An example Kubernetes cluster on Exoscale"
  auto_upgrade   = true
  metrics_server = true
  service_level  = "starter"
  version        = "1.23.9"
}

resource "exoscale_sks_nodepool" "sks_nodepool" {
  zone          = "ch-dk-2"
  cluster_id    = exoscale_sks_cluster.sks_cluster.id
  name          = "sks-k8s-nodepool"
  instance_type = "standard.medium"
  size          = 5
  security_group_ids = [
    data.exoscale_security_group.default.id,
    resource.exoscale_security_group.sks_security_group.id,
  ]
}

########################################################################################################################
# Kubeconfig
########################################################################################################################
resource "exoscale_sks_kubeconfig" "sks_kubeconfig" {
  cluster_id = exoscale_sks_cluster.sks_cluster.id
  zone       = exoscale_sks_cluster.sks_cluster.zone
  user       = "kubernetes-admin"
  groups     = ["system:masters"]
}

resource "local_sensitive_file" "sks_kubeconfig_file" {
  filename        = "sks_kubeconfig"
  content         = exoscale_sks_kubeconfig.sks_kubeconfig.kubeconfig
  file_permission = "0600"
}

########################################################################################################################
# Terraform outputs
########################################################################################################################
output "sks_cluster_endpoint" {
  value = exoscale_sks_cluster.sks_cluster.endpoint
}

output "sks_kubeconfig" {
  value = local_sensitive_file.sks_kubeconfig_file.filename
}

output "sks_connection" {
  value = format(
    "export KUBECONFIG=%s; kubectl cluster-info; kubectl get pods -A",
    local_sensitive_file.sks_kubeconfig_file.filename,
  )
}
```

The above Terraform configuration specifies a security group for K8s, a K8s cluster / management plane, a K8s node pool and the kubeconfig file for accessing the cluster.

All of this will be provisioned on Exoscale by simply running `terraform apply`:

```bash
$ terraform apply
data.exoscale_security_group.default: Reading...
data.exoscale_security_group.default: Read complete after 0s [id=91772b4d-a404-4717-8fa4-a82dc4060b38]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

... # terraform plan preview here, lots of output

Plan: 9 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + sks_cluster_endpoint = (known after apply)
  + sks_connection       = "export KUBECONFIG=sks_kubeconfig; kubectl cluster-info; kubectl get pods -A"
  + sks_kubeconfig       = "sks_kubeconfig"

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

exoscale_security_group.sks_security_group: Creating...
exoscale_sks_cluster.sks_cluster: Creating...
exoscale_security_group.sks_security_group: Creation complete after 3s [id=bf6c5ebf-1091-4ca9-a427-034ccfbdae8a]
exoscale_security_group_rule.nodeport_udp: Creating...
exoscale_security_group_rule.nodeport_tcp: Creating...
exoscale_security_group_rule.kubelet: Creating...
exoscale_security_group_rule.calico_vxlan: Creating...
exoscale_security_group_rule.nodeport_udp: Creation complete after 4s [id=f90b6619-4559-4cc9-9d0d-91d071397501]
exoscale_security_group_rule.nodeport_tcp: Creation complete after 4s [id=23a1293b-1a2b-4b6f-8d57-46d089e61f27]
exoscale_security_group_rule.calico_vxlan: Creation complete after 4s [id=863bb61e-7649-44d9-8ed3-b187ebadb424]
exoscale_security_group_rule.kubelet: Creation complete after 4s [id=e18cdcc8-2b67-4bb3-a6c9-8f29380acced]
exoscale_sks_cluster.sks_cluster: Creation complete after 1m37s [id=6a94074f-302c-446a-821e-9acfebf5d33b]
exoscale_sks_kubeconfig.sks_kubeconfig: Creating...
exoscale_sks_nodepool.sks_nodepool: Creating...
exoscale_sks_kubeconfig.sks_kubeconfig: Creation complete after 1s [id=115016320829257889883792189515326601296577323034:116838890743125145307630577456649047067124867913]
local_sensitive_file.sks_kubeconfig_file: Creating...
local_sensitive_file.sks_kubeconfig_file: Creation complete after 0s [id=becb4140b572bd2a622f02a116a3734921132e45]
exoscale_sks_nodepool.sks_nodepool: Creation complete after 7s [id=85a398c3-19f6-47d8-89cf-d8feab72828d]

Apply complete! Resources: 9 added, 0 changed, 0 destroyed.

Outputs:

sks_cluster_endpoint = "https://6a94074f-302c-446a-821e-9acfebf5d33b.sks-ch-dk-2.exo.io"
sks_connection = "export KUBECONFIG=sks_kubeconfig; kubectl cluster-info; kubectl get pods -A"
sks_kubeconfig = "sks_kubeconfig"
```

After `terraform apply` has finished it will print out the result and all of the defined `output`'s.

Let's quickly check to confirm our new Kubernetes cluster is up and running:
```bash
$ export KUBECONFIG=sks_kubeconfig; kubectl cluster-info; kubectl get pods -A
Kubernetes control plane is running at https://6a94074f-302c-446a-821e-9acfebf5d33b.sks-ch-dk-2.exo.io:443
CoreDNS is running at https://6a94074f-302c-446a-821e-9acfebf5d33b.sks-ch-dk-2.exo.io:443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
NAMESPACE     NAME                                      READY   STATUS    RESTARTS   AGE
kube-system   calico-kube-controllers-6b77fff45-hrn7h   1/1     Running   0          117s
kube-system   calico-node-hzthv                         1/1     Running   0          65s
kube-system   calico-node-ndvn4                         1/1     Running   0          64s
kube-system   calico-node-zgljr                         1/1     Running   0          57s
kube-system   coredns-7c85997-fbndk                     1/1     Running   0          113s
kube-system   coredns-7c85997-rd79q                     1/1     Running   0          113s
kube-system   konnectivity-agent-54dd7f4b98-8f2fd       1/1     Running   0          111s
kube-system   konnectivity-agent-54dd7f4b98-d26kx       1/1     Running   0          111s
kube-system   kube-proxy-9b9fl                          1/1     Running   0          64s
kube-system   kube-proxy-9dq54                          1/1     Running   0          65s
kube-system   kube-proxy-gdft4                          1/1     Running   0          57s
kube-system   metrics-server-7bbd99559d-xlskh           0/1     Running   0          109s
```

It's like magic! 🥳

You can now even go a step further and also add Helm chart deployments to your Terraform configuration files, by courtesy of the Helm provider plugin: https://github.com/hashicorp/terraform-provider-helm

We could for example easily add and deploy the Ingress-NGINX controller too by adding this here to our configuration:

```terraform
provider "helm" {
  kubernetes {
    config_path = "./sks_kubeconfig"
  }
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress-controller"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx-ingress-controller"
  set {
    name  = "service.type"
    value = "ClusterIP"
  }
}
```

After running `terraform apply` again, we get this:

```bash
$ export KUBECONFIG=sks_kubeconfig; kubectl get pods -n default
NAME                                                        READY   STATUS    RESTARTS   AGE
nginx-ingress-controller-6b9cf4684f-dk6gc                   1/1     Running   0          96s
nginx-ingress-controller-default-backend-6798d86668-984dw   1/1     Running   0          96s
```

There are many more additional possibilities out there, for example using the [Carvel provider plugin](https://github.com/vmware-tanzu/terraform-provider-carvel) to use [ytt](https://carvel.dev/ytt) templates and deploy with [kapp](https://carvel.dev/kapp) instead of Helm.
But let's safe that for another time.

## Define your NSX-T DFW rules

Now let's go back to our NSX-T firewall rules we want to setup after this small detour into the world of IaC and Terraform.

You might have already guessed it at this point, but there actually is a [NSX-T provider plugin](https://github.com/vmware/terraform-provider-nsxt) for Terraform, and obviously we are going to use it! 😁

The documentation of this plugin can be found here: [https://www.terraform.io/docs/providers/nsxt/](https://registry.terraform.io/providers/vmware/nsxt/latest/docs)

### Terraform configuration files
Let's start our Terraform project by defining what provider plugin we want to use and configure it accordingly.

#### provider.tf
```terraform
terraform {
  required_providers {
    nsxt = {
      source  = "vmware/nsxt"
      version = "~> 3.2.8"
    }
  }
  required_version = ">= 1.2.0"
}

provider "nsxt" {
  host                 = var.nsx_manager
  username             = var.nsx_username
  password             = var.nsx_password
  allow_unverified_ssl = true
  max_retries          = 5
  retry_min_delay      = 50
  retry_max_delay      = 2000
}
```

As you can see above we are referring to several variables and using them to configure the provider plugin's `host`, `username` and `password` parameter.

These and some more variables are defined within `variables.tf`.

#### variables.tf / terraform.tfvars
```terraform
variable "nsx_manager" {}
variable "nsx_username" {}
variable "nsx_password" {}
variable "nsx_policy_enabled" {
  default = true
}

variable "nsx_env_tag_scope" {
  default = "env"
}
variable "nsx_env" {}

variable "ipset_all_cidrs" {}
variable "ipset_k8s_node_cidrs" {}
variable "ipset_k8s_master_cidrs" {}
variable "ipset_bastionhost" {}
```

```terraform
nsx_manager        = "nsx-t.manager.domain"
nsx_username       = "my-username"
nsx_password       = "********"
nsx_policy_enabled = false

nsx_env = "k8s-dev"

ipset_all_cidrs        = ["10.8.5.0/24", "10.8.10.0/24", "10.8.11.0/24", "10.8.12.0/24"]
ipset_k8s_node_cidrs   = ["10.8.11.0/24", "10.8.12.0/24"]
ipset_k8s_master_cidrs = ["10.8.10.0/24"]
ipset_bastionhost      = ["10.8.5.10", "10.8.5.11"]
```

We use these variables to define all the network ranges and IPs we expect to play around with in the DFW policy and rules.

The next step is to configure the NSX-T policy groups as described in [https://registry.terraform.io/providers/vmware/nsxt/latest/docs/resources/policy_group](https://registry.terraform.io/providers/vmware/nsxt/latest/docs/resources/policy_group). For our example project we will need a group which encompasses all segments to use for targeting scope purposes, some CIDR groups for the various collection of VMs and their networks and finally a group for an example bastion host and its IP.

#### groups.tf
```terraform
resource "nsxt_policy_group" "all_segments" {
  display_name = "all_segments"
  description  = "All ${var.nsx_env} segments"
  tag {
    scope = var.nsx_env_tag_scope
    tag   = var.nsx_env
  }
  criteria {
    condition {
      member_type = "Segment"
      operator    = "EQUALS"
      key         = "Tag"
      value       = "${var.nsx_env_tag_scope}|${var.nsx_env}"
    }
  }
}

resource "nsxt_policy_group" "bastionhost" {
  display_name = "bastionhost"
  description  = "All bastionhost IPs"
  tag {
    scope = var.nsx_env_tag_scope
    tag   = var.nsx_env
  }
  criteria {
    ipaddress_expression {
      ip_addresses = var.ipset_bastionhost
    }
  }
}

resource "nsxt_policy_group" "all_cidrs" {
  display_name = "k8s_all_cidrs"
  description  = "All CIDRs"
  tag {
    scope = var.nsx_env_tag_scope
    tag   = var.nsx_env
  }
  criteria {
    ipaddress_expression {
      ip_addresses = var.ipset_all_cidrs
    }
  }
}

resource "nsxt_policy_group" "k8s_master_cidrs" {
  display_name = "k8s_master_cidrs"
  description  = "All K8s master CIDRs"
  tag {
    scope = var.nsx_env_tag_scope
    tag   = var.nsx_env
  }
  criteria {
    ipaddress_expression {
      ip_addresses = var.ipset_k8s_master_cidrs
    }
  }
}

resource "nsxt_policy_group" "k8s_node_cidrs" {
  display_name = "k8s_node_cidrs"
  description  = "All K8s nodes CIDRs"
  tag {
    scope = var.nsx_env_tag_scope
    tag   = var.nsx_env
  }
  criteria {
    ipaddress_expression {
      ip_addresses = var.ipset_k8s_node_cidrs
    }
  }
}
```

Finally we have all the bits and pieces together to write out the actual DFW firewall rules into a policy.

#### dfw_policy.tf
```terraform
data "nsxt_policy_service" "ssh" {
  display_name = "SSH"
}

resource "nsxt_policy_service" "k8s_api_server" {
  display_name = "k8s_api_server"
  tag {
    scope = var.nsx_env_tag_scope
    tag   = var.nsx_env
  }

  l4_port_set_entry {
    display_name      = "TCP"
    protocol          = "TCP"
    destination_ports = ["443", "6443"]
  }
}

resource "nsxt_policy_service" "k8s_kubelet_api" {
  display_name = "k8s_kubelet_api"
  tag {
    scope = var.nsx_env_tag_scope
    tag   = var.nsx_env
  }

  l4_port_set_entry {
    display_name      = "TCP"
    protocol          = "TCP"
    destination_ports = ["10250"]
  }
}

resource "nsxt_policy_security_policy" "k8s_policy" {
  display_name = "DFW_K8s_policy"
  description  = "DFW rules for ${var.nsx_env}"

  category   = "Application"
  locked     = false
  stateful   = true
  tcp_strict = false
  # scope      = [nsxt_policy_group.all_segments.path]
  tag {
    scope = var.nsx_env_tag_scope
    tag   = var.nsx_env
  }

  # allow SSH to bastion host
  rule {
    display_name = "allow_ssh_to_bastionhost"
    description  = "Allow SSH from Any to bastion host"

    destination_groups = [nsxt_policy_group.bastionhost.path]
    services           = [data.nsxt_policy_service.ssh.path]
    scope              = [nsxt_policy_group.all_segments.path]

    action   = "ALLOW"
    logged   = false
    disabled = !var.nsx_policy_enabled
  }

  # allow bastion host to do anything
  rule {
    display_name = "allow_bastionhost_to_any"
    description  = "Allow Any for ${var.nsx_env} bastion host"

    source_groups = [nsxt_policy_group.bastionhost.path]
    scope         = [nsxt_policy_group.all_segments.path]

    action   = "ALLOW"
    logged   = false
    disabled = !var.nsx_policy_enabled
  }

  # block any other SSH
  rule {
    display_name = "block_ssh_to_any"
    description  = "Block SSH to/from anything else"

    services = [data.nsxt_policy_service.ssh.path]
    scope    = [nsxt_policy_group.all_segments.path]

    action   = "DROP"
    logged   = false
    disabled = !var.nsx_policy_enabled
  }

  # allow ingress to k8s api-server
  rule {
    display_name = "allow_k8s_api_server"
    description  = "Allow Any for ${var.nsx_env} K8s API-server ports"

    destination_groups = [nsxt_policy_group.k8s_master_cidrs.path]
    services           = [nsxt_policy_service.k8s_api_server.path]
    scope              = [nsxt_policy_group.all_segments.path]

    action   = "ALLOW"
    logged   = false
    disabled = !var.nsx_policy_enabled
  }

  # allow k8s master to kubelet api
  rule {
    display_name = "allow_k8s_kubelets"
    description  = "Allow K8s master to Kubelet API ports"

    source_groups      = [nsxt_policy_group.k8s_master_cidrs.path]
    destination_groups = [nsxt_policy_group.k8s_node_cidrs.path]
    services           = [nsxt_policy_service.k8s_kubelet_api.path]
    scope              = [nsxt_policy_group.all_segments.path]

    action   = "ALLOW"
    logged   = false
    disabled = !var.nsx_policy_enabled
  }

  # block anything that was not yet explicitely allowed, for all CIDRs
  rule {
    display_name = "block_all_remaining"
    description  = "Block anything remaining for all ${var.nsx_env} CIDRs"

    source_groups      = [nsxt_policy_group.all_cidrs.path]
    destination_groups = [nsxt_policy_group.all_cidrs.path]
    scope              = [nsxt_policy_group.all_segments.path]

    action   = "DROP"
    logged   = false
    disabled = !var.nsx_policy_enabled
  }
}
```

Note: All of these rules and definitions shown above are just examples, they are not meant to be used on any actual environment and very likely are incomplete or do not work for your use-case at all. Don't blindly copy and paste this stuff. 😉

## Apply configuration to NSX-T

Now it's time to create some stuff on our infrastructure! 😎

#### terraform init

To create our new DFW policy we'll first have to initialize Terraform with `terraform init`. This will download the configured provider plugin and prepare everything to be used:

```bash
$ terraform init

Initializing the backend...

Initializing provider plugins...
- Finding vmware/nsxt versions matching "~> 3.2.8"...
- Installing vmware/nsxt v3.2.8...
- Installed vmware/nsxt v3.2.8 (signed by a HashiCorp partner, key ID 6B6B0F38607A2264)

...
Terraform has been successfully initialized!
...
```

#### terraform plan

Let's first have a look at what Terraform will do to our infrastructure.

We can do a "dry-run" first with `terraform plan`:

```bash
$ terraform plan
data.nsxt_policy_service.ssh: Reading...
data.nsxt_policy_service.ssh: Read complete after 2s [id=SSH]

Terraform used the selected providers to generate the following execution plan.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # nsxt_policy_group.all_cidrs will be created
  + resource "nsxt_policy_group" "all_cidrs" {
      + description  = "All CIDRs"
      + display_name = "k8s_all_cidrs"
      + domain       = "default"
      + id           = (known after apply)
      + nsx_id       = (known after apply)
      + path         = (known after apply)
      + revision     = (known after apply)

... # lots of output

  # nsxt_policy_security_policy.k8s_policy will be created
  + resource "nsxt_policy_security_policy" "k8s_policy" {
      + category        = "Application"
      + description     = "DFW rules for k8s-dev"
      + display_name    = "DFW_K8s_policy"
      + domain          = "default"
      + sequence_number = 0
      + stateful        = true
      + tcp_strict      = false

      + rule {
          + action                = "ALLOW"
          + description           = "Allow SSH from Any to bastion host"
          + destination_groups    = (known after apply)
          + destinations_excluded = false
          + direction             = "IN_OUT"
          + disabled              = true
          + display_name          = "allow_ssh_to_bastionhost"
          + ip_version            = "IPV4_IPV6"
          + logged                = false
          + nsx_id                = (known after apply)
          + revision              = (known after apply)
          + rule_id               = (known after apply)
          + scope                 = (known after apply)
          + sequence_number       = (known after apply)
          + services              = [
              + "/infra/services/SSH",
            ]
          + sources_excluded      = false
        }

... # lots of output

  # nsxt_policy_service.k8s_kubelet_api will be created
  + resource "nsxt_policy_service" "k8s_kubelet_api" {
      + display_name = "k8s_kubelet_api"
      + id           = (known after apply)
      + nsx_id       = (known after apply)
      + path         = (known after apply)
      + revision     = (known after apply)

      + l4_port_set_entry {
          + destination_ports = [
              + "10250",
            ]
          + display_name      = "TCP"
          + protocol          = "TCP"
          + source_ports      = []
        }

      + tag {
          + scope = "env"
          + tag   = "k8s-dev"
        }
    }

Plan: 8 to add, 0 to change, 0 to destroy.

────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
Note: You didn't use the -out option to save this plan, so Terraform can't guarantee to take exactly these actions
if you run "terraform apply" now.
```

Looking good so far! 👍️

#### terraform apply

Now we will use `terraform apply`. This will again show all the expected changes to our infrastructure first and then ask you to confirm with `yes`:

```bash
$ terraform apply
... # terraform plan preview here, lots of output

Plan: 8 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

nsxt_policy_group.all_segments: Creating...
nsxt_policy_service.k8s_api_server: Creating...
nsxt_policy_group.k8s_node_cidrs: Creating...
nsxt_policy_group.k8s_master_cidrs: Creating...
nsxt_policy_service.k8s_kubelet_api: Creating...
nsxt_policy_group.bastionhost: Creating...
nsxt_policy_group.all_cidrs: Creating...
nsxt_policy_service.k8s_kubelet_api: Creation complete after 0s [id=7ccc1b64-db72-4a69-b344-1e3d5b3a3963]
nsxt_policy_group.k8s_master_cidrs: Creation complete after 1s [id=45628ca7-1a87-4813-8f35-579257a3e417]
nsxt_policy_group.all_cidrs: Creation complete after 1s [id=bd45ecfc-1b48-48f2-b160-af02a185b4c6]
nsxt_policy_service.k8s_api_server: Creation complete after 1s [id=0f983f5d-5c60-4421-ae91-2d792cbf2b67]
nsxt_policy_group.all_segments: Creation complete after 1s [id=08a73c98-cb55-40f1-91a0-863cf26821b9]
nsxt_policy_group.k8s_node_cidrs: Creation complete after 1s [id=5dd6e26d-1cbc-4c83-bcf3-b2e2a47428cd]
nsxt_policy_group.bastionhost: Creation complete after 1s [id=a502410c-caa8-4893-a533-b95999d20fbb]
nsxt_policy_security_policy.k8s_policy: Creating...
nsxt_policy_security_policy.k8s_policy: Creation complete after 0s [id=e6ce6f27-3dc4-43ab-bf90-fd46681f4446]

Apply complete! Resources: 8 added, 0 changed, 0 destroyed.
```

### Result

Lets see have a look at what was created on NSX-T.

We can see all the inventory groups that have been created:
![NSX-T Security Groups](/images/nsx_t_groups.png)

And here's the DFW security policy, exactly as defined in our configuration files:
![NSX-T Security Policy](/images/nsx_t_dfw_rules.png)

### Cleanup

Since Terraform keeps track of all the state of your infrastructure it can also do the reverse and remove all of these resources again cleanly.

All you need to do is run `terraform destroy`, review what it will do carefully, and confirm by typing `yes`:

```bash
$ terraform destroy
data.nsxt_policy_service.ssh: Reading...
nsxt_policy_service.k8s_kubelet_api: Refreshing state... [id=7ccc1b64-db72-4a69-b344-1e3d5b3a3963]
nsxt_policy_group.k8s_node_cidrs: Refreshing state... [id=5dd6e26d-1cbc-4c83-bcf3-b2e2a47428cd]
nsxt_policy_group.bastionhost: Refreshing state... [id=a502410c-caa8-4893-a533-b95999d20fbb]
nsxt_policy_group.all_segments: Refreshing state... [id=08a73c98-cb55-40f1-91a0-863cf26821b9]
nsxt_policy_group.k8s_master_cidrs: Refreshing state... [id=45628ca7-1a87-4813-8f35-579257a3e417]
nsxt_policy_group.all_cidrs: Refreshing state... [id=bd45ecfc-1b48-48f2-b160-af02a185b4c6]
nsxt_policy_service.k8s_api_server: Refreshing state... [id=0f983f5d-5c60-4421-ae91-2d792cbf2b67]
data.nsxt_policy_service.ssh: Read complete after 2s [id=SSH]
nsxt_policy_security_policy.k8s_policy: Refreshing state... [id=e6ce6f27-3dc4-43ab-bf90-fd46681f4446]

... # terraform plan preview here, lots of output

Plan: 0 to add, 0 to change, 8 to destroy.

Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes

nsxt_policy_security_policy.k8s_policy: Destroying... [id=e6ce6f27-3dc4-43ab-bf90-fd46681f4446]
nsxt_policy_security_policy.k8s_policy: Destruction complete after 1s
nsxt_policy_group.all_segments: Destroying... [id=08a73c98-cb55-40f1-91a0-863cf26821b9]
nsxt_policy_group.bastionhost: Destroying... [id=a502410c-caa8-4893-a533-b95999d20fbb]
nsxt_policy_service.k8s_api_server: Destroying... [id=0f983f5d-5c60-4421-ae91-2d792cbf2b67]
nsxt_policy_group.k8s_node_cidrs: Destroying... [id=5dd6e26d-1cbc-4c83-bcf3-b2e2a47428cd]
nsxt_policy_group.k8s_master_cidrs: Destroying... [id=45628ca7-1a87-4813-8f35-579257a3e417]
nsxt_policy_service.k8s_kubelet_api: Destroying... [id=7ccc1b64-db72-4a69-b344-1e3d5b3a3963]
nsxt_policy_group.all_cidrs: Destroying... [id=bd45ecfc-1b48-48f2-b160-af02a185b4c6]
nsxt_policy_service.k8s_api_server: Destruction complete after 0s
nsxt_policy_group.k8s_node_cidrs: Destruction complete after 0s
nsxt_policy_service.k8s_kubelet_api: Destruction complete after 1s
nsxt_policy_group.all_cidrs: Destruction complete after 1s
nsxt_policy_group.all_segments: Destruction complete after 1s
nsxt_policy_group.k8s_master_cidrs: Destruction complete after 1s
nsxt_policy_group.bastionhost: Destruction complete after 1s

Destroy complete! Resources: 8 destroyed.
```

And there we go, all of our infrastructure was properly cleaned up.. 😃
