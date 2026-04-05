---
title: "Template rendering and secrets management with Plato"
description: "Plato is a template renderer with automatic SOPS secret injection, written in Golang"
tags: [golang,sops,secrets,kubernetes,github,continuous deployment,k3s,hetzner,templating]
author: Fabio Berchtold
date: 2025-11-23T16:49:00
draft: false
---

## The problem with secrets

If you've been following my blog you might have noticed a recurring theme throughout my posts, and that is I'm obsessed with automation and keeping everything as code in git repositories. My entire [Kubernetes infrastructure](/posts/my-own-kubernetes/) is defined in code, deployed automatically via GitHub Actions, and reproducible from scratch.

But there's always been one annoying thorn in my side: **secrets**. 😤

I wrote about [using Mozilla/SOPS for secret management](/posts/encrypt-secrets-with-sops/) a while back, and while SOPS itself is a fantastic tool for encrypting secrets so they can safely live in a git repository, the way I was *using* those secrets in my deployment pipelines was... let's just say it was not pretty.

It looked something like this:
```shell
export HETZNER_CLOUD_TOKEN=$(sops -d "secrets.yaml" | yq -e eval '.secrets.hetzner.token' -)
export HETZNER_PUBLIC_SSH_KEY=$(sops -d "secrets.yaml" | yq -e eval '.secrets.hetzner.ssh.public_key' -)
export HETZNER_PRIVATE_SSH_KEY=$(sops -d "secrets.yaml" | yq -e eval '.secrets.hetzner.ssh.private_key' -)
export POSTGRES_PASSWORD=$(sops -d "secrets.yaml" | yq -e eval '.secrets.postgres.password' -)
export GRAFANA_PASSWORD=$(sops -d "secrets.yaml" | yq -e eval '.secrets.grafana.password' -)
# ... and on and on and on ...
```

Every single secret had to be individually extracted from the SOPS-encrypted file, exported as an environment variable, and then somehow injected into whatever configuration file or deployment manifest needed it. As the number of secrets grew, so did this monstrosity of shell scripting. And don't even get me started on the `sed` and `envsubst` gymnastics needed to actually get those values into template files.

