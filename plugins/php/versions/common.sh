#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin:/opt/homebrew/bin
export PATH=$PATH:/opt/homebrew/bin

curPath=`pwd`
rootPath=$(dirname "$curPath")
rootPath=$(dirname "$rootPath")
rootPath=$(dirname "$rootPath")
serverPath=$(dirname "$rootPath")

version=$1
action=$2
extName=$3

# echo $1,$2,$3

# echo $curPath
# echo $rootPath
# echo $serverPath

if [ "$version" = "86" ]; then
    php_bin="$serverPath/php/86/bin"
    if [ "$action" = "install" ]; then
        extension_dir=$("$php_bin/php-config" --extension-dir) || exit 1
        mkdir -p "$extension_dir" || exit 1
    fi
    case "$extName" in
        apcu|brotli|event|imagemagick|memcached|mongodb|pgsql|sodium|xhprof|yac|yaml)
            exec bash "$curPath/86/pecl.sh" "$action" "$extName"
            ;;
    esac
fi

FILE=${curPath}/${version}/${extName}.sh
FILE_COMMON=${curPath}/common/${extName}.sh


if [ "$action" = 'install' ];then
	
	if [ -f $FILE ];then
		cd ${curPath}/${version} && bash ${extName}.sh install ${version} || exit $?
	elif [ -f $FILE_COMMON ];then
		cd ${curPath}/common && bash ${extName}.sh install ${version} || exit $?
	else
		echo 'no such extension'
	fi
fi


if [ "$action" = 'uninstall' ];then
		if [ -f $FILE ];then
		cd ${curPath}/${version} && bash ${extName}.sh uninstall ${version} || exit $?
	elif [ -f $FILE_COMMON ];then
		cd ${curPath}/common && bash ${extName}.sh uninstall ${version} || exit $?
	else
		echo 'no such extension'
	fi
fi

echo "cd ${curPath}/common && bash ${extName}.sh install ${version}"
echo "cd ${curPath}/${version} && bash ${extName}.sh install ${version}"
echo "cd ${curPath}/common && bash ${extName}.sh uninstall ${version}"
echo "cd ${curPath}/${version} && bash ${extName}.sh uninstall ${version}"
