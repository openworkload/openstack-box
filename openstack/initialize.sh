#!/usr/bin/env bash
#
# This script is meant to be run once after running start for the first
# time. This script downloads a cirros image and registers it. Then it
# configures networking and nova quotas to allow 40 m1.small instances
# to be created.

IMAGE_URL=http://download.cirros-cloud.net/0.5.2/
IMAGE=cirros-0.5.2-x86_64-disk.img
IMAGE_NAME=cirros
IMAGE_TYPE=linux

EXT_NET_CIDR="172.28.128.0/24"
EXT_NET_RANGE="start=172.28.128.150,end=172.28.128.200"
EXT_NET_GATEWAY="172.28.128.2"
HORIZON_URL="172.28.128.2"

# Sanitize language settings to avoid commands bailing out
# with "unsupported locale setting" errors.
unset LANG
unset LANGUAGE
LC_ALL=C
export LC_ALL

export PATH=/usr/local/bin:$PATH

for i in curl openstack; do
    if [[ ! $(type ${i} 2>/dev/null) ]]; then
        if [ "${i}" == 'curl' ]; then
            echo "Please install ${i} before proceeding."
        else
            echo "Please install python-${i}client before proceeding."
        fi
        exit
    fi
done
# Move to top level directory
REAL_PATH=$(python -c "import os,sys;print(os.path.realpath('$0'))")
cd "$(dirname "$REAL_PATH")/.."

# Test for credentials set
if [[ "${OS_USERNAME}" == "" ]]; then
    echo "No Keystone credentials specified. Try running:\n source /etc/kolla/admin-openrc.sh"
    exit
fi

# Test to ensure configure script is run only once
if openstack image list | grep -q cirros; then
    echo "This tool should only be run once per deployment."
    exit
fi

echo "Downloading glance image."
if ! [ -f "${IMAGE}" ]; then
    curl -L -o ./${IMAGE} ${IMAGE_URL}/${IMAGE}
fi
echo "Creating glance image."
openstack image create --disk-format qcow2 --container-format bare --public \
    --property os_type=${IMAGE_TYPE} --file ./${IMAGE} ${IMAGE_NAME}

echo "Configuring neutron."
openstack network create --external --provider-physical-network physnet1 \
    --provider-network-type flat public1

openstack subnet create --no-dhcp \
    --allocation-pool ${EXT_NET_RANGE} --network public1 \
    --subnet-range ${EXT_NET_CIDR} --gateway ${EXT_NET_GATEWAY} public1-subnet

openstack network create --provider-network-type vxlan demo-net
openstack subnet create --subnet-range 10.0.0.0/24 --network demo-net \
    --gateway 10.0.0.1 --dns-nameserver 8.8.8.8 demo-subnet

openstack router create demo-router
openstack router add subnet demo-router demo-subnet
openstack router set --external-gateway public1 demo-router

# Get admin user and tenant IDs
ADMIN_USER_ID=$(openstack user list | awk '/ admin / {print $2}')
ADMIN_PROJECT_ID=$(openstack project list | awk '/ admin / {print $2}')
ADMIN_SEC_GROUP=$(openstack security group list --project ${ADMIN_PROJECT_ID} | awk '/ default / {print $2}')

# Sec Group Config
openstack security group rule create --ingress --ethertype IPv4 \
    --protocol icmp ${ADMIN_SEC_GROUP}
openstack security group rule create --ingress --ethertype IPv4 \
    --protocol tcp --dst-port 22 ${ADMIN_SEC_GROUP}
# Open heat-cfn so it can run on a different host
openstack security group rule create --ingress --ethertype IPv4 \
    --protocol tcp --dst-port 8000 ${ADMIN_SEC_GROUP}
openstack security group rule create --ingress --ethertype IPv4 \
    --protocol tcp --dst-port 8080 ${ADMIN_SEC_GROUP}

if [ ! -f ~/.ssh/id_rsa.pub ]; then
    echo "Generating ssh key."
    ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa
fi
if [ -r ~/.ssh/id_rsa.pub ]; then
    echo "Configuring nova public key."
    openstack keypair create --public-key ~/.ssh/id_rsa.pub mykey
fi

echo "Configuring nova quotas."
# 40 instances
openstack quota set --instances 40 ${ADMIN_PROJECT_ID}
# 40 cores
openstack quota set --cores 40 ${ADMIN_PROJECT_ID}
# 96GB ram
openstack quota set --ram 96000 ${ADMIN_PROJECT_ID}

