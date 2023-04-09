---
title: "Using Mozilla/SOPS for secret management"
description: "Learn how to encrypt your secrets with Mozilla/SOPS"
tags: [continuous deployment,github actions,secrets,github]
author: Fabio Berchtold
date: 2021-07-25T19:51:09
draft: false
---

## Environment variables

When I was originally contemplating on how to run all my personal projects and applications on [my own Kubernetes](/posts/my-own-kubernetes/) cluster, one of the problems was how would I store secrets? Where would I store them?

Since I intended to have all my [Infrastructure-as-Code](https://www.youtube.com/watch?v=RO7VcUAsf-I), deployment and application repositories publicly accessible on GitHub (to be able to benefit from all the nice free services it provides for public / open-source projects), I needed to figure out how I should do this.

Initially I went for the simple and obvious way of having all my pipeline code relying on injected environment variables, a typical principle of the [12-factor](https://12factor.net/config) approach on how to store configuration data.

Since at that point I was also migrating from [CircleCI](https://circleci.com/) to [GitHub Actions](https://docs.github.com/en/actions), all I had to do was store all needed environment variables as "Secrets" on the particular Github repository where the Github Actions workflows are running:

![GitHub secrets](/images/sops-github-secrets.png)

Now I could simply inject them as environment variables into a workflow and its job steps, by referring to these GitHub repository secrets via *`${{ .secret.<SECRET_NAME> }}`*:

```yaml
name: minecraft server on k8s

jobs:
  minecraft:
    name: minecraft
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: deploy minecraft server to k8s
      working-directory: minecraft
      run: ./deploy.sh
      env:
        KUBECONFIG: ${{ secrets.KUBECONFIG }}
        MINECRAFT_SERVER_PASSWORD: ${{ secrets.MINECRAFT_SERVER_PASSWORD }}
        MINECRAFT_RCON_PASSWORD: ${{ secrets.MINECRAFT_RCON_PASSWORD }}
        S3_BACKUP_BUCKET: ${{ secrets.S3_BACKUP_BUCKET }}
        S3_BACKUP_ACCESS_KEY: ${{ secrets.S3_BACKUP_ACCESS_KEY }}
        S3_BACKUP_SECRET_KEY: ${{ secrets.S3_BACKUP_SECRET_KEY }}
```

Great, this works reasonably well!

#### Could it be better though?

While I always felt a bit uneasy about storing these raw secrets on GitHub, I was never bothered enough by it to seek out better solutions. What was however starting to bother me was that after a while this collection of GitHub repo secrets started to grow more and more. As I added more applications to my infrastructure-as-code monorepo and its number of deployment workflows grew, so did the number of secrets I had to configure and store.

How else could I store secrets and the configuration data necessary for my workflows? This is where I learned about [Mozilla/SOPS](https://github.com/mozilla/sops)

## Mozilla/SOPS

SOPS, short for **S**ecrets **OP**eration**S**, is a tool to encrypt files so that they can safely be stored in public git repositories. It natively supports *YAML*, *JSON*, *ENV*, *INI* and *BINARY* file formats and encrypts these either via [AWS KMS](https://aws.amazon.com/kms/), GCP KMS, Azure Key Vault, age, and/or PGP.

With SOPS you can encrypt certain values (or the whole file) and are then able to safely store it in this encrypted state into a git repository, without having to fear that someone would be able to read your secrets.

![SOPS](/images/sops-sops.gif)

Initially I wanted to use PGP as backend for SOPS, since I already use it in combination with [pass](https://www.passwordstore.org/) to store my private passwords in git. (Fantastic tool btw!)

But after researching for a bit longer and learning more in detail as to what exactly a "Cloud KMS" was I decided to use AWS KMS instead PGP. Another reason was also that at the time I was anyway neck deep into learning and preparing for my AWS Solution Architect and Developer associate certifications, and already had a personal AWS account that I used for S3 storage. So why not also use AWS KMS then? After all it is extremely cheap too, just like S3.

### Using SOPS with AWS Key Management Service (KMS)

The great thing about using AWS KMS instead of PGP is that since the master key remains on AWS at all times and is never itself committed onto the git repository (only the generated encryption keys are), it is possible to retroactively revoke access to decrypt any secrets simply by disabling the master key on AWS. It is also easy to use multiple master keys combined and also rotate a key.

First I had to set up a new IAM user with appropriate policies for AWS KMS usage added. Once you create a new master key for in the AWS KMS web console then it will ask you which IAM user to grant access as "key administrator" or "key user". I then also added a new Access key to this user, to allow API access to AWS KMS by using an access key ID and secret key.

For a more detailed guide on using AWS KMS in general you can check out the official documentation here: https://docs.aws.amazon.com/kms/latest/developerguide/create-keys.html

Once I had my shiny new master key ready I could create a *`.sops.yaml`* file in the root of my repository, referring to the AWS ARN of the master key:
```yaml
creation_rules:
- kms: arn:aws:kms:eu-central-1:1234567890:key/beefdead-beef-dead-dead-deadbeef
```

This is the main configuration file for SOPS. With this configuration setting any new secret or file you encrypt with SOPS will be encrypted via the referred master key on AWS KMS.

Since SOPS uses the AWS SDK internally this means it will automatically infer the necessary credentials to access your master key via either [*`AWS_*`* environment variables](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html) or from `~/.aws/credentials` (if you are using the AWS CLI)

For this I've set the necessary *`AWS_*`* environment variables directly as GitHub secrets:

![GitHub AWS secrets](/images/sops-github-aws-secrets.png)

### Secrets file instead of variables

Since as you can see in the screenshot above I've removed all other environment variable secrets from the GitHub repository. So where are they now?

I have added a new file to my git repo, *`secrets.yaml`*, which is a *YAML* file that contains all my secrets now that are needed by my applications and deployments:
```yaml
secrets:
  hetzner:
    token: deadbeef-beefdead
    ssh:
      public_key: 'ssh-rsa ... kubernetes'
      private_key: |
        -----BEGIN RSA PRIVATE KEY-----
        ...
        -----END RSA PRIVATE KEY-----

  ingress:
    basic_auth:
      username: my-user-name
      password: super-secret-password

  lets_encrypt:
    email: 'user@domain'
    prod_key: '... ='
    staging_key: '... ='

  postgres:
    password: super-secret-superuser-password
    backup:
      s3:
        access_key_id: my-access-key
        secret_access_key: my-secret-key
        endpoint: https://s3.eu-west-1.amazonaws.com
        bucket: my-bucket

  grafana:
    password: super-secret-grafana-password
```

This file I then encrypted via simply running `sops -e -i secrets.yaml`. Afterwards the content of the file looks like this:
```yaml
secrets:
    hetzner:
        token: ENC[AES256_GCM,data:J3WHN2aAvIedB2Ogga6qhGA=,iv:CRqk4amBxFffdomf015JAyzn9gTDYS4BowB1j65Wdkl=,tag:MLI3OadfYkqaLygKhryf5w==,type:str]
        ssh:
            public_key: ENC[AES256_GCM,data:x074coIv5IegZm/sRuOkW6i6RX2ILQ==,iv:xJcYGh2SL3FU4FX2Ul71HVgDxDtCJZeH3ls26Qxe4Tx=,tag:yl7B3WPhdJ3sZ3R1ZsQJ53K==,type:str]
            private_key: ENC[AES256_GCM,data:GrugSAh4v5deSWlKNP/idFlTC8P6CQv7HUmYgd3Y6B8ao9FGB0TPwhg41l7BRgt67y5CdDpSOzxFLBSh,iv:kHhGXK+pACGtVQ7hFdihIZ2TJqH1j8q7K58FKbKFo6l=,tag:0ZIqoHCahXwVlvYvh0ea68==,type:str]
    ingress:
        basic_auth:
            username: ENC[AES256_GCM,data:RcTHE4Ad5SfAzsKl,iv:fPJOktbGrudSAh4v5ddSWlKNPUdVRPBpn+v0dqS3A=,tag:5tvr0ffkMR/AE3k3ks4zkQ==,type:str]
            password: ENC[AES256_GCM,data:Fl2G234vsdfzLVQlfGyBB8,iv:uYX2t291234dfddH0CRjaiJeJyT345fdgf46VCvlplKL0=,tag:eJxkE57656wpHZng8xBsdfgA==,type:str]
    lets_encrypt:
        email: ENC[AES256_GCM,data:I/J8XWsdfE23Xc=,iv:z2AkXK/jM234gSAh4v5deSWl54ssvFIA3OiWU=,tag:IoC6/X234fLLTF342Tza5mw==,type:str]
        prod_key: ENC[AES256_GCM,data:Q8NOjyc=,iv:R7xdfHpTSMSpG3isBL4qsdf+8S/8FGxsfUom4k=,tag:bR34spzBj/Q5Gsdf6Cpu+Q==,type:str]
        staging_key: ENC[AES256_GCM,data:63mgFw0=,iv:9Pe345GrugSARcTgEIsdffIzsJBNIRh7N45f8b5RA=,tag:odflzrcsdf6h6OWvU78f5g==,type:str]
    postgres:
        password: ENC[AES256_GCM,data:Jff24GBDKXpNVEKVdfcKwuTKEV62odfgzlQDg==,iv:hcdfgCFijtFU4e8bt12adfgk8HOA5huzKx30=,tag:L2hK26uMsdfy1gh8D+Eg==,type:str]
        backup:
            s3:
                access_key_id: ENC[AES256_GCM,data:9BE3545KsdfCOgig==,iv:+dAdfgskprCdfgv0yB5Vx45ZwjP+rfY456T0tU=,tag:/XT33OdgfP/H39+8odffCw==,type:str]
                secret_access_key: ENC[AES256_GCM,data:ZtsdfOU88567t7w==,iv:gc567P7G+f8f8OefghNnBZyo6Z5hjkcNwVXhjkWo=,tag:K/x234dNo9SfghOHAm2xcv==,type:str]
                endpoint: ENC[AES256_GCM,data:fg234ZSkpaXnyxc+8/hK3yxc2XsOOz2XX8v456YQXg==,iv:pyxcbDfe+m345z+6IyxcqMsxc/JNLT1234ltd=,tag:Dp+qsdfJUdjIJ345Ax567==,type:str]
                bucket: ENC[AES256_GCM,data:Fd345LdqG,iv:SssdfuP6fcvb/IsdfEo3455R1Zdfg=,tag:22UufFsdfMg==,type:str]
    grafana:
        password: ENC[AES256_GCM,data:6hasd6if9ON1aVL456k=,iv:ko4V/u3/nx2223t+5G234SWlKNPEdfg=,tag:3dnLtsdfySn51GsaSfxlw==,type:str]
sops:
    kms:
        - arn: arn:aws:kms:eu-central-1:1234567890:key/beefdead-beef-dead-dead-deadbeef
          created_at: "2021-07-25T14:19:47Z"
          enc: AKICFGHSHrR5cmJjgGFGHvKDmYZVSEGHJShczFxDgDStM7IbXaAA3AfWER9w0BBwagbzBtA34YXSIb3DQEHATAeBglghkDFHMEAS4wD778+ZjYAgast6Pf/6di0V234p6yqHJKWy345aBbYNsmemoTi345A2MBeY+OVP4D/4U3pHM4d+5dfqhA==
```
As you can see all the secrets have been encrypted by SOPS. This file can now be committed and pushed safely to a public GitHub repository.

I now changed the deployments in my monorepo to always on-the-fly read and decrypt the `secrets.yaml` file at the start of each workflow step with a shellscript looking similar to this:
```shell
export HETZNER_CLOUD_TOKEN=$(sops -d "secrets.yaml" | yq -e eval '.secrets.hetzner.token' -)
export HETZNER_PUBLIC_SSH_KEY=$(sops -d "secrets.yaml" | yq -e eval '.secrets.hetzner.ssh.public_key' -)
export HETZNER_PRIVATE_SSH_KEY=$(sops -d "secrets.yaml"| yq -e eval '.secrets.hetzner.ssh.private_key' -)
# etc ...
```

Reading and decrypting these secrets with SOPS and exporting them to environment variables for the running process means that I did not have to do any further changes to my already existing deployment procedures, all workflows were already based on environment variables. 😄

## Video tutorials for SOPS

{{< youtube V2PRhxphH2w >}}

{{< youtube DWzJ87KbwxA >}}

### Appendix

For reference, the blogpost that led me to my decision to use SOPS instead of switching to use Vault: https://oteemo.com/hashicorp-vault-is-overhyped-and-mozilla-sops-with-kms-and-git-is-massively-underrated/