I also had to deal with multiple different templating systems at the same time. [ytt](https://carvel.dev/ytt/) uses `#@` annotations, [Helm](https://helm.sh/) uses `{{ }}` Go template delimiters, Ruby ERB uses `<%= %>`, and if I wanted to do my own templating on top of that... well, delimiter conflicts everywhere!

There had to be a better way.

## Enter Plato

So naturally I did what any reasonable engineer would do. Why of course, I wrote my own tool! 😂

[**Plato**](https://github.com/JamesClonk/plato) is a CLI template renderer with automatic SOPS secret injection, written in Golang. It takes template files, decrypts your SOPS-encrypted secrets, merges everything together and renders the output. As simple as that.

The core idea is straightforward:
1. You have a `plato.yaml` configuration file with all your non-secret data
2. You have a `secrets.yaml` file encrypted with SOPS containing all your secrets
3. You have template files that reference values from both of these
4. Plato renders those templates with all values merged and injected, secrets decrypted on-the-fly

No more shell scripting shenanigans, no more `sops -d | yq eval` chains, no more `envsubst` madness. Just clean templates and a single command!

### Why "Plato"?

No deep philosophical reason, I just thought it was a fun name. Though if you want to get fancy about it, Plato was all about the world of ideal "Forms" behind the messy reality we see, and that is kind of what a template renderer does, isn't it? Taking an ideal template form and rendering it into messy reality with all the actual values filled in.

That, and besides tem*plate* and *plato* are similar-ish looking. 🤣

## How does it work?

Plato is built around two main files in your project:

#### plato.yaml
This is your main configuration file. It contains all non-secret configuration data, plus some Plato-specific settings:
```yaml
---
plato:
  log_level: debug
  source: templates    # where your template files live
  target: rendered     # where rendered output goes
  secrets: rendered/secrets  # where generated secrets end up

# everything below is your actual payload data, available in templates
environment:
  domain: jamesclonk.io
  ip: 178.104.49.223

hetzner:
  node:
    name: kubernetes
    type: cpx32
    image: ubuntu-24.04
    location: nbg1

k3s:
  version: "v1.34.5+k3s1"

postgres:
  backup:
    schedule: "55 5 * * *"
    s3:
      enabled: true
```

#### secrets.yaml
This encrypted file contains all your secrets, encrypted via SOPS using whatever backend you prefer (*age*, *AWS KMS*, *Vault*, etc.). Though I greatly prefer [age](https://github.com/filosottile/age) to be independent of other systems:
```yaml
# this is what a SOPS-encrypted yaml file looks like
hetzner:
    token: ENC[AES256_GCM,data:J3WHN2aAvIedB2Ogga6qhGA=,iv:CRqk4amBxFf...,tag:MLI3Oa...,type:str]
ssh:
    private_key: ENC[AES256_GCM,data:GrugSAh4v5deSWlKNP/idFlTC8P6CQv7...,type:str]
    public_key: ENC[AES256_GCM,data:x074coIv5IegZm/sRuOkW6i6RX2ILQ==...,type:str]
postgres:
    password: ENC[AES256_GCM,data:Jff24GBDKXpNVEKVdfcKwuTKEV62odfgzlQDg==...,type:str]
grafana:
    password: ENC[AES256_GCM,data:6hasd6if9ON1aVL456k=...,type:str]
sops:
    age:
    - recipient: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
      enc: |
        -----BEGIN AGE ENCRYPTED FILE-----
        ...
        -----END AGE ENCRYPTED FILE-----
```

This file can be safely committed to a public git repository. Nobody can read your secrets without the decryption key.

Plato reads both files, decrypts the secrets via SOPS on-the-fly, merges everything into one big configuration tree, and makes it all available as payload to your templates.

#### Triple-brace delimiters

One small workaround I had to do for Plato was the use of *triple-brace delimiters*: `{{{ }}}` instead of the standard Go template `{{ }}`.

Why? Because if you're working with Kubernetes you're almost certainly also dealing with Helm charts (`{{ .Values.something }}`), ytt templates, or other Go template based tools. Having Plato use the same delimiters would cause absolute chaos. Triple-braces avoid any conflicts and make it immediately obvious which parts of a file are Plato templates vs. Helm or ytt.

## Usage examples

### Rendering a single template via stdin/stdout

The simplest possible use case. Pipe a template in, get the rendered result out:
```shell
$ echo '{{{ .ssh.public_key -}}}' | plato template
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMmROMaltL5DRYCYNHW9BE2BTZWUqZ3dISyzZopyrRjg kubernetes
```

Plato automatically found the `plato.yaml` and `secrets.yaml` in the current directory (or traversed upwards to find them, just like git does), decrypted the secrets, and rendered the template. One command, done. 😄

### Rendering a template file to stdout

```shell
$ cat templates/kubeconfig.yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: {{{ .kubernetes.server }}}
  name: kubernetes
users:
- name: admin
  user:
    token: {{{ .kubernetes.token }}}

$ plato template templates/kubeconfig.yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: https://10.8.0.2:6443
  name: kubernetes
users:
- name: admin
  user:
    token: eyJhbGciOiJSUzI1NiIs...
```

### Rendering a template file to an output file

```shell
$ plato template templates/kubeconfig.yaml rendered/kubeconfig.yaml
```

### Batch rendering an entire directory

This is where Plato really shines. Point it at a directory full of templates and it renders them all:
```shell
$ plato render
```

That's it. Plato walks through everything under `plato.source` (default: `templates/`), renders each file with the full configuration and secrets payload, and writes the output to `plato.target` (default: `rendered/`). Directory structure is preserved.

## Advanced features

### Custom template functions

Plato includes all [Sprig](https://masterminds.github.io/sprig/) template functions (the same ones Helm uses), plus several custom ones that I found myself needing over and over:

```yaml
# Generate a bcrypt htpasswd entry
auth: "{{{ HtpasswdBcrypt .ingress.username .ingress.password }}}"

# Calculate an IP from a CIDR range
gateway_ip: "{{{ IPofCIDR .network.cidr 1 }}}"

# Generate a SHA-512 hashed password (for Linux /etc/shadow)
password_hash: "{{{ MKPasswd .node.password }}}"

# Render a nested object as indented YAML
config: |
{{{ ToYAML .prometheus.config 4 }}}

# Semver version checks for conditional logic
{{{ if SemverCheck .k3s.version ">= 1.30.0" "K3s 1.30+ detected, using new API" -}}}
apiVersion: gateway.networking.k8s.io/v1
{{{ else -}}}
apiVersion: networking.k8s.io/v1beta1
{{{ end -}}}
```

### Automatic SOPS file decryption

Any file in your templates directory with a `.sops_enc` extension will be automatically decrypted during rendering. This is perfect for files that need to be encrypted at rest in git but decrypted for deployment, like TLS certificates or kubeconfig files:

```
templates/
├── cert-manager/
│   ├── deploy.sh
│   └── cluster-issuer.yaml
├── hetzner-k3s/
│   ├── deploy.sh
│   └── wireguard.conf.sops_enc    ← this gets decrypted automatically!
└── postgres/
    └── deploy.sh
```

After `plato render`:
```
rendered/
├── cert-manager/
│   ├── deploy.sh
│   └── cluster-issuer.yaml
├── hetzner-k3s/
│   ├── deploy.sh
│   └── wireguard.conf              ← decrypted, no .sops_enc extension
└── postgres/
    └── deploy.sh
```

### Symlink support

Sometimes you have files that change dynamically (like Terraform state files) and you don't want Plato to copy them, but rather create symlinks back to the originals. Just add a `.symlink` marker file next to them:

```
templates/terraform/
├── main.tf
├── terraform.tfstate          ← the actual state file
└── terraform.tfstate.symlink  ← marker: "create a symlink for this!"
```

After rendering, `rendered/terraform/terraform.tfstate` will be a symlink pointing back to the original. No unnecessary copies, no stale state. 😉

### Storing generated secrets back

A key feature that evolved back when I was dealing with Terraform state files (which I do not anymore, Terraform can go the way of the Dodo for all I care! 🤮). Plato can take generated secrets and store them back into your SOPS-encrypted `secrets.yaml`:

```shell
$ plato store-secrets
```

It reads files from the `plato.secrets` directory, and for each file it stores the content back into `secrets.yaml` using the filename as the YAML path. For example a file at `rendered/secrets/tls.key` gets stored as `["tls"]["key"]` in secrets.yaml.

It also re-encrypts any formerly `.sops_enc` files back to their original location, but only if the content has actually changed. This avoids unnecessary git noise from re-encryption producing different ciphertext each time.

## Real-world example: my Kubernetes infrastructure

The best way to see Plato in action is to look at how I use it for my own Kubernetes cluster: [k8s-infrastructure](https://github.com/JamesClonk/k8s-infrastructure)

This repository contains the entire infrastructure-as-code for my personal K3s cluster running on [Hetzner Cloud](https://www.hetzner.com/cloud). The whole thing is powered by Plato.

The structure looks like this:
```
k8s-infrastructure/
├── plato.yaml              ← all configuration (domain, IPs, K3s version, etc.)
├── secrets.yaml            ← SOPS-encrypted secrets
├── .sops.yaml              ← SOPS encryption config
├── templates/              ← source templates (plato.source)
│   ├── setup.sh            ← installs tools, sets up environment
│   ├── taskfile.yaml       ← orchestrates the entire deployment
│   ├── hetzner-k3s/        ← VM provisioning + K3s installation
│   ├── kube-system/        ← namespace customization
│   ├── envoy-gateway/      ← Gateway API routing (ingress)
│   ├── cert-manager/       ← Let's Encrypt certificates
│   ├── dex/                ← OAuth2/OIDC authentication
│   ├── headlamp/           ← Kubernetes dashboard
│   ├── postgres/           ← database + backups
│   ├── prometheus/         ← metrics + alerting
│   ├── loki/               ← log aggregation
│   ├── vector/             ← log forwarding
│   └── grafana/            ← dashboards
├── rendered/               ← output (gitignored)
└── taskfile.yaml           ← entry point
```

The deployment flow is:
1. Run `plato render`, all templates get rendered with config and secrets injected
2. Then run `task deploy` inside the rendered directory to deploy everything sequentially

Here's an example of what a template looks like in practice. This is from `templates/setup.sh`, the script that bootstraps the entire environment:

```shell
#!/bin/bash
# ...
export HCLOUD_TOKEN="{{{ .hetzner.token }}}"
export INGRESS_DOMAIN="{{{ .environment.domain }}}"

# write SSH key
cat >"$HOME/.ssh/id_rsa" <<'SSHKEY'
{{{ .ssh.private_key }}}
SSHKEY
chmod 600 "$HOME/.ssh/id_rsa"
```

No more `sops -d | yq eval` chains. No more environment variable explosion. The Hetzner Cloud token, the SSH private key, the domain name, etc.. They all come from the same merged config and secrets payload, referenced directly in the template.

And thanks to the triple-braces it also works like a charm in a Helm values file, for example:

```yaml
grafana:
  adminUser: admin
  adminPassword: "{{{ .grafana.password }}}"
  ingress:
    enabled: true
    hosts:
      - grafana.{{{ .environment.domain }}}
  datasources:
    datasources.yaml:
      datasources:
        - name: Prometheus
          url: http://prometheus-server.{{{ .prometheus.namespace }}}.svc.cluster.local
        - name: Loki
          url: http://loki.{{{ .loki.namespace }}}.svc.cluster.local:{{{ .loki.port }}}
```

After `plato render` this becomes a fully populated values file ready for Helm, with the actual password and domain injected. No Helm secrets plugin needed, no external secret operator, no vault sidecar. Just Plato doing its thing. 🥳

## Benefits

There are many benefits of using Plato, in particular:

- **Secrets stay encrypted in git**: The `secrets.yaml` file is SOPS-encrypted and safe to commit publicly. No more GitHub repository secrets sprawl, no more "where did I put that password again?"
- **Single source of truth**: All configuration and secrets in two files (`plato.yaml` + `secrets.yaml`), referenced everywhere via templates
- **No delimiter conflicts**: Triple-brace `{{{ }}}` plays nicely with Helm, ytt, and any other Go template based tooling
- **Full Sprig function library**: All the string manipulation, crypto, date, and other functions you know from Helm
- **Automatic SOPS decryption**: Both for the secrets.yaml payload and for individual `.sops_enc` files
- **Bidirectional secret flow**: Generate secrets during deployment, store them back encrypted with the `store-secrets` command
- **Simple and self-contained**: Single Go binary, no runtime dependencies (except `sops` itself for decryption)
- **Works with any backend**: age, AWS KMS, GCP KMS, Azure Key Vault, HashiCorp Vault, whatever SOPS supports, Plato supports it!

## Installation

Plato is distributed as a single binary. Grab the latest release from GitHub:

```shell
# download and extract
$ wget https://github.com/JamesClonk/plato/releases/download/v1.3.0/plato_1.3.0_linux_x86_64.tar.gz
$ tar -xvzf plato_1.3.0_linux_x86_64.tar.gz
$ chmod +x plato
$ mv plato /usr/local/bin/

# verify
$ plato version
```

Available for Linux and macOS. Sorry Windows users, but honestly if you're managing Kubernetes infrastructure from Windows you have bigger problems than not having Plato. 🤭

## Getting started

Here's the quickest way to get going:

1. Create a `plato.yaml` with your configuration
2. Create a `secrets.yaml` with your secrets, then encrypt it with SOPS: `sops -e -i secrets.yaml`
3. Create a `templates/` directory with your template files using `{{{ .path.to.value }}}` syntax
4. Run `plato render`
5. Find your rendered output in `rendered/`

That's all there is to it.

Check out the repository for more details and examples: [https://github.com/JamesClonk/plato](https://github.com/JamesClonk/plato)

And if you want to see a full real-world example of Plato powering an entire Kubernetes infrastructure, have a look at my Kubernetes IaC repo: [k8s-infrastructure](https://github.com/JamesClonk/k8s-infrastructure)

Happy templating! 🎉
