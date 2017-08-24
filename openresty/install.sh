if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

VER=openresty-1.11.2.3
OPS_DIR=/opt/ops
PREFIX=/usr/local/openresty
BUILD_DIR=/tmp

# certbot

apt-get install software-properties-common
add-apt-repository ppa:certbot/certbot
apt-get update
apt-get install certbot 

# env
apt-get install libreadline-dev libncurses5-dev libpcre3-dev libssl-dev perl make build-essential -y

# stream module
cd $BUILD_DIR
wget https://github.com/openresty/stream-lua-nginx-module/archive/master.zip
unzip master
rm $VER.tar.gz
rm -rf $VER

# openresty
wget https://openresty.org/download/$VER.tar.gz
tar xzvf $VER.tar.gz
cd $VER

./configure \
--with-pcre-jit \
--with-ipv6 \
--with-http_realip_module \
--with-http_iconv_module \
--with-pcre-jit \
--with-ipv6 \
--with-http_ssl_module \
--with-http_stub_status_module \
--with-stream \
--with-stream_ssl_module \
--add-module=/tmp/stream-lua-nginx-module-master \

make
make install
ln -s /usr/local/openresty/nginx/sbin/nginx /usr/sbin

# luarocks
LUAROCKS=luarocks-2.4.1
cd $BUILD_DIR
wget -c http://keplerproject.github.io/luarocks/releases/$LUAROCKS.tar.gz
tar -xzvf $LUAROCKS.tar.gz
cd $LUAROCKS
./configure --prefix=/usr/local/openresty/luajit \
    --with-lua=/usr/local/openresty/luajit/ \
    --lua-suffix=jit-2.1.0-beta2 \
    --with-lua-include=/usr/local/openresty/luajit/include/luajit-2.1
make build
make install

ln -sf $PREFIX/nginx/sbin/nginx /usr/local/bin/nginx
ln -sf $PREFIX/luajit/bin/luarocks /usr/local/bin/luarocks

# log
mkdir -p /var/log/nginx

# nginx conf
mkdir -p $PREFIX/nginx/conf/sites-enabled

# logrotate
cp $OPS_DIR/openresty/files/logrotate /etc/logrotate.d/nginx
# nginx
cp $OPS_DIR/openresty/files/nginx.conf $PREFIX/nginx/conf/nginx.conf
# service
cp $OPS_DIR/openresty/files/nginx /etc/init.d/nginx
update-rc.d nginx defaults

