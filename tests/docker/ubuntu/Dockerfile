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
    BINDIR="${HOME}/.local/bin" sh -c "$(curl -fsLS get.chezmoi.io)"

# Copy test scripts
COPY --chown=testuser:testuser test-bootstrap.sh /home/testuser/
COPY --chown=testuser:testuser test-bootstrap-offline.sh /home/testuser/
RUN chmod +x /home/testuser/test-bootstrap.sh /home/testuser/test-bootstrap-offline.sh

CMD ["/home/testuser/test-bootstrap-offline.sh"]