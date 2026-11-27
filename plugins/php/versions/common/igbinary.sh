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


actionType=$1
version=$2

LIBNAME=igbinary
LIBV=3.2.16

if [ "$version" -lt "70" ];then
	echo "not need"
	exit 1
fi 

php_bin="$serverPath/php/$version/bin"
php_ini="$serverPath/php/$version/etc/php.ini"
source_name="$LIBNAME-$LIBV"
source_url="https://pecl.php.net/get/$source_name.tgz"
if [ "$version" = "86" ]; then
    # The 3.2.16 release uses a header removed in PHP 8.6.
    source_commit=fe33bf9ec03e97e2290a090abc72326e6910f5c1
    source_name="$LIBNAME-$source_commit"
    source_url="https://codeload.github.com/igbinary/igbinary/tar.gz/$source_commit"
    source_sha256=f6f7a0633e04714eb38b8ec4e96b7a1eccf04d78eb100129c536b9c62b063a08
fi
extension_dir=$("$php_bin/php-config" --extension-dir) || exit 1
extFile="$extension_dir/$LIBNAME.so"

sysName=`uname`
if [ "$sysName" = "Darwin" ];then
	BAK='_bak'
else
	BAK=''
fi

Install_lib()
{
    if ! [ -f "$php_ini" ]; then
        echo "找不到 PHP $version 的配置文件：$php_ini"
        return 1
    fi
    if [ ! -f "$extFile" ]; then
        php_lib="$sourcePath/php_lib"
        mkdir -p "$php_lib" && cd "$php_lib" || return 1
        archive="$source_name.tgz"
        if [ ! -s "$archive" ]; then
            curl -fL --retry 3 --retry-all-errors -o "$archive.tmp" "$source_url" || return 1
            mv "$archive.tmp" "$archive" || return 1
        fi
        if [ "$version" = "86" ]; then
            hash_command=sha256sum
            if ! command -v sha256sum >/dev/null 2>&1; then
                hash_command="shasum -a 256"
            fi
            if ! printf '%s  %s\n' "$source_sha256" "$archive" | $hash_command -c -; then
                rm -f "$archive"
                return 1
            fi
        fi
        tar -xzf "$archive" && cd "$source_name" || return 1
        "$php_bin/phpize" || return 1
        ./configure --with-php-config="$php_bin/php-config" || return 1
        make clean && make && make install || return 1
        cd "$php_lib" && rm -rf "$source_name"
    fi

    if ! "$php_bin/php" -n -d "extension=$extFile" -r 'exit(extension_loaded("igbinary") ? 0 : 1);'; then
        echo "PHP $version 无法加载 $extFile"
        return 1
    fi
    if ! grep -Eq '^[[:space:]]*extension[[:space:]]*=[[:space:]]*"?igbinary[.]so"?([[:space:]]|;|$)' "$php_ini"; then
        printf '\n[igbinary]\nextension=igbinary.so\n' >> "$php_ini" || return 1
    fi

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
		return
	fi
	
	echo $serverPath/php/$version/etc/php.ini
	sed -i $BAK "/${LIBNAME}.so/d" $serverPath/php/$version/etc/php.ini
	sed -i $BAK "/${LIBNAME}.use_namespace/d" $serverPath/php/$version/etc/php.ini
	sed -i $BAK "/\[${LIBNAME}\]/d"  $serverPath/php/$version/etc/php.ini
		
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