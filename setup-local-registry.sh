#!/usr/bin/env bash

REGISTRY_VERSION=2
REGISTRY_PORT=6006
TEST_CONT_IMAGE=jupyter/datascience-notebook:hub-3.1.1

CERT_DIR=/home/vagrant/docker_certs
CERT_DAYS=3650
CERT_SUBJ="/C=US/ST=MA/L=Boston/O=OpenWorkload/OU=Dev/CN=openworkload.org"

echo "Generate self signed certificate"
mkdir -p $CERT_DIR
pushd $CERT_DIR
openssl req -newkey rsa:4096 -nodes -sha256 -keyout $CERT_DIR/domain.key -x509 -days $CERT_DAYS -out $CERT_DIR/domain.crt -subj $CERT_SUBJ  -extensions v3_req
popd


echo "Start local registry as docker container"
docker run\
  -d\
  -e REGISTRY_HTTP_ADDR=0.0.0.0:$REGISTRY_PORT\
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt\
  -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key\
  -v$CERT_DIR:/auth\
  -w /auth\
  --net=host\
  --restart=always\
  --name=registry\
  registry:$REGISTRY_VERSION

echo
echo "Pull test container image to local docker: $TEST_CONT_IMAGE"
docker pull $TEST_CONT_IMAGE
docker image tag $TEST_CONT_IMAGE localhost:$REGISTRY_PORT/$TEST_CONT_IMAGE

echo
echo "Push the test container image to the local registry: $TEST_CONT_IMAGE"
docker push localhost:$REGISTRY_PORT/$TEST_CONT_IMAGE

echo
echo "Remove local container images: $TEST_CONT_IMAGE localhost:$REGISTRY_PORT/$TEST_CONT_IMAGE"
docker rmi $TEST_CONT_IMAGE localhost:$REGISTRY_PORT/$TEST_CONT_IMAGE

exit 0
