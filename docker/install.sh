if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

OPS_DIR=/opt/ops

# docker-ce
apt-get update
apt-get -y install software-properties-common
apt-get -y install apt-transport-https ca-certificates curl
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository \
       "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
       $(lsb_release -cs) \
       stable"
apt-get update
apt-get -y install docker-ce

# logrotate
cp $OPS_DIR/docker/files/logrotate /etc/logrotate.d/docker-container

# docker-compose
apt-get install python3-pip
pip3 install docker-compose
