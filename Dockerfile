FROM node:22-bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV BUN_INSTALL=/root/.bun
ENV PATH="/root/.bun/bin:/opt/python-venv/bin:${PATH}"
WORKDIR /workspace

# Native toolchains and language runtimes.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget gnupg unzip zip xz-utils git build-essential \
    gcc g++ make cmake pkg-config \
    php-cli php-mbstring php-xml php-curl \
    default-jdk kotlin scala \
    perl r-base lua5.4 elixir \
    python3 python3-venv python3-pip \
    && rm -rf /var/lib/apt/lists/*

# .NET SDK provides C# and F# toolchains.
RUN wget -q https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb \
    && dpkg -i /tmp/packages-microsoft-prod.deb \
    && rm /tmp/packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends dotnet-sdk-8.0 \
    && rm -rf /var/lib/apt/lists/*

# Dart SDK.
RUN install -d -m 0755 /etc/apt/keyrings \
    && wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/keyrings/dart.gpg \
    && chmod a+r /etc/apt/keyrings/dart.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/dart.gpg] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main" > /etc/apt/sources.list.d/dart_stable.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends dart \
    && rm -rf /var/lib/apt/lists/*

# Bun runtime.
RUN curl -fsSL https://bun.sh/install | bash

# Isolated Python environment: Python is the only API/backend language.
RUN python3 -m venv /opt/python-venv
COPY docker/requirements-api.txt /tmp/requirements-api.txt
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r /tmp/requirements-api.txt

# Install the frontend toolchains used by the web workspace.
COPY web/package.json /workspace/web/package.json
RUN cd /workspace/web && npm install

COPY . /workspace
WORKDIR /workspace/web

EXPOSE 5173
CMD ["npm", "run", "dev"]
