FROM debian:bullseye-slim

# Install essential tools for Terraform and Azure
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install Terraform
RUN wget -O terraform.zip https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip \
    && apt-get update && apt-get install -y unzip \
    && unzip terraform.zip -d /usr/local/bin/ \
    && rm terraform.zip \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -s /bin/bash vscode

USER vscode
WORKDIR /workspace
