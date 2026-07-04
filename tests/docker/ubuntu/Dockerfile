FROM ubuntu:22.04

# Install basic dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    sudo \
    ca-certificates \
    build-essential \
    procps \
    file \
    && rm -rf /var/lib/apt/lists/*

# Install bats-core and assertion libraries from source
RUN git clone --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats-core \
    && /tmp/bats-core/install.sh /usr/local \
    && git clone --depth 1 https://github.com/bats-core/bats-support.git /usr/local/lib/bats-support \
    && git clone --depth 1 https://github.com/bats-core/bats-assert.git /usr/local/lib/bats-assert \
    && rm -rf /tmp/bats-core

# Create a non-root user for testing
RUN useradd -m -s /bin/bash testuser && \
    echo 'testuser ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Switch to test user
USER testuser
WORKDIR /home/testuser

# Set up environment
ENV HOME=/home/testuser
ENV PATH="${HOME}/.local/bin:${PATH}"

# Install chezmoi first (as required by bootstrap)
RUN mkdir -p ${HOME}/.local/bin && \
    cd /tmp && \
    curl -sL "https://github.com/twpayne/chezmoi/releases/download/v2.66.0/chezmoi_2.66.0_linux_amd64.tar.gz" -o chezmoi.tar.gz && \
    tar -xzf chezmoi.tar.gz && \
    mv chezmoi ${HOME}/.local/bin/ && \
    chmod +x ${HOME}/.local/bin/chezmoi && \
    rm chezmoi.tar.gz

# Copy test scripts
COPY --chown=testuser:testuser test-bootstrap.sh /home/testuser/
COPY --chown=testuser:testuser test-bootstrap-offline.sh /home/testuser/
RUN chmod +x /home/testuser/test-bootstrap.sh /home/testuser/test-bootstrap-offline.sh

CMD ["/home/testuser/test-bootstrap-offline.sh"]