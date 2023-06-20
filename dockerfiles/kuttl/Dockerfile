# syntax=docker/dockerfile:1.4
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# hadolint global ignore=DL3020

ARG IMG_BASE='ghcr.io/apache/yetus'
ARG IMG_BASE_TAG='0.14.1'
ARG BASE_IMG_ALPINE='alpine'
ARG BASE_IMG_TAG_ALPINE='latest'
ARG YQ_IMG='mikefarah/yq'
ARG YQ_IMG_TAG='latest'

FROM ${BASE_IMG_ALPINE}:${BASE_IMG_TAG_ALPINE} as alpine
RUN apk add --no-cache \
    bash~=5 \
    curl~=8

FROM ${YQ_IMG}:${YQ_IMG_TAG} as yq

## -- Stages kubectl_${TARGETARCH} --
# Define stages that facilitate bringing in platform-specific binaries.
FROM alpine as kubectl_amd64
ARG KUBECTL_SHA_AMD64_URL
ARG KUBECTL_SHA_AMD64
ARG KUBECTL_BIN_AMD64_URL
ARG KUBECTL_BIN_AMD64
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /tmp
ADD --link ${KUBECTL_SHA_AMD64_URL} /tmp/
ADD --link ${KUBECTL_BIN_AMD64_URL} /tmp/
RUN echo "$(cat "${KUBECTL_SHA_AMD64}")  ${KUBECTL_BIN_AMD64}" | sha512sum -c
ENV KUBECTL_BIN "${KUBECTL_BIN_AMD64}"

FROM alpine as kubectl_arm64
ARG KUBECTL_SHA_ARM64_URL
ARG KUBECTL_SHA_ARM64
ARG KUBECTL_BIN_ARM64_URL
ARG KUBECTL_BIN_ARM64
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /tmp
ADD --link ${KUBECTL_SHA_ARM64_URL} /tmp/
ADD --link ${KUBECTL_BIN_ARM64_URL} /tmp/
RUN echo "$(cat "${KUBECTL_SHA_ARM64}")  ${KUBECTL_BIN_ARM64}" | sha512sum -c
ENV KUBECTL_BIN "${KUBECTL_BIN_ARM64}"

ARG TARGETARCH
# hadolint ignore=DL3006
FROM kubectl_${TARGETARCH} as kubectl
RUN mv "/tmp/${KUBECTL_BIN}" /tmp/kubectl \
    && chmod a+x /tmp/kubectl

## -- Stages kuttl_${TARGETARCH} --
# Define stages that facilitate bringing in platform-specific binaries.
FROM alpine as kuttl_amd64
ARG KUTTL_CHECKSUMS_URL
ARG KUTTL_CHECKSUMS
ARG KUTTL_BIN_AMD64_URL
ARG KUTTL_BIN_AMD64
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /tmp
ADD --link ${KUTTL_CHECKSUMS_URL} /tmp/
ADD --link ${KUTTL_BIN_AMD64_URL} /tmp/
RUN sha256sum -c <(grep "${KUTTL_BIN_AMD64}" "${KUTTL_CHECKSUMS}")
ENV KUTTL_BIN "${KUTTL_BIN_AMD64}"

FROM alpine as kuttl_arm64
ARG KUTTL_CHECKSUMS_URL
ARG KUTTL_CHECKSUMS
ARG KUTTL_BIN_ARM64_URL
ARG KUTTL_BIN_ARM64
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /tmp
ADD --link ${KUTTL_CHECKSUMS_URL} /tmp/
ADD --link ${KUTTL_BIN_ARM64_URL} /tmp/
RUN sha256sum -c <(grep "${KUTTL_BIN_ARM64}" "${KUTTL_CHECKSUMS}")
ENV KUTTL_BIN "${KUTTL_BIN_ARM64}"

ARG TARGETARCH
# hadolint ignore=DL3006
FROM kuttl_${TARGETARCH} as kuttl
RUN mv "/tmp/${KUTTL_BIN}" /tmp/kubectl-kuttl \
    && chmod a+x /tmp/kubectl-kuttl

