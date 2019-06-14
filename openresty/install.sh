if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

VER=openresty-1.13.6.1
STREAM_VER=0.0.3
OPS_DIR=/opt/ops
PREFIX=/usr/local/openresty
BUILD_DIR=/tmp

# certbot

apt-get install software-properties-common -y
add-apt-repository ppa:certbot/certbot -y
apt-get update
apt-get install certbot -y

# env
apt-get install libreadline-dev libncurses5-dev libpcre3-dev libssl-dev perl make build-essential -y

# stream module
cd $BUILD_DIR
wget -O stream-lua-nginx-module.tar.gz https://github.com/openresty/stream-lua-nginx-module/archive/v$STREAM_VER.tar.gz
tar xzvf stream-lua-nginx-module.tar.gz
rm stream-lua-nginx-module.tar.gz

# openresty
wget https://openresty.org/download/$VER.tar.gz
tar xzvf $VER.tar.gz
cd $VER

./configure --prefix=/usr/local/openresty \
--with-luajit \
--with-pcre-jit \
--with-stream_ssl_module \
--with-stream_ssl_preread_module \
--with-http_v2_module \
--without-mail_pop3_module \
--without-mail_imap_module \
--without-mail_smtp_module \
--with-http_stub_status_module \
--with-http_realip_module \
--with-http_addition_module \
--with-http_auth_request_module  \
--with-http_secure_link_module \
--with-http_random_index_module \
--with-http_gzip_static_module \
--with-http_sub_module \
--with-http_dav_module \
--with-http_flv_module \
--with-http_mp4_module \
--with-http_gunzip_module \
--with-threads \
--with-dtrace-probes \
--with-stream \
--with-stream_ssl_preread_module \
--with-http_ssl_module \
--with-http_iconv_module \
--with-http_slice_module \
--add-module=/tmp/stream-lua-nginx-module-$STREAM_VER

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
    --lua-suffix=jit-2.1.0-beta3 \
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

# clean up
