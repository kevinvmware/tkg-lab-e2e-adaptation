#!/bin/bash

# Lab Setup...

# Open two terminals
# Terminal 1

# Set context to tbs cluster

# Delete current image
kp image delete spring-petclinic -n tbs-project-petclinic

# Go to harbor and delete all repositories in your petclinic project

# To simplify some of the commands later (depend on your PARAMS_YAML env var)
cd workspace/tkg-lab-e2e-adaptation/
export PARAMS_YAML=local-config/params.yaml

export TBS_REPOSITORY=$(yq r $PARAMS_YAML tbs.harborRepository)
export HARBOR_DOMAIN=$(yq r $PARAMS_YAML commonSecrets.harborDomain)

# Rest cluster stack to make it match with 100.0.22
kp clusterstack update demo-stack  \
  --build-image $TBS_REPOSITORY/build@sha256:ee37e655a4f39e2e6ffa123306db0221386032d3e6e51aac809823125b0a400e \
  --run-image $TBS_REPOSITORY/run@sha256:51cebe0dd77a1b09934c4ce407fb07e3fc6f863da99cdd227123d7bfc7411efa

cd ../spring-petclinic
./mvnw clean package -D skipTests

# Terminal 2
watch kp build list spring-petclinic -n tbs-project-petclinic

# ------------------------------------------------
# Create an image and then update it
# ------------------------------------------------

# Let's start by creating an image. At this point we have TBS installed and Harbor registry credentials configured
kp image create spring-petclinic --tag $HARBOR_DOMAIN/petclinic/spring-petclinic \
 --cluster-builder demo-cluster-builder \
 --namespace tbs-project-petclinic \
 --local-path target/spring-petclinic-2.4.0.BUILD-SNAPSHOT.jar

# Check images
kp image list -n tbs-project-petclinic
# Check builds
kp build list spring-petclinic -n tbs-project-petclinic
# Check build logs
kp build logs spring-petclinic -b 1 -n tbs-project-petclinic
# Let's observe the stages of the build from ^^^^

# Let's make a quick code change and push it
vi src/main/resources/templates/welcome.html
./mvnw clean package -D skipTests

kp image patch spring-petclinic \
 --namespace tbs-project-petclinic \
 --local-path target/spring-petclinic-2.4.0.BUILD-SNAPSHOT.jar

# Check Harbor again for a new image

kp build logs spring-petclinic -b 2 -n tbs-project-petclinic

# ------------------------------------------------
# Explore the build service central configuration
# ------------------------------------------------

# Explore stores
kp clusterstore list
kp clusterstore status default
# Explore stacks
kp clusterstack list
kp clusterstack status demo-stack
# Explore builders
kp clusterbuilder list
kp clusterbuilder status demo-cluster-builder

# ------------------------------------------------
# Inspect image for metadata for traceability and auditability
# ------------------------------------------------

# Discuss Tanzu continually posting updates
open https://network.pivotal.io/products/tbs-dependencies/

# Discuss how you can download the descriptor and then run a command like (but don't actually run)
# This process can easily be automated with a CI tool like Concourse
kp import -f ~/Downloads/descriptor-100.0.55.yaml

# Update cluster stack to make it match with 100.0.55
kp clusterstack update demo-stack \
 --build-image $TBS_REPOSITORY/build@sha256:cf87e6b7e69c5394440c11d41c8d46eade57d13236e4fb79c80227cc15d33abf \
 --run-image $TBS_REPOSITORY/run@sha256:52a9a0002b16042b4d34382bc244f9b6bf8fd409557fe3ca8667a5a52da44608
# Image rebuild

# Check logs this time
kp build logs spring-petclinic -b3

# Check Harbor again for a new image with less vulnerabilities

# ------------------------------------------------
# Inspect image for metadata for traceability and auditability
# ------------------------------------------------

# Show result of a Dockerfile image
docker pull $HARBOR_DOMAIN/concourse/concourse-helper
docker inspect $HARBOR_DOMAIN/concourse/concourse-helper

# Now show a TBS built image

export MOST_RECENT_SUCCESS_IMAGE=$(kp build list spring-petclinic | grep SUCCESS | tail -1 | awk '{print $(3)}')
docker pull $MOST_RECENT_SUCCESS_IMAGE

docker inspect $MOST_RECENT_SUCCESS_IMAGE
# Discuss the sheer amount of metadata, baked right into the image itself

docker inspect $MOST_RECENT_SUCCESS_IMAGE | jq ".[].Config.Labels.\"io.buildpacks.build.metadata\" | fromjson"
# Can be parsed

docker inspect $MOST_RECENT_SUCCESS_IMAGE | jq ".[].Config.Labels.\"io.buildpacks.build.metadata\" | fromjson | .buildpacks"
# And even more specific example, which buildpacks