## -- Stages kustomize_${TARGETARCH} --
# Define stages that facilitate bringing in platform-specific binaries.
FROM alpine as kustomize_amd64
ARG KUSTOMIZE_CHECKSUMS_URL
ARG KUSTOMIZE_CHECKSUMS
ARG KUSTOMIZE_BIN_AMD64_TGZ_URL
ARG KUSTOMIZE_BIN_AMD64_TGZ
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /tmp
ADD --link ${KUSTOMIZE_CHECKSUMS_URL} /tmp/
ADD --link ${KUSTOMIZE_BIN_AMD64_TGZ_URL} /tmp/
RUN sha256sum -c <(grep "${KUSTOMIZE_BIN_AMD64_TGZ}" "${KUSTOMIZE_CHECKSUMS}")
ENV KUSTOMIZE_BIN_TGZ "${KUSTOMIZE_BIN_AMD64_TGZ}"

FROM alpine as kustomize_arm64
ARG KUSTOMIZE_CHECKSUMS_URL
ARG KUSTOMIZE_CHECKSUMS
ARG KUSTOMIZE_BIN_ARM64_TGZ_URL
ARG KUSTOMIZE_BIN_ARM64_TGZ
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /tmp
ADD --link ${KUSTOMIZE_CHECKSUMS_URL} /tmp/
ADD --link ${KUSTOMIZE_BIN_ARM64_TGZ_URL} /tmp/
RUN sha256sum -c <(grep "${KUSTOMIZE_BIN_ARM64_TGZ}" "${KUSTOMIZE_CHECKSUMS}")
ENV KUSTOMIZE_BIN_TGZ "${KUSTOMIZE_BIN_ARM64_TGZ}"

ARG TARGETARCH
# hadolint ignore=DL3006
FROM kustomize_${TARGETARCH} as kustomize
RUN tar xzf "/tmp/${KUSTOMIZE_BIN_TGZ}" \
    && chmod a+x /tmp/kustomize

FROM alpine as hadolint_amd64
ARG HADOLINT_VERSION=2.12.0
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sSl \
        https://github.com/hadolint/hadolint/releases/download/v$HADOLINT_VERSION/hadolint-Linux-x86_64 \
        -o /bin/hadolint \
    && chmod a+rx /bin/hadolint

FROM alpine as hadolint_arm64
ARG HADOLINT_VERSION=2.12.0
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sSl \
        https://github.com/hadolint/hadolint/releases/download/v$HADOLINT_VERSION/hadolint-Linux-arm64 \
        -o /bin/hadolint \
    && chmod a+rx /bin/hadolint

ARG TARGETARCH
FROM hadolint_$TARGETARCH AS hadolint

FROM ${IMG_BASE}:${IMG_BASE_TAG} as final
ARG IMG_BASE
ARG IMG_BASE_TAG

COPY --from=hadolint /bin/hadolint /bin/hadolint
COPY --from=kubectl /tmp/kubectl /usr/local/bin/
COPY --from=kustomize /tmp/kustomize /usr/local/bin/
COPY --from=kuttl /tmp/kubectl-kuttl /usr/local/bin/
COPY --from=yq /usr/bin/yq /usr/bin/yq
COPY --chmod=0755 dockerfiles/kuttl/entrypoint.sh /bin/

# nonroot user as defined in https://github.com/GoogleContainerTools/distroless
ENV NON_ROOT_USER=nonroot
ENV NON_ROOT_USER_ID=65532
ENV NON_ROOT_USER_HOME=/home/nonroot

ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_TERSE=true

# hadolint ignore=DL3018
RUN apt-get -q update \
    && apt-get -q -y upgrade \
    && apt-get -q clean \
    && rm -rf /var/lib/apt/lists/* \
    && adduser --disabled-password --uid "${NON_ROOT_USER_ID}" "${NON_ROOT_USER}" \
    && adduser "${NON_ROOT_USER}" docker

WORKDIR "${NON_ROOT_USER_HOME}"
USER "${NON_ROOT_USER}"

# setup a go dev environment
ENV GOPATH="${NON_ROOT_USER_HOME}/go"
ENV GOBIN="${GOPATH}/bin"
ENV PATH="${PATH}:${GOBIN}"

# replicate the test-related bits generated by `kubebuilder` into its Makefile.
ENV ENVTEST_K8S_VERSION='1.23.x'
RUN go install sigs.k8s.io/controller-runtime/tools/setup-envtest@latest \
    && "${GOBIN}/setup-envtest" use "${ENVTEST_K8S_VERSION}"

# disable downloading remote content henceforth
ENV ENVTEST_INSTALLED_ONLY=true

ENTRYPOINT ["/bin/entrypoint.sh"]

# verify the image basically works
FROM final AS test
COPY dockerfiles/kuttl/test/* ./
RUN bats *.bats
