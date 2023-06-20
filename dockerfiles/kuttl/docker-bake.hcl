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
#
# A convenience script to build the kuttl image. See ./README.md
#

# input variables
variable KUBECTL_VERSION { default = "1.24.10" }
variable KUSTOMIZE_VERSION { default = "4.5.4" }
variable KUTTL_VERSION { default = "0.15.0" }

variable KUBECTL_SHA_AMD64_URL {}
variable KUBECTL_SHA_AMD64 {}
variable KUBECTL_BIN_AMD64_URL {}
variable KUBECTL_BIN_AMD64 {}
variable KUBECTL_SHA_ARM64_URL {}
variable KUBECTL_SHA_ARM64 {}
variable KUBECTL_BIN_ARM64_URL {}
variable KUBECTL_BIN_ARM64 {}
variable KUTTL_CHECKSUMS_URL {}
variable KUTTL_CHECKSUMS {}
variable KUTTL_BIN_AMD64_URL {}
variable KUTTL_BIN_AMD64 {}
variable KUTTL_BIN_ARM64_URL {}
variable KUTTL_BIN_ARM64 {}
variable KUSTOMIZE_CHECKSUMS_URL {}
variable KUSTOMIZE_CHECKSUMS {}
variable KUSTOMIZE_BIN_AMD64_TGZ_URL {}
variable KUSTOMIZE_BIN_AMD64_TGZ {}
variable KUSTOMIZE_BIN_ARM64_TGZ_URL {}
variable KUSTOMIZE_BIN_ARM64_TGZ {}

# output variables
variable USER {}
variable IMAGE_NAME_REPOSITORY {
  default = ""
}
variable IMAGE_NAME_LABEL {
  default = "${USER}/hbase/kustomize/kuttl"
}
variable IMAGE_NAME_TAG {
  default = "latest"
}
variable IMAGE_TAG {
  default = "${regex_replace("${IMAGE_NAME_REPOSITORY}/${IMAGE_NAME_LABEL}:${IMAGE_NAME_TAG}", "^/+", "")}"
}

group default {
  targets = [ "kuttl", "kuttl-test" ]
}

target kuttl {
  dockerfile = "dockerfiles/kuttl/Dockerfile"
  args = {
    KUBECTL_SHA_AMD64_URL = KUBECTL_SHA_AMD64_URL
    KUBECTL_SHA_AMD64 = KUBECTL_SHA_AMD64
    KUBECTL_BIN_AMD64_URL = KUBECTL_BIN_AMD64_URL
    KUBECTL_BIN_AMD64 = KUBECTL_BIN_AMD64
    KUBECTL_SHA_ARM64_URL = KUBECTL_SHA_ARM64_URL
    KUBECTL_SHA_ARM64 = KUBECTL_SHA_ARM64
    KUBECTL_BIN_ARM64_URL = KUBECTL_BIN_ARM64_URL
    KUBECTL_BIN_ARM64 = KUBECTL_BIN_ARM64
    KUTTL_CHECKSUMS_URL = KUTTL_CHECKSUMS_URL
    KUTTL_CHECKSUMS = KUTTL_CHECKSUMS
    KUTTL_BIN_AMD64_URL = KUTTL_BIN_AMD64_URL
    KUTTL_BIN_AMD64 = KUTTL_BIN_AMD64
    KUTTL_BIN_ARM64_URL = KUTTL_BIN_ARM64_URL
    KUTTL_BIN_ARM64 = KUTTL_BIN_ARM64
    KUSTOMIZE_CHECKSUMS_URL = KUSTOMIZE_CHECKSUMS_URL
    KUSTOMIZE_CHECKSUMS = KUSTOMIZE_CHECKSUMS
    KUSTOMIZE_BIN_AMD64_TGZ_URL = KUSTOMIZE_BIN_AMD64_TGZ_URL
    KUSTOMIZE_BIN_AMD64_TGZ = KUSTOMIZE_BIN_AMD64_TGZ
    KUSTOMIZE_BIN_ARM64_TGZ_URL = KUSTOMIZE_BIN_ARM64_TGZ_URL
    KUSTOMIZE_BIN_ARM64_TGZ = KUSTOMIZE_BIN_ARM64_TGZ
  }
  target = "final"
  platforms = [ "linux/amd64" ]
  tags = [ "${IMAGE_TAG}" ]
}

target kuttl-test {
  inherits = [ "kuttl" ]
  target = "test"
  tags = []
}
