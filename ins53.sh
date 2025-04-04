#!/bin/bash
# filepath: /workspaces/lnmp/ins53.sh
# 说明：本脚本基于 LNMP 安装流程，针对 PHP 5.3（例如 php-5.3.29）在 CentOS7 下的安装。
# 请确保当前目录（cur_dir）包含所需的源代码包及补丁文件，并且已经设置好 Download_Mirror 及其它变量。
# 此脚本仅供参考，部分函数为 LNMP 内部函数，此处做了简单实现。

# 输出蓝色字体
Echo_Blue() {
    echo -e "\e[34m$*\e[0m"
}

# 检查是否安装 curl
Check_Curl() {
    if ! command -v curl >/dev/null 2>&1; then
        echo "curl 未安装，请先安装 curl。"
        exit 1
    fi
}

# 解压并进入目录（解压 tar.bz2 文件）
Tar_Cd() {
    tar -jxf "$1"
    cd "$2" || exit 1
}

# 为 PHP 创建软链接，方便系统调用
Ln_PHP_Bin() {
    ln -sf /usr/local/php/bin/php /usr/bin/php
}

# 检查 PHP 安装后的关键文件（此处为占位函数，可根据需求扩展）
Check_PHP_Upgrade_Files() {
    echo "检查 PHP 安装文件...完成。"
}

# 主流程开始
# 设置 PHP 版本，这里以 php-5.3.29 为例
Php_Ver="php-5.3.29"
cur_dir=$(pwd)
Stack="lnmp"  # 表示 LNMP 堆栈

Echo_Blue "[+] 开始安装 ${Php_Ver} ..."

# 1. 检查 curl
Check_Curl

# 2. 解压 PHP 源代码包，进入源代码目录
Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}

# 3. 应用 multipart/form-data 补丁
patch -p1 < ${cur_dir}/src/patch/php-5.3-multipart-form-data.patch

# 4. 如果使用 LNMP 堆栈，则应用 PHP-FPM 补丁
if [ "${Stack}" = "lnmp" ]; then
    gzip -cd ${Php_Ver}-fpm-0.5.14.diff.gz | patch -d ${Php_Ver} -p1
fi

# 5. 进入 PHP 源代码目录
cd ${Php_Ver} || exit 1

# 6. 配置 PHP 编译参数（以下参数为示例，可根据实际情况调整）
./configure --prefix=/usr/local/php \
    --with-config-file-path=/usr/local/php/etc \
    --with-config-file-scan-dir=/usr/local/php/conf.d \
    --enable-fpm --with-fpm-user=www --with-fpm-group=www \
    --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd \
    --with-iconv-dir \
    --with-freetype=/usr/local/freetype \
    --with-jpeg --with-png --with-zlib \
    --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem

# 7. 编译并安装 PHP
make && make install
cd ..  # 返回上级目录

# 8. 建立 php 二进制软链接
Ln_PHP_Bin

# 9. 复制 php.ini-production 至配置目录，并创建 conf.d 目录
mkdir -p /usr/local/php/{etc,conf.d}
cp ${Php_Ver}/php.ini-production /usr/local/php/etc/php.ini

# 10. 修改 php.ini 参数
sed -i 's/post_max_size =.*/post_max_size = 50M/g' /usr/local/php/etc/php.ini
sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' /usr/local/php/etc/php.ini
sed -i 's/;date.timezone =.*/date.timezone = PRC/g' /usr/local/php/etc/php.ini
sed -i 's/short_open_tag =.*/short_open_tag = On/g' /usr/local/php/etc/php.ini
sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' /usr/local/php/etc/php.ini

# 11. 启动 PHP 服务（假设已有 lnmp 脚本启动全部服务）
lnmp start

# 12. 检查 PHP 文件安装情况
Check_PHP_Upgrade_Files

Echo_Blue "PHP 5.3 安装完成！"