FROM ubuntu:22.04
RUN apt-get update && apt-get install -y --no-install-recommends \
    autossh openssh-client curl jq coreutils && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /opt/agent
COPY entrypoint.sh integrity.sh hw_fingerprint.sh ./
RUN chmod +x *.sh
ENTRYPOINT ["/opt/agent/entrypoint.sh"]