# Add default flavors, if they don't already exist
if ! openstack flavor list | grep -q m1.tiny; then
    openstack flavor create --id 1 --ram 512   --disk 1   --vcpus 1 m1.micro
    openstack flavor create --id 2 --ram 1024  --disk 10  --vcpus 1 m1.tiny
    openstack flavor create --id 3 --ram 2048  --disk 20  --vcpus 1 m1.small
    openstack flavor create --id 4 --ram 4096  --disk 40  --vcpus 2 m1.medium
    openstack flavor create --id 5 --ram 8192  --disk 80  --vcpus 4 m1.large
    openstack flavor create --id 6 --ram 16384 --disk 160 --vcpus 8 m1.xlarge
fi

# Initialize ratings
openstack rating module enable hashmap

# Add flavors costs per instance
openstack rating hashmap service create compute
SERVICE_ID=$(openstack rating hashmap service list | grep compute | awk -F'|' '{ print $3}' | sed 's/ //g')

openstack rating hashmap field create ${SERVICE_ID} flavor
FIELD_ID=$(openstack rating hashmap field list ${SERVICE_ID} | grep flavor | awk -F'|' '{ print $3}' | sed 's/ //g')

openstack rating hashmap mapping create --field-id ${FIELD_ID} -t flat --value m1.micro 0.1
openstack rating hashmap mapping create --field-id ${FIELD_ID} -t flat --value m1.tiny 0.2
openstack rating hashmap mapping create --field-id ${FIELD_ID} -t flat --value m1.small 0.3

# add ingoing bandwidth costs per MB
openstack rating hashmap service create network.bw.in
SERVICE_ID=$(openstack rating hashmap service list | grep network.bw.in | awk -F'|' '{ print $3}' | sed 's/ //g')

openstack rating hashmap mapping create --service-id  ${SERVICE_ID} -t flat 0.05

# add outgoing bandwidth costs per MB
openstack rating hashmap service create network.bw.out
SERVICE_ID=$(openstack rating hashmap service list | grep network.bw.out | awk -F'|' '{ print $3}' | sed 's/ //g')

openstack rating hashmap mapping create --service-id  ${SERVICE_ID} -t flat 0.05

# add floating ip costs per IP
openstack rating hashmap service create network.floating
SERVICE_ID=$(openstack rating hashmap service list | grep network.floating | awk -F'|' '{ print $3}' | sed 's/ //g')

openstack rating hashmap mapping create --service-id  ${SERVICE_ID} -t flat 0.05

echo ""

