<!--
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
-->

# Tests

Kustomization tests are implemented using the [Kuttl](https://kuttl.dev/) testing harness. Tests
are divided into two groups: unit and integration.

The unit test environment is light-weight and built on Kuttl's [Mocked Control
Plane](https://kuttl.dev/docs/testing/test-environments.html#mocked-control-plane) feature. The
tests themselves are limited to assertions based on the structure of resource requests made to the
kube API server.

Integration tests can also be considered end-to-end tests. They rely on a "real", multi-node
kubernetes environment, be it a small [KinD](https://kind.sigs.k8s.io/) or
[MiniKube](https://minikube.sigs.k8s.io/) deployment or a fully distributed Kubernetes
cluster. Integration tests expect to see the results of the requests made against the API server
and make assertions of the presence of running Hadoop application processes. As such, the
integration testing environment must provide compute resources sufficient to run a small
HBase cluster.

In both cases, tests are run using Kuttl. While you can install kuttl locally, it is recommended
that you use the `kuttl` container image provided by this project. It is described in
[dockerfiles/kuttl/README.md](../dockerfiles/kuttl/README.md). The following examples assume that
you have built the image locally.

## Unit Tests

Running tests in the `kuttl` image requires mounting the workspace into the container runtime and
passing appropriate parameters to `kuttl`. Run the unit tests like this:

```shell
% docker container run \
  --mount type=bind,source=$(pwd),target=/workspace \
  --workdir /workspace \
  ${USER}/hbase/kustomize/kuttl:latest \
  --config tests/kuttl-test-unit.yaml
=== RUN   kuttl
    harness.go:462: starting setup
    harness.go:246: running tests with a mocked control plane (kube-apiserver and etcd).
...
--- PASS: kuttl (5.81s)
    --- PASS: kuttl/harness (0.00s)
        --- PASS: kuttl/harness/base (1.35s)
        --- PASS: kuttl/harness/overlays_hdfs (1.40s)
PASS
```

## Integration Tests

This directory defines a set of tests that are suitable for running against a target cluster --
they are not too resource intensive and do not require any vendor-specific extensions. It should
be possible to run these tests against a multi-node KinD cluster, below are some notes to help a
developer to run them locally.

### Run the tests locally

Assumes a Docker Desktop or some other docker-in-docker type of environment. First, prepare your
cluster connection details such that they can be passed into the container context. Next, launch
the test runner in a container:

```shell
$ docker container run \
  --env KUBECONFIG=/workspace/your-kubeconfig \
  --mount type=bind,source=$(PWD),target=/workspace \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --workdir /workspace \
  ${USER}/hbase/kustomize/kuttl:latest \
  --config tests/kuttl-test-integration.yaml \
  --parallel 1
```

### Run the tests in AWS EKS

It is possible to run these tests in AWS EKS. This requires configuring an RBAC on your target
cluster that maps to an AIM profile. Next, define a profile in AWS configuration. When you launch
the container, pass configuration and profile selection through to the running container.

Building on the previous example,

```shell
$ docker container run \
  --env AWS_PROFILE="your-profile" \
  --env KUBECONFIG=/workspace/your-kubeconfig \
  --mount type=bind,source=$(PWD),target=/workspace \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v ~/.aws:/root/.aws \
  --workdir /workspace \
  ${USER}/hbase/kustomize/kuttl:latest \
  --config tests/kuttl-test-integration.yaml
```

### Prepare a KinD cluster

Ask KinD to create a cluster (and docker network), and export the configuration oriented as from
inside the cluster. Start by creating a kind-config.yaml and configuring it for muliple nodes.
See https://kind.sigs.k8s.io/docs/user/quick-start/#configuring-your-kind-cluster

```shell
$ kind create cluster --config kind-config.yaml
...
You can now use your cluster with:

kubectl cluster-info --context kind --kubeconfig kubeconfig
$ kind export kubeconfig --name kind --internal --kubeconfig kubeconfig-internal
```

### Local KinD Hacks

Preparing and staging the large container images into the kind nodes is slow. Speed up the process
a bit by creating a single-node KinD cluster and letting `kuttl` populate the images you need.

First, find all the images used in your tests,

```shell
$ find tests/kind -type f -iname '*kustomization.yaml' \
    -exec yq '.images[] | .newName + ":" + .newTag' {} + \
  | sort -u
hadoop:...
hbase:...
zookeeper:...
```

Pull those images locally.

```shell
$ docker image pull hadoop:...
$ docker image pull hbase:...
$ docker image pull zookeeper:...
```

Now make sure kuttl is using a docker volume for the containerd directory on each container, and
populate those images into your kuttl configuration using this config snippet:

```yaml
kindNodeCache:
  # Have kuttl create and mount volumes for a container image cache to each kind pod. Kuttl will
  # reuse these mounts across runs, so we can save time the next the tests run.
  true
kindContainers:
  # pre-populate the kind containers with these images pulled from the host registry. They'll be
  # cached via `kindNodeCache`.
- hadoop...
- hbase...
- zookeeper:...
```

When you run `kuttl` with this config, you'll see that it has mounted a volume for each container.
It'll take a while, but `kuttl` will report its progress copying these container images.

```
== RUN   kuttl
...
    harness.go:202: node mount point /var/lib/docker/volumes/kind-0/_data
...
    harness.go:155: Starting KIND cluster
    kind.go:66: Adding Containers to KIND...
    kind.go:75: Add image zookeeper:... to node control-plane
...
```

Once copied into one volume, create all the additional volumes you'll need and clone the original.
Repeat this for every worker node you'd like in your cluster.

```shell
$ docker volume create --name kind-1
$ docker container run --rm -it \
  -v kind-0:/from \
  -v kind-1:/to \
  alpine ash -c "cd /from ; cp -a . /to"
```

In `kind-config.yaml`, specify the mount points for each of your KinD processes.

```yaml
nodes:
- role: control-plane
  extraMounts:
  - &extra-mounts
    hostPath: /var/lib/docker/volumes/kind-0/_data
    containerPath: /var/lib/containerd
    readOnly: false
    propagation: HostToContainer
- role: worker
  extraMounts:
  - <<: *extra-mounts
    hostPath: /var/lib/docker/volumes/kind-1/_data
...
```
