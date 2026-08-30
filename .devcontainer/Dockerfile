FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG TERRAFORM_VERSION=1.16.0
ARG TERRAFORM_SHA256=41d05b927aa174f15d1228c4eba832a323b716c68b415ef5a00179f46cc602d3
ARG GO_VERSION=1.26.7
ARG GO_SHA256=ffb5f8de10c62550dfddab66b36b57030721e0a44a3218e9e1181d7b59f121ca
ARG KUBECTL_VERSION=v1.36.1
ARG KUBECTL_SHA256=629d3f410e09bf49b64ae7079f7f0bda1191efed311f7d37fdbab0ad5b0ec2b7
ARG HELM_VERSION=v3.19.0
ARG HELM_SHA256=a7f81ce08007091b86d8bd696eb4d86b8d0f2e1b9f6c714be62f82f96a594496
ARG GCLOUD_VERSION=582.0.0-0

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gnupg unzip make jq python3 shellcheck ripgrep gettext-base \
    && curl -fsSLo /tmp/terraform.zip "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
    && echo "${TERRAFORM_SHA256}  /tmp/terraform.zip" | sha256sum --check --strict - \
    && unzip /tmp/terraform.zip -d /usr/local/bin \
    && curl -fsSLo /tmp/go.tar.gz "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
    && echo "${GO_SHA256}  /tmp/go.tar.gz" | sha256sum --check --strict - \
    && tar -C /usr/local -xzf /tmp/go.tar.gz \
    && curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && echo "${KUBECTL_SHA256}  /usr/local/bin/kubectl" | sha256sum --check --strict - \
    && curl -fsSLo /tmp/helm.tar.gz "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" \
    && echo "${HELM_SHA256}  /tmp/helm.tar.gz" | sha256sum --check --strict - \
    && tar -C /tmp -xzf /tmp/helm.tar.gz \
    && install /tmp/linux-amd64/helm /usr/local/bin/helm \
    && chmod +x /usr/local/bin/kubectl \
    && curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
      | gpg --dearmor --batch --yes -o /usr/share/keyrings/cloud.google.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
      > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && apt-get update \
    && CLOUDSDK_SKIP_PY_COMPILATION=1 apt-get install -y --no-install-recommends "google-cloud-cli=${GCLOUD_VERSION}" \
    && rm -rf /var/lib/apt/lists/* /tmp/*

ENV PATH="/usr/local/go/bin:${PATH}"

COPY scripts/install-security-tools.sh /tmp/install-security-tools.sh
RUN bash /tmp/install-security-tools.sh /usr/local/bin \
    && rm /tmp/install-security-tools.sh

USER vscode
