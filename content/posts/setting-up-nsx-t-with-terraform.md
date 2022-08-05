---
title: "Setting up NSX-T Distributed Firewall with Terraform"
description: "How to setup NSX-T DFW rules with Terraform, the Infrastructure-as-Code way"
tags: [terraform,nsx-t,vmware,firewall]
author: Fabio Berchtold
date: 2022-07-31T12:33:24+02:00
draft: true
---

## NSX-T

// TODO: explain what is NSX-T/sdn here very briefly, mention DFW..
// TODO: https://docs.vmware.com/en/VMware-NSX-T-Data-Center/3.2/administration/GUID-6AB240DB-949C-4E95-A9A7-4AC6EF5E3036.html

## Infrastructure-as-Code (IaC)

[Infrastructure-as-Code](https://www.redhat.com/en/topics/automation/what-is-infrastructure-as-code-iac) is the process of defining, provisioning and managing infrastructure resources like VMs, networks, load-balancers, Kubernetes clusters, disks and storage, etc. through code, rather than manual work or interactive configuration tools.
With IaC you write configuration files, or code, that then can repeatably be run to create all your infrastructure resources in a 100% reproducible and idempotent way. These configuration files are usually also store in a version control repository, like git, and can then further be used to setup automated GitOps deployment pipelines that will update your infrastructure everytime there is a new commit or change in the configuration files. It is best practice to not _ever_ manually manage any infrastructure like for example VMs through any manual interaction or tampering with them in any way, all work should be done through the automated deployment and provisioning process only.

One of the most popular and commonly used tools for IaC is HashiCorp [Terraform](https://www.terraform.io/).

## Terraform

// TODO: quick explanation of what Terraform is/does, etc.. not too much, there's enough docs/posts out there already
// TODO: show quick example of using TF for provisioning SKS cluster
// TODO: also show quick example of using TF for helm deployment on SKS cluster

## Define your NSX-T DFW rules

Now let's go back to our NSX-T firewall rules we want to setup. For this we are going to use the [NSX-T provider plugin](https://github.com/vmware/terraform-provider-nsxt) for Terraform.

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