for i in {1..5}; do
    DEMO_PROJECT_NAME="demo$i"
    DEMO_USERNAME=${DEMO_PROJECT_NAME}
    DEMO_PASSWORD=${DEMO_PROJECT_NAME}

    # Create demo project with name ${DEMO_PROJECT_NAME} with parent ${OS_PROJECT_DOMAIN_NAME} project
    echo "Create project '${DEMO_PROJECT_NAME}'."
    openstack project create ${DEMO_PROJECT_NAME} --domain ${OS_PROJECT_DOMAIN_NAME} \
        --description "The demo project ${DEMO_PROJECT_NAME}"
    DEMO_PROJECT_ID=$(openstack project list | grep ${DEMO_PROJECT_NAME} | awk '{print $2}')

    echo "Create user '${DEMO_USERNAME}' with password '${DEMO_PASSWORD}'."
    openstack user create --domain $OS_PROJECT_DOMAIN_NAME --project ${DEMO_PROJECT_NAME} \
        --password $DEMO_PASSWORD ${DEMO_USERNAME}
    DEMO_USER_ID=$(openstack user list | grep ${DEMO_USERNAME} | awk '{print $2}')

    # Assing user roles to ${DEMO_PROJECT_NAME}
    openstack role add --project ${DEMO_PROJECT_NAME} --user ${DEMO_USERNAME} rating
    openstack role add --project ${DEMO_PROJECT_NAME} --user ${DEMO_USERNAME} heat_stack_owner

    # We temporary add admin role as a workaround to allow the demo users to get
    # different information from OpenStack API.
    # FIXME: get rid of the role assignment:
    openstack role add --project ${DEMO_PROJECT_NAME} --user ${DEMO_USERNAME} admin

    echo "Configuring nova public key user '${DEMO_USERNAME}'."
    OS_PROJECT_NAME=${DEMO_PROJECT_NAME} \
    OS_TENANT_NAME=${DEMO_PROJECT_NAME} \
    OS_USERNAME=${DEMO_USERNAME} \
    OS_PASSWORD=${DEMO_PASSWORD} \
        openstack keypair create ${DEMO_USERNAME} > ~/.ssh/${DEMO_USERNAME}.pem
    chmod 400  ~/.ssh/${DEMO_USERNAME}.pem

    echo "Configuring neutron for '${DEMO_PROJECT_NAME}'."
    openstack network create --project ${DEMO_PROJECT_NAME} --provider-network-type vxlan ${DEMO_PROJECT_NAME}-net
    openstack subnet create --project ${DEMO_PROJECT_NAME} --subnet-range 10.0.0.0/24 --network ${DEMO_PROJECT_NAME}-net \
        --gateway 10.0.0.1 --dns-nameserver 8.8.8.8 ${DEMO_PROJECT_NAME}-subnet

    openstack router create --project ${DEMO_PROJECT_NAME} ${DEMO_PROJECT_NAME}-router
    openstack router add subnet ${DEMO_PROJECT_NAME}-router ${DEMO_PROJECT_NAME}-subnet
    openstack router set --external-gateway public1 ${DEMO_PROJECT_NAME}-router

    echo "Configuring nova quotas for '${DEMO_PROJECT_NAME}'."
    # 10 instances
    openstack quota set --instances 100 ${DEMO_PROJECT_ID}
    # 10 cores
    openstack quota set --cores 1000 ${DEMO_PROJECT_ID}
    # 20GB ram
    openstack quota set --ram 2000000 ${DEMO_PROJECT_ID}

    echo "Configuring cloudkitty pricing for '${DEMO_PROJECT_NAME}.'"
    # Add flavors costs per instance
    SERVICE_ID=$(openstack rating hashmap service list | grep compute | awk -F'|' '{ print $3}' | sed 's/ //g')
    FIELD_ID=$(openstack rating hashmap field list ${SERVICE_ID} | grep flavor | awk -F'|' '{ print $3}' | sed 's/ //g')

    openstack rating hashmap mapping create --project-id ${DEMO_PROJECT_ID} --field-id ${FIELD_ID} -t flat --value m1.micro 0.1
    openstack rating hashmap mapping create --project-id ${DEMO_PROJECT_ID} --field-id ${FIELD_ID} -t flat --value m1.tiny 0.2
    openstack rating hashmap mapping create --project-id ${DEMO_PROJECT_ID} --field-id ${FIELD_ID} -t flat --value m1.small 0.3

    # Add ingoing bandwidth costs per MB
    SERVICE_ID=$(openstack rating hashmap service list | grep network.bw.in | awk -F'|' '{ print $3}' | sed 's/ //g')

    openstack rating hashmap mapping create --project-id ${DEMO_PROJECT_ID} --service-id ${SERVICE_ID} -t flat 0.05

    # Add outgoing bandwidth costs per MB
    SERVICE_ID=$(openstack rating hashmap service list | grep network.bw.out | awk -F'|' '{ print $3}' | sed 's/ //g')

    openstack rating hashmap mapping create --project-id ${DEMO_PROJECT_ID} --service-id ${SERVICE_ID} -t flat 0.05

    # Add floating ip costs per IP
    SERVICE_ID=$(openstack rating hashmap service list | grep network.floating | awk -F'|' '{ print $3}' | sed 's/ //g')

    openstack rating hashmap mapping create --project-id ${DEMO_PROJECT_ID} --service-id ${SERVICE_ID} -t flat 0.05
done

DEMO_NET_ID=$(openstack network list | awk '/ demo-net / {print $2}')

cat << EOF

Done.

To deploy a demo instance, run:

source /etc/kolla/admin-openrc.sh

openstack server create \\
    --image ${IMAGE_NAME} \\
    --flavor m1.tiny \\
    --key-name mykey \\
    --nic net-id=${DEMO_NET_ID} \\
    demo1

The Horizon dashboard available at http://${HORIZON_URL}/ with username '${OS_USERNAME}' and password '${OS_PASSWORD}'
EOF

echo "Dashboard: http://${HORIZON_URL}\nusername: ${OS_USERNAME}\npassword: ${OS_PASSWORD}" > ~/admin-credentials.txt

for i in {1..5}; do
    DEMO_PROJECT_NAME="demo$i"
    DEMO_USERNAME=${DEMO_PROJECT_NAME}
    DEMO_PASSWORD=${DEMO_PROJECT_NAME}
    echo "or with username '${DEMO_USERNAME}' and password '${DEMO_PASSWORD}'"
done

exit 0
