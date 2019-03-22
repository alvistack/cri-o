FROM golang:1.8

RUN apt-get update && apt-get install -y \
    apparmor \
    autoconf \
    automake \
    bison \
    build-essential \
    curl \
    e2fslibs-dev \
    gawk \
    gettext \
    iptables \
    pkg-config \
    libaio-dev \
    libcap-dev \
    libfuse-dev \
    libostree-dev \
    libprotobuf-dev \
    libprotobuf-c0-dev \
    libseccomp2 \
    libseccomp-dev \
    libtool \
    libudev-dev \
    protobuf-c-compiler \
    protobuf-compiler \
    python-minimal \
    libglib2.0-dev \
    libapparmor-dev \
    btrfs-tools \
    libdevmapper1.02.1 \
    libdevmapper-dev \
    libgpgme11-dev \
    liblzma-dev \
    netcat \
    socat \
    --no-install-recommends \
    bsdmainutils \
    && apt-get clean

# install bats
RUN cd /tmp \
    && git clone https://github.com/sstephenson/bats.git \
    && cd bats \
    && git reset --hard 03608115df2071fff4eaaff1605768c275e5f81f \
    && ./install.sh /usr/local

# install criu
ENV CRIU_VERSION 1.7
RUN mkdir -p /usr/src/criu \
    && curl -sSL https://github.com/xemul/criu/archive/v${CRIU_VERSION}.tar.gz | tar -v -C /usr/src/criu/ -xz --strip-components=1 \
    && cd /usr/src/criu \
    && make install-criu \
    && rm -rf /usr/src/criu

# Install runc
ENV RUNC_COMMIT ce80fa0a64803d52883955cb77b2708b438a0b28
RUN set -x \
	&& export GOPATH="$(mktemp -d)" \
	&& git clone https://github.com/opencontainers/runc.git "$GOPATH/src/github.com/opencontainers/runc" \
	&& cd "$GOPATH/src/github.com/opencontainers/runc" \
	&& git fetch origin --tags \
	&& git checkout -q "$RUNC_COMMIT" \
	&& make static BUILDTAGS="seccomp selinux" \
	&& cp runc /usr/bin/runc \
	&& rm -rf "$GOPATH"

# Install CNI plugins
ENV CNI_COMMIT dcf7368eeab15e2affc6256f0bb1e84dd46a34de
RUN set -x \
       && export GOPATH="$(mktemp -d)" \
       && git clone https://github.com/containernetworking/plugins.git "$GOPATH/src/github.com/containernetworking/plugins" \
       && cd "$GOPATH/src/github.com/containernetworking/plugins" \
       && git checkout -q "$CNI_COMMIT" \
       && ./build.sh \
       && mkdir -p /opt/cni/bin \
       && cp bin/* /opt/cni/bin/ \
       && rm -rf "$GOPATH"

# Install CNI bridge plugin test wrapper
COPY test/cni_plugin_helper.bash /opt/cni/bin/cni_plugin_helper.bash

# Install crictl
ENV CRICTL_COMMIT release-1.10
RUN set -x \
       && export GOPATH="$(mktemp -d)" \
       && git clone https://github.com/kubernetes-sigs/cri-tools.git "$GOPATH/src/github.com/kubernetes-sigs/cri-tools" \
       && cd "$GOPATH/src/github.com/kubernetes-sigs/cri-tools" \
       && git checkout -q "$CRICTL_COMMIT" \
       && go install github.com/kubernetes-sigs/cri-tools/cmd/crictl \
       && cp "$GOPATH"/bin/crictl /usr/bin/ \
       && rm -rf "$GOPATH"

# Make sure we have some policy for pulling images
RUN mkdir -p /etc/containers
COPY test/policy.json /etc/containers/policy.json
COPY test/redhat_sigstore.yaml /etc/containers/registries.d/registry.access.redhat.com.yaml

WORKDIR /go/src/github.com/kubernetes-sigs/cri-o

ADD . /go/src/github.com/kubernetes-sigs/cri-o
