#!/usr/bin/env bash
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# SHELLDOC-IGNORE

set -euxo pipefail

# place ourselves in the directory containing the hbase and yetus checkouts
cd "$(dirname "$0")/../.."
echo "executing from $(pwd)"

printenv 2>&1 | sort

declare -i missing_env=0
declare -a required_envs=(
  # these ENV variables define the required API with Jenkinsfile_GitHub
  "ARCHIVE_PATTERN_LIST"
  "BUILD_URL_ARTIFACTS"
  "CHANGE_ID"
  "DOCKER_TAG"
  "GITHUB_TOKEN"
  "PATCHDIR"
  "PATCHDIR_REL"
  "PLUGINS"
  "WORKDIR"
  "SOURCEDIR"
  "SOURCEDIR_REL"
)
# Validate params
for required_env in "${required_envs[@]}"; do
  if [ -z "${!required_env}" ]; then
    echo "[ERROR] Required environment variable '${required_env}' is not set."
    missing_env=${missing_env}+1
  fi
done

if [ ${missing_env} -gt 0 ]; then
  echo "[ERROR] Please set the required environment variables before invoking. If this error is " \
       "on Jenkins, then please file a JIRA about the error."
  exit 1
fi

# where the magic happens inside the container runtime
MOUNT_DIR="/workdir"

declare -a DOCKER_ARGS
DOCKER_ARGS+=('container' 'run')
DOCKER_ARGS+=('--entrypoint' '/bin/bash')
DOCKER_ARGS+=('--mount' "type=bind,source=${WORKDIR},target=${MOUNT_DIR}")
DOCKER_ARGS+=('--platform' 'linux/amd64')
DOCKER_ARGS+=('--quiet')
DOCKER_ARGS+=('--rm')
DOCKER_ARGS+=('--workdir' "${MOUNT_DIR}")
DOCKER_ARGS+=('--user' "$(id -u):$(id -g)")

# path to test-patch in the container image
TESTPATCHBIN="/usr/bin/test-patch"

# this must be clean for every run
rm -rf "${PATCHDIR}"
mkdir -p "${PATCHDIR}"

# Gather machine information
mkdir "${PATCHDIR}/machine"
"${SOURCEDIR}/dev-support/jenkins/gather_machine_environment.sh" "${PATCHDIR}/machine"

# If CHANGE_URL is set (e.g., Github Branch Source plugin), process it.
# Otherwise exit, because we don't want HBase to do a
# full build.  We wouldn't normally do this check for smaller
# projects. :)
if [[ -z "${CHANGE_URL}" ]]; then
  echo "Full build skipped" > "${PATCHDIR}/report.html"
  exit 0
fi
# enable debug output for yetus
if [[ "true" = "${DEBUG}" ]]; then
  YETUS_ARGS+=("--debug")
fi
# If we're doing docker, make sure we don't accidentally pollute the image with a host java path
if [ -n "${JAVA_HOME-}" ]; then
  unset JAVA_HOME
fi
YETUS_ARGS+=('--project=hbase-kustomize')
YETUS_ARGS+=("--patch-dir=${MOUNT_DIR}/${PATCHDIR_REL}")
# where the source is located
YETUS_ARGS+=("--basedir=${MOUNT_DIR}/${SOURCEDIR_REL}")
# lots of different output formats
YETUS_ARGS+=("--brief-report-file=${MOUNT_DIR}/${PATCHDIR_REL}/brief.txt")
YETUS_ARGS+=("--console-report-file=${MOUNT_DIR}/${PATCHDIR_REL}/console.txt")
YETUS_ARGS+=("--html-report-file=${MOUNT_DIR}/${PATCHDIR_REL}/report.html")
# don't complain about issues on source branch
YETUS_ARGS+=('--continuous-improvement=true')
# don't worry about unrecognized options
YETUS_ARGS+=('--ignore-unknown-options=true')
# auto-kill any surefire stragglers during unit test runs
YETUS_ARGS+=("--reapermode=kill")
# -1 spotbugs issues that show up prior to the patch being applied
YETUS_ARGS+=("--spotbugs-strict-precheck")
# rsync these files back into the archive dir
YETUS_ARGS+=("--archive-list=${ARCHIVE_PATTERN_LIST}")
# URL for user-side presentation in reports and such to our artifacts
YETUS_ARGS+=("--build-url-artifacts=${BUILD_URL_ARTIFACTS}")
# include our custom plugins
YETUS_ARGS+=("--user-plugins=${MOUNT_DIR}/${SOURCEDIR_REL}/dev-support/jenkins/yetus_plugins.d")
# plugins to enable
YETUS_ARGS+=("--plugins=${PLUGINS}")
YETUS_ARGS+=("--tests-filter=test4tests")
# help keep the ASF boxes clean
YETUS_ARGS+=("--sentinel")
YETUS_ARGS+=("--github-token=${GITHUB_TOKEN}")
# use emoji vote so it is easier to find the broken line
YETUS_ARGS+=("--github-use-emoji-vote")
YETUS_ARGS+=("--github-repo=apache/hbase-kustomize")
# enable writing back to Github
YETUS_ARGS+=('--github-write-comment')
# increasing proc limit to avoid OOME: unable to create native threads
YETUS_ARGS+=("--proclimit=5000")

YETUS_ARGS+=("GH:${CHANGE_ID}")

echo "Launching yetus via docker with command line:"
echo "docker ${DOCKER_ARGS[*]} ${DOCKER_TAG} ${TESTPATCHBIN} ${YETUS_ARGS[*]}"

/usr/bin/env docker "${DOCKER_ARGS[@]}" "${DOCKER_TAG}" "${TESTPATCHBIN}" "${YETUS_ARGS[@]}"
