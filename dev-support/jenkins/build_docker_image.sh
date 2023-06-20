#!/usr/bin/env bash
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# SHELLDOC-IGNORE

set -euxo pipefail

# variables referenced from the environment.
declare DOCKER_MULTIARCH="${DOCKER_MULTIARCH-}"
declare IMAGE_NAME_TAG="${IMAGE_NAME_TAG-}"
declare SOURCE_BRANCH="${SOURCE_BRANCH-}"
declare SOURCE_COMMIT="${SOURCE_COMMIT-}"

function usage
{
    cat <<EOF
Usage: $0 -h|--help|<target> [extra_bake_args...]

Construct an environment suitable for running docker buildx bake from a CI environment. Can be run
safely from a developer's local environment as well. This script is responsible for (1)
establishing a suitable builder agent when requested ; (2) extracting metadata to populate image
labels ; and (3) invoking docker buildx bake with arguments appropriate to the specified image.

Options:
  -h|--help: Print this usage message and exit.
  target: The image to build (and publish). Required. One of:
    kuttl: builds 'dockerfiles/kuttl'
  extra_bake_args...: Additional argument(s) passed along to the docker
    buildx bake invocation. Optional.

Environment:
  DOCKER_MULTIARCH: When non-empty, this script creates and uses a multi-
    platform docker container builder instance.
  IMAGE_NAME_TAG: This script will attempt to identify the current git tag or
    branch and use this value as the image tag. Set this variable to a
    non-empty value to override the final tag name.
  SOURCE_BRANCH: This script will attempt to identify the current git branch.
    This value is used as part of building the image tag and included in an
    image label. Set this variable to a non-empty value to override branch
    name detection.
  SOURCE_COMMIT: This script will attempt to identify the current git commit.
    this value is included in an image label. Set this variable to a non-empty
    value to override commit detection.
EOF
}

declare target
declare build_dir
declare -a extra_bake_args=()
function parse_args
{
  if [ "$#" -lt 1 ] ; then
    usage
    exit 1
  fi

  target="$1"
  shift

  case $target in
    -h|--help)
      usage
      exit 0
      ;;
    kuttl)
      build_dir='dockerfiles/kuttl'
      ;;
    *)
      usage
      exit 1
      ;;
  esac

  extra_bake_args+=("$@")
}

parse_args "$@"

#
# TODO: enable more platforms as our base-image, yetus, adds support.
#

if [[ -n "${DOCKER_MULTIARCH}" ]]; then
  docker buildx create \
       --name hbase-kustomize-multiarch \
       --driver docker-container \
       --platform linux/amd64 \
       --use \
    || docker buildx use hbase-kustomize-multiarch \
    || exit 1
  docker buildx inspect --bootstrap || exit 1

  traphandler() {
    docker buildx rm hbase-kustomize-multiarch || true
  }

  trap traphandler EXIT HUP INT QUIT TERM
fi

declare -a platarray=('')
function select_platforms {
  local -a platforms=()
  local known_platforms
  known_platforms="$(docker buildx inspect --bootstrap | grep Platforms)"

  if [[ ${known_platforms} =~ linux/amd64 ]]; then
    platforms+=('linux/amd64')
  fi

  if [ -z "${platforms[*]-}" ] ; then
    >&2 echo 'Error: The active docker buildx context does not offer any of the supported'
    >&2 echo 'platforms. Supported platforms are: linux/amd64. Consider building with'
    >&2 echo 'DOCKER_MULTIARCH=1.'
    exit 1
  fi

  local platstring
  platstring=${platforms[*]}
  platstring=${platstring/ /,}
  platarray=(--set '*.platform='"${platstring}")
}

iso8601date() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

declare -a labels=()
opencontainerslabels() {
  local desc
  local title_suffix

  ## Reference: https://github.com/opencontainers/image-spec/blob/main/annotations.md

  case "$1" in
    "kuttl")
      desc="Test image used for working on HBase Kustomize. Includes 3rd party tools."
      title_suffix=" (kuttl Test image)"
      ;;
  esac


  if [[ "${git_url}" =~ apache/hbase-kustomize ]]; then
    for label in \
      "org.opencontainers.image.description=${desc}" \
      "org.opencontainers.image.authors=\"Apache HBase <dev@hbase.apache.org>\"" \
      "org.opencontainers.image.url=https://hbase.apache.org" \
      "org.opencontainers.image.documentation=https://github.com/apache/hbase-kustomize" \
      "org.opencontainers.image.title=\"Apache HBase Kustomize ${title_suffix}\"" \
      ; do
        labels+=(--set '*.labels.'"$label")
    done
  fi

 for label in \
    "org.opencontainers.image.created=$(iso8601date)" \
    "org.opencontainers.image.source=${git_url}" \
    "org.opencontainers.image.version=${SOURCE_BRANCH}" \
    "org.opencontainers.image.revision=${SOURCE_COMMIT}" \
  ; do
    labels+=(--set '*.labels.'"$label")
  done
}

declare git_url
git_url="$(git config --get remote.origin.url)"

if [[ -z "${SOURCE_COMMIT}" ]]; then
  SOURCE_COMMIT="$(git rev-parse --verify HEAD)"
  export SOURCE_COMMIT
fi

if [[ -z "${SOURCE_BRANCH}" ]]; then
  SOURCE_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "${SOURCE_BRANCH}" == 'HEAD' ]]; then
    SOURCE_BRANCH=$(git describe --tags)
  fi
  export SOURCE_BRANCH
fi

if [[ -z "${IMAGE_NAME_TAG}" ]]; then
  IMAGE_NAME_TAG="${SOURCE_BRANCH/rel\//}"
  export IMAGE_NAME_TAG
fi

opencontainerslabels "${target}"

select_platforms

declare -a bake_args=()
bake_args+=('--pull')
if [[ -n "${DOCKER_MULTIARCH}" ]]; then
    bake_args+=('--load')
fi
if [ -n "${platarray[*]-}" ] ; then
  bake_args+=("${platarray[@]}")
fi
bake_args+=("${labels[@]}")
bake_args+=('--file' "${build_dir}/docker-bake.hcl")
bake_args+=('--file' "${build_dir}/docker-bake.override.hcl")
if [ -n "${extra_bake_args[*]-}" ] ; then
  bake_args+=("${extra_bake_args[@]}")
fi

docker buildx bake --print "${bake_args[@]}" || exit 1
docker buildx bake "${bake_args[@]}" || exit 1
