#!/bin/bash

function fail(){
    printf "$*"
    exit
}
yum -y install policycoreutils-python
rpm -q policycoreutils-python || fail "Failed to install required packages"
semanage port -a -t http_port_t -p tcp 8050
semanage port -a -t http_port_t -p tcp 8051
semanage port -a -t http_port_t -p tcp 8052
setsebool -P httpd_can_network_connect 1

systemctl stop firewalld
systemctl disable firewalld


yum -y install epel-release wget || fail "EPEL Required"
yum -y install centos-release-scl centos-release-scl-rh || fail "Failed to install Software Collections"

#### AWX Repository:

echo "[mrmeee-ansible-awx]
name=Copr repo for ansible-awx owned by mrmeee
baseurl=https://copr-be.cloud.fedoraproject.org/results/mrmeee/ansible-awx/epel-7-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://copr-be.cloud.fedoraproject.org/results/mrmeee/ansible-awx/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1" | sudo tee /etc/yum.repos.d/ansible-awx.repo > /dev/null || fail "Error: unable to setup Ansible AWX Repo."

#### RabbitMQ and Erlang Repositories:

echo "[bintraybintray-rabbitmq-rpm] 
name=bintray-rabbitmq-rpm 
baseurl=https://dl.bintray.com/rabbitmq/rpm/rabbitmq-server/v3.7.x/el/7/
gpgcheck=0 
repo_gpgcheck=0 
enabled=1" |sudo tee  /etc/yum.repos.d/rabbitmq.repo > /dev/null || fail "Error: unable to setup rabbitmq repo"


echo "[bintraybintray-rabbitmq-erlang-rpm] 
name=bintray-rabbitmq-erlang-rpm 
baseurl=https://dl.bintray.com/rabbitmq-erlang/rpm/erlang/21/el/7/
gpgcheck=0 
repo_gpgcheck=0 
enabled=1" |sudo tee /etc/yum.repos.d/rabbitmq-erlang.repo > /dev/null || fail "Error: unable to setup erlang repo"

#### Installation:

echo "01- Install RabbitMQ and Git:"
yum -y install rabbitmq-server rh-git29
systemctl enable rabbitmq-server && systemctl start rabbitmq-server

echo "02- Install PostgreSQL, Initialize db && create awx db and user:"
yum install -y rh-postgresql10
scl enable rh-postgresql10 "postgresql-setup initdb"
systemctl start rh-postgresql10-postgresql.service && systemctl enable rh-postgresql10-postgresql.service
scl enable rh-postgresql10 "su postgres -c \"createuser -S awx\""
scl enable rh-postgresql10 "su postgres -c \"createdb -O awx awx\""

echo "03- Install memcached:"
yum install -y memcached
systemctl enable memcached && systemctl start memcached

echo "04- Install & configure NGINX:"
yum -y install nginx
cp -p /etc/nginx/nginx.conf{,.org}
wget -O /etc/nginx/nginx.conf https://raw.githubusercontent.com/faudeltn/AnsibleTower-awx/master/ansible-awx-install/nginx.conf
systemctl enable nginx && systemctl start nginx

echo "05- Install Python and dependcies:"
yum -y install rh-python36
yum -y install --disablerepo='*' --enablerepo='mrmeee-ansible-awx, base' -x *-debuginfo rh-python36*

echo "06- Install AWX-RPM:"
yum install -y ansible-awx

echo "07- Initialize AWX:"
sudo -u awx scl enable rh-python36 rh-postgresql10 rh-git29 "GIT_PYTHON_REFRESH=quiet awx-manage migrate"
echo "from django.contrib.auth.models import User; User.objects.create_superuser('admin', 'root@localhost', 'password')" | sudo -u awx scl enable rh-python36 rh-postgresql10 "GIT_PYTHON_REFRESH=quiet awx-manage shell"
sudo -u awx scl enable rh-python36 rh-postgresql10 rh-git29 "GIT_PYTHON_REFRESH=quiet awx-manage create_preload_data" # Optional Sample Configuration
sudo -u awx scl enable rh-python36 rh-postgresql10 rh-git29 "GIT_PYTHON_REFRESH=quiet awx-manage provision_instance --hostname=$(hostname)"
sudo -u awx scl enable rh-python36 rh-postgresql10 rh-git29 "GIT_PYTHON_REFRESH=quiet awx-manage register_queue --queuename=tower --hostnames=$(hostname)"

echo "08- Enable and Start AWX:"
systemctl enable awx
systemctl start awx
