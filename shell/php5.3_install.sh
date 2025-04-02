#!/bin/bash

# 替换为CentOS vault镜像源（确保安装脚本中也有这个配置）
cd /etc/yum.repos.d/
sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
yum clean all

# 安装依赖 (CentOS 7版本)
yum update -y
yum install -y \
    gcc gcc-c++ make \
    libxml2-devel \
    libjpeg-devel \
    libpng-devel \
    freetype-devel \
    libmcrypt-devel \
    mhash-devel \
    libcurl-devel \
    openssl-devel \
    curl \
    bzip2-devel \
    libc-client-devel \
    krb5-devel \
    libicu-devel \
    gmp-devel \
    autoconf \
    bison \
    re2c

# 创建www用户和用户组
groupadd -r www
useradd -r -g www -s /sbin/nologin -d /usr/local/php -M www

# 下载并解压PHP 5.3.29
cd /tmp
curl -o php-5.3.29.tar.gz https://www.php.net/distributions/php-5.3.29.tar.gz
tar zxf php-5.3.29.tar.gz
cd php-5.3.29

# 修复PHP 5.3在现代系统上的编译问题
# 修复openssl问题
sed -i 's#(\*gcm=\*)#(*gcm=*), (*aes\*), (*ctr\*)#' ext/openssl/openssl.c

# 修复GCC较新版本的编译问题
sed -i 's/-n32/-D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64/g' configure
sed -i 's/ZEND_EXTRA_LIBS="$ZEND_EXTRA_LIBS -lpthread"/ZEND_EXTRA_LIBS="$ZEND_EXTRA_LIBS -lpthread -lrt"/g' configure

# 修复CentOS 7下编译问题
mkdir -p /usr/include/libc-client/
ln -s /usr/lib64/libc-client.so /usr/lib/libc-client.so
ln -s /usr/include/c-client/* /usr/include/libc-client/

# 配置并编译PHP
./configure \
  --prefix=/usr/local/php \
  --with-config-file-path=/usr/local/php/etc \
  --with-mysql=/usr/local/mysql \
  --with-mysqli=/usr/local/mysql/bin/mysql_config \
  --with-pdo-mysql=/usr/local/mysql \
  --with-iconv-dir \
  --with-freetype-dir \
  --with-jpeg-dir \
  --with-png-dir \
  --with-zlib \
  --with-libxml-dir=/usr \
  --enable-xml \
  --disable-rpath \
  --enable-bcmath \
  --enable-shmop \
  --enable-sysvsem \
  --enable-inline-optimization \
  --with-curl \
  --enable-mbregex \
  --enable-fpm \
  --enable-mbstring \
  --with-mcrypt \
  --with-gd \
  --enable-gd-native-ttf \
  --with-openssl \
  --with-mhash \
  --enable-pcntl \
  --enable-sockets \
  --with-xmlrpc \
  --enable-zip \
  --enable-soap \
  --without-pear \
  --with-gettext \
  --disable-fileinfo \
  --enable-maintainer-zts

# 编译并安装
make ZEND_EXTRA_LIBS='-liconv -lrt'
make install

# 配置PHP
cp php.ini-production /usr/local/php/etc/php.ini
cd /usr/local/php/etc
cp php-fpm.conf.default php-fpm.conf
sed -i 's/;pid = run\/php-fpm.pid/pid = run\/php-fpm.pid/' php-fpm.conf
sed -i 's/;error_log = log\/php-fpm.log/error_log = log\/php-fpm.log/' php-fpm.conf
sed -i 's/;log_level = notice/log_level = notice/' php-fpm.conf

# 配置www.conf
cd /usr/local/php/etc/php-fpm.d
cp www.conf.default www.conf
sed -i 's/;listen.owner = nobody/listen.owner = www/' www.conf
sed -i 's/;listen.group = nobody/listen.group = www/' www.conf
sed -i 's/user = nobody/user = www/' www.conf
sed -i 's/group = nobody/group = www/' www.conf
sed -i 's/^;pm.max_requests = 500/pm.max_requests = 500/' www.conf
sed -i 's/^;listen.mode = 0660/listen.mode = 0660/' www.conf

# 创建日志目录和日志文件
mkdir -p /usr/local/php/logs
touch /usr/local/php/logs/php-fpm.log
chown -R www:www /usr/local/php/logs

# 设置PHP-FPM启动脚本
# 检查是否存在init.d脚本
if [ -f "/tmp/php-5.3.29/sapi/fpm/init.d.php-fpm" ]; then
    cp /tmp/php-5.3.29/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
else
    # 如果不存在，手动创建启动脚本
    echo '#!/bin/sh' > /etc/init.d/php-fpm
    echo 'php_fpm_BIN=/usr/local/php/sbin/php-fpm' >> /etc/init.d/php-fpm
    echo 'php_fpm_CONF=/usr/local/php/etc/php-fpm.conf' >> /etc/init.d/php-fpm
    echo 'php_fpm_PID=/usr/local/php/var/run/php-fpm.pid' >> /etc/init.d/php-fpm
    echo '' >> /etc/init.d/php-fpm
    echo 'case "$1" in' >> /etc/init.d/php-fpm
    echo '    start)' >> /etc/init.d/php-fpm
    echo '        echo -n "Starting php-fpm "' >> /etc/init.d/php-fpm
    echo '        $php_fpm_BIN' >> /etc/init.d/php-fpm
    echo '        echo " done"' >> /etc/init.d/php-fpm
    echo '        ;;' >> /etc/init.d/php-fpm
    echo '    stop)' >> /etc/init.d/php-fpm
    echo '        echo -n "Stopping php-fpm "' >> /etc/init.d/php-fpm
    echo '        if [ -r $php_fpm_PID ]; then' >> /etc/init.d/php-fpm
    echo '            kill -QUIT `cat $php_fpm_PID`' >> /etc/init.d/php-fpm
    echo '        else' >> /etc/init.d/php-fpm
    echo '            echo "Warning: Not running."' >> /etc/init.d/php-fpm
    echo '        fi' >> /etc/init.d/php-fpm
    echo '        echo " done"' >> /etc/init.d/php-fpm
    echo '        ;;' >> /etc/init.d/php-fpm
    echo '    restart)' >> /etc/init.d/php-fpm
    echo '        $0 stop' >> /etc/init.d/php-fpm
    echo '        $0 start' >> /etc/init.d/php-fpm
    echo '        ;;' >> /etc/init.d/php-fpm
    echo '    *)' >> /etc/init.d/php-fpm
    echo '        echo "Usage: $0 {start|stop|restart}"' >> /etc/init.d/php-fpm
    echo '        exit 1' >> /etc/init.d/php-fpm
    echo '        ;;' >> /etc/init.d/php-fpm
    echo 'esac' >> /etc/init.d/php-fpm
fi

chmod +x /etc/init.d/php-fpm

# 创建必要的目录
mkdir -p /usr/local/php/var/run
chown -R www:www /usr/local/php/var

# 设置PHP-FPM开机启动
chkconfig --add php-fpm
chkconfig php-fpm on

# 添加PHP二进制文件到PATH
echo 'export PATH=$PATH:/usr/local/php/bin:/usr/local/php/sbin' > /etc/profile.d/php.sh
chmod +x /etc/profile.d/php.sh
source /etc/profile.d/php.sh

echo "PHP 5.3.29 安装完成"
