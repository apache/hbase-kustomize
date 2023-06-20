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

# no public APIs here
# SHELLDOC-IGNORE

add_test_type kuttl

KUTTL_TIMER=0
KUTTL_KUBECTL=${KUBECTL:-$(command -v kubectl 2>/dev/null)}
KUTTL_TEST_INVOCATION=( "${KUTTL_KUBECTL}" 'kuttl' 'test' )
# files that define `kubectl kuttl test` invocations.
KUTTL_CONFIGS=()
DECLARED_KUTTL_INVOCATION='false'
DECLARED_KUBECTL_PATH='false'

function kuttl_usage
{
  yetus_add_option "--kuttl-test-invocation=<invocation>" "fully describe an executable invocation, i.e., using docker (default: '${KUTTL_TEST_INVOCATION[*]}')."
  yetus_add_option "--kuttl-kubectl=<path>" "path to the kubectl executable (default: '${KUTTL_KUBECTL}')."
  yetus_add_option "--kuttl-config" "relative path to kuttl configuration file in source tree (my be specified multiple times). [default: kuttl-test.yaml]"
}

function kuttl_parse_args
{
  declare i

  for i in "$@" ; do
    case ${i} in
      --kuttl-test-invocation=*)
        DECLARED_KUTTL_INVOCATION='true'
        if [ "${DECLARED_KUBECTL_PATH}" = 'true' ] ; then
          yetus_error "--kuttl-test-invocation and --kuttl-kubectl are mutually exclusive but both provided."
          return 1
        fi
        delete_parameter "${i}"
        KUTTL_TEST_INVOCATION=()
        read -r -a KUTTL_TEST_INVOCATION <<< "${i#*=}"
        ;;
      --kuttl-kubectl=*)
        DECLARED_KUBECTL_PATH='true'
        if [ "${DECLARED_KUTTL_INVOCATION}" = 'true' ] ; then
          yetus_error "--kuttl-test-invocation and --kuttl-kubectl are mutually exclusive but both provided."
          return 1
        fi
        delete_parameter "${i}"
        KUTTL_KUBECTL=${i#*=}
        KUTTL_TEST_INVOCATION=( "${KUTTL_KUBECTL}" 'kuttl' 'test' )
        ;;
      --kuttl-config=*)
        delete_parameter "${i}"
        yetus_add_array_element KUTTL_CONFIGS "${i#*=}"
        ;;
    esac
  done
}

function kuttl_filefilter
{
  local filename=$1
  local i

  for i in "${KUTTL_CONFIGS[@]}" ; do
    if [ "${filename}" = "${i}" ] ; then
      add_test kuttl
    fi
  done

  if [[ ${filename} =~ /kuttl-test.yaml$ ]] || [[ ${filename} =~ ^kuttl-test.yaml$ ]] ; then
    yetus_add_array_element KUTTL_CONFIGS "${filename}"
    add_test kuttl
  fi
}

function verify_kuttl
{
  yetus_debug "verifying the presence of ${KUTTL_TEST_INVOCATION[*]}"

  if "${KUTTL_TEST_INVOCATION[@]}" '--help' >> "${PATCH_DIR}/verify-kuttl.txt" 2>&1 ; then
    return 0
  else
    return 1
  fi
}

function kuttl_precheck
{
  if ! verify_kuttl ; then
    add_vote_table 0 kuttl "kuttl was not available."
    delete_test kuttl
  fi
}

function kuttl_exec
{
  local repostatus=$1
  local config=$2
  local result=0

  if [ ! -f "${config}" ] ; then
    yetus_debug "file not found: ${config}"
    return 1
  fi

  yetus_debug "Running: kubectl kuttl --config ${config}"
  pushd "${BASEDIR}" >/dev/null || return 1

  {
    echo "${KUTTL_TEST_INVOCATION[@]}" --config "${config}"
    "${KUTTL_TEST_INVOCATION[@]}" --config "${config}"
    result=$?
  } >> "${PATCH_DIR}/${repostatus}-kuttl-result.txt" 2>&1

  popd >/dev/null || return 1
  return $result
}

function kuttl_precompile
{
  set -x
  local repostatus=$1
  local i
  local result_total=0
  local result_local=0

  if ! verify_needed_test kuttl ; then
    set +x
    return 0
  fi

  start_clock
  if [ "${repostatus}" = 'branch' ] ; then
    big_console_header "kuttl plugin: ${PATCH_BRANCH}"
  else
    big_console_header "kuttl plugin: ${BUILDMODE}"
    # add our previous elapsed to our new timer by setting the clock back
    offset_clock "${KUTTL_TIMER}"
  fi

  for i in "${KUTTL_CONFIGS[@]}" ; do
    # test failures should not terminate the build ; failures are reported by the junit plug-in
      kuttl_exec "${repostatus}" "${i}"
      result_local=$?
      (( result_total = result_total + result_local ))
  done

  if [ "${repostatus}" = 'branch' ] ; then
    # keep track of how much as elapsed for us already
      KUTTL_TIMER=$(stop_clock)
  fi

  if [[ $result_total -gt 0 ]] ; then
    add_vote_table -1 kuttl "${BUILDMODEMSG} had errors."
    add_footer_table kuttl "@@BASE@@/${repostatus}-kuttl-result.txt"
    set +x
    return 1
  else
    add_vote_table +1 kuttl "${BUILDMODEMSG} had no errors."
    set +x
    return 0
  fi
}
