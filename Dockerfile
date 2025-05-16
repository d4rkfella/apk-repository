FROM cgr.dev/chainguard/wolfi-base:latest AS build

# Arguments
ARG TARGETPLATFORM
ARG RUNNER_VERSION=2.323.0
ARG RUNNER_CONTAINER_HOOKS_VERSION=0.7.0
ARG DOTNET_VERSION=8
ARG RUNNER_UID=1001
ARG RUNNER_GID=1001

# Set up the non-root user (runner)
RUN addgroup -g ${RUNNER_GID} -S runner && \
    adduser -u ${RUNNER_UID} -S runner -G runner

# Install software
RUN apk add --no-cache \
  aspnet-${DOTNET_VERSION}-runtime \
  sudo \
  bash \
  ca-certificates \
  curl \
  git \
  gh \
  jq \
  nodejs \
  wget \
  unzip \
  yq \
  melange \
  bubblewrap

RUN echo "https://packages.darkfellanetwork.com/wolfi-os" >> /etc/apk/repositories && curl -sL https://packages.darkfellanetwork.com/wolfi-os/melange.rsa.pub -o /etc/apk/keys/melange.rsa.pub

RUN apk add --no-cache \
  jfrog-cli
  
RUN export PATH=$HOME/.local/bin:$PATH

# Shell setup
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Make and set the working directory
RUN mkdir -p /home/runner \
  && chown -R runner:runner /home/runner

# Allow passwordless sudo for runner user
RUN echo "runner ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/runner \
 && chmod 0440 /etc/sudoers.d/runner

WORKDIR /home/runner

RUN test -n "$TARGETPLATFORM" || (echo "TARGETPLATFORM must be set" && false)

# Runner download supports amd64 and x64
RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
  && if [ "$ARCH" = "amd64" ]; then export ARCH=x64 ; fi \
  && curl -L -o runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz \
  && tar xzf ./runner.tar.gz \
  && rm runner.tar.gz

# remove bundled nodejs and symlink to system nodejs
RUN rm /home/runner/externals/node20/bin/node && ln -s /usr/bin/node /home/runner/externals/node20/bin/node

# Install container hooks
RUN curl -f -L -o runner-container-hooks.zip https://github.com/actions/runner-container-hooks/releases/download/v${RUNNER_CONTAINER_HOOKS_VERSION}/actions-runner-hooks-k8s-${RUNNER_CONTAINER_HOOKS_VERSION}.zip \
  && unzip ./runner-container-hooks.zip -d ./k8s \
  && rm runner-container-hooks.zip

# configure directory permissions; ref https://github.com/actions/runner-images/blob/main/images/ubuntu/scripts/build/configure-system.sh
RUN chmod -R 777 /opt /usr/share

# squash it!
FROM scratch AS final

USER runner

COPY --from=build / /

WORKDIR /home/runner

LABEL org.opencontainers.image.source="https://github.com/d4rkfella/apk-repository"
LABEL org.opencontainers.image.title="wolfi"
LABEL org.opencontainers.image.description="A Chainguard Wolfi based runner image for GitHub Actions"
LABEL org.opencontainers.image.authors="Georgi Panov"
LABEL org.opencontainers.image.licenses="MIT"

ENV RUNNER_MANUALLY_TRAP_SIG=1
ENV ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1
ENV DOTNET_RUNNING_IN_CONTAINER=true
