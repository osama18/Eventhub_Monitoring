FROM openjdk:17-jdk-slim

# Install basic tools
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    make \
    && rm -rf /var/lib/apt/lists/*

# Install Maven
RUN curl -fsSL https://archive.apache.org/dist/maven/maven-3/3.9.4/binaries/apache-maven-3.9.4-bin.tar.gz | tar xzf - -C /opt \
    && ln -s /opt/apache-maven-3.9.4 /opt/maven \
    && ln -s /opt/maven/bin/mvn /usr/local/bin/mvn

ENV MAVEN_HOME=/opt/maven
ENV PATH=$PATH:$MAVEN_HOME/bin

# Create a non-root user
RUN useradd -m -s /bin/bash vscode
USER vscode

WORKDIR /workspace