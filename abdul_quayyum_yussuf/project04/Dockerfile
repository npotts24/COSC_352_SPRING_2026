FROM ubuntu:24.04

# Install Java
RUN apt-get update && apt-get install -y openjdk-17-jdk wget unzip

# Install Kotlin
RUN wget -q https://github.com/JetBrains/kotlin/releases/download/v1.9.21/kotlin-compiler-1.9.21.zip && \
    unzip kotlin-compiler-1.9.21.zip && \
    mv kotlinc /usr/local/ && \
    rm kotlin-compiler-1.9.21.zip

# Install Go
RUN wget -q https://go.dev/dl/go1.21.5.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz && \
    rm go1.21.5.linux-amd64.tar.gz

ENV PATH="/usr/local/kotlinc/bin:/usr/local/go/bin:$PATH"

WORKDIR /app

COPY . .

RUN chmod +x run.sh

ENTRYPOINT ["./run.sh"]