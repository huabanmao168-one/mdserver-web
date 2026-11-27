#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin:/opt/homebrew/bin
export PATH=$PATH:/opt/homebrew/bin

curPath=`pwd`

rootPath=$(dirname "$curPath")
rootPath=$(dirname "$rootPath")
rootPath=$(dirname "$rootPath")
rootPath=$(dirname "$rootPath")
serverPath=$(dirname "$rootPath")
sourcePath=${serverPath}/source/php
SYS_ARCH=`arch`
LIBNAME=redis
LIBV=6.3.0
sysName=`uname`
actionType=$1
version=$2

if [ "$version" = "86" ]; then
    # Redis 6.3.0 uses Zend APIs removed in PHP 8.6.
    redis_commit=c772ffa75a324bd021cd5d1b19ec4983164b85a6
    redis_source="phpredis-$redis_commit"
    redis_url="https://codeload.github.com/phpredis/phpredis/tar.gz/$redis_commit"
    redis_sha256=0ffef4123c2c5d667ac866a52417e3bfacb245018ad9e602592d110c874f468b
    extension_dir=$("$serverPath/php/$version/bin/php-config" --extension-dir) || exit 1
    extFile="$extension_dir/redis.so"
else
    if [ "$version" = "52" ];then
        LIBV=2.2.7
    elif [ "$version" -lt "70" ];then
        LIBV=4.2.0
    elif [ "$version" -lt "80" ];then
        LIBV=5.3.7
    elif [ "$version" -gt "80" ];then
        LIBV=6.3.0
    fi

    redis_source="$LIBNAME-$LIBV"
    redis_url="https://pecl.php.net/get/$redis_source.tgz"
    LIB_PATH_NAME=lib/php
    if [ -d "$serverPath/php/$version/lib64" ];then
        LIB_PATH_NAME=lib64
    fi
    NON_ZTS_FILENAME=$(ls "$serverPath/php/$version/$LIB_PATH_NAME/extensions" | grep no-debug-non-zts)
    extFile="$serverPath/php/$version/$LIB_PATH_NAME/extensions/$NON_ZTS_FILENAME/$LIBNAME.so"
fi

if [ "$sysName" = "Darwin" ];then
	BAK='_bak'
else
	BAK=''
fi

Install_lib()
{
	isInstall=`cat $serverPath/php/${version}/etc/php.ini|grep "${LIBNAME}.so"`
	if [ "${isInstall}" != "" ];then
		echo "php-$version 已安装${LIBNAME},请选择其它版本!"
		return
	fi
	
	
	if [ ! -f "$extFile" ];then

        php_lib="$sourcePath/php_lib"
        mkdir -p "$php_lib" || return 1
        cd "$php_lib" || return 1
        archive="$redis_source.tgz"
        if [ ! -s "$archive" ]; then
            curl -fL --retry 2 -o "$archive.tmp" "$redis_url" || return 1
            mv "$archive.tmp" "$archive" || return 1
        fi
        if [ "$version" = "86" ]; then
            hash_command=sha256sum
            if ! command -v sha256sum >/dev/null 2>&1; then
                hash_command="shasum -a 256"
            fi
            if ! printf '%s  %s\n' "$redis_sha256" "$archive" | $hash_command -c -; then
                rm -f "$archive"
                return 1
            fi
        fi
        tar -xzf "$archive" && cd "$redis_source" || return 1

		OPTIONS=""
		if [ "${SYS_ARCH}" = "aarch64" ] && [ "$version" -lt "56" ];then
			OPTIONS="$OPTIONS --build=aarch64-unknown-linux-gnu --host=aarch64-unknown-linux-gnu"
		fi
		
		$serverPath/php/$version/bin/phpize || return 1
		./configure --with-php-config=$serverPath/php/$version/bin/php-config $OPTIONS || return 1
		make clean && make && make install && make clean || return 1

		cd "$php_lib" && rm -rf "$php_lib/$redis_source"
	fi

	if [ ! -f "$extFile" ];then
		echo "ERROR!"
		return 1
	fi

	echo "[${LIBNAME}]" >> $serverPath/php/$version/etc/php.ini
	echo "extension=${LIBNAME}.so" >> $serverPath/php/$version/etc/php.ini

	cd  ${curPath} && bash ${rootPath}/plugins/php/versions/lib.sh $version restart
	echo '==========================================================='
	echo 'successful!'
}


Uninstall_lib()
{
	if [ ! -f "$serverPath/php/$version/bin/php-config" ];then
		echo "php-$version 未安装,请选择其它版本!"
		return
	fi

	if [ ! -f "$extFile" ];then
		echo "php-$version 未安装${LIBNAME},请选择其它版本!"
		echo "php-$version not install ${LIBNAME}, Plese select other version!"
		return
	fi
	
	sed -i $BAK "/${LIBNAME}.so/d" $serverPath/php/$version/etc/php.ini
	sed -i $BAK "/${LIBNAME}/d" $serverPath/php/$version/etc/php.ini
		
	rm -f $extFile
	cd  ${curPath} && bash ${rootPath}/plugins/php/versions/lib.sh $version restart
	echo '==============================================='
	echo 'successful!'
}



if [ "$actionType" = 'install' ];then
	Install_lib
elif [ "$actionType" = 'uninstall' ];then
	Uninstall_lib
fi