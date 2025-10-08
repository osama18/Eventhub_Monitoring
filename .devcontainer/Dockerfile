FROM openjdk:17-jdk-slim

# Install basic tools
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    make \
    ca-certificates \
    gnupg \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Install Docker
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce docker-ce-cli containerd.io \
    && rm -rf /var/lib/apt/lists/*

# Install Maven
RUN curl -fsSL https://archive.apache.org/dist/maven/maven-3/3.9.4/binaries/apache-maven-3.9.4-bin.tar.gz | tar xzf - -C /opt \
    && ln -s /opt/apache-maven-3.9.4 /opt/maven \
    && ln -s /opt/maven/bin/mvn /usr/local/bin/mvn

ENV MAVEN_HOME=/opt/maven
ENV PATH=$PATH:$MAVEN_HOME/bin

# Create a non-root user and add to docker group
RUN useradd -m -s /bin/bash vscode \
    && usermod -aG docker vscode
USER vscode

WORKDIR /workspace