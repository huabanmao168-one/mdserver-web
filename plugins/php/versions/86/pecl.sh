#!/bin/bash

# Called from versions/common.sh with the versions directory as cwd.
action=$1
module=$2
versions_dir=$PWD
server_dir=$(cd "$versions_dir/../../../.." && pwd)
php_dir="$server_dir/php/86"
php_ini="$php_dir/etc/php.ini"
options=()
source_subdir=''
source_url=''
repository=''
ini_setting=''

case "$module" in
    apcu)
        repository=krakjoe/apcu
        source_name=apcu-fb2c942552a3f5dab7f4dea4afb5cf0831222c57
        sha256=7f9d03dfabaf5961021c529f48a61386b73cd697cbacd410008ec32bc2d038c6
        ;;
    brotli)
        source_name=brotli-0.21.1
        sha256=33574094e39a433ede3570ba6fcf15d356fc3489abbda396f8cdac472338e1ce
        ;;
    event)
        source_name=event-3.2.0
        sha256=fb3d4e3c9fdc79125274f2b46461492923edec6b489ed7077973f7e65f41dc1c
        ;;
    imagemagick)
        module=imagick
        repository=Imagick/imagick
        source_name=imagick-55ed2e9fda264395636a2e27e51f31673f5566ab
        sha256=81a24f34334cb620ea16ed563afdc3b61b60ab321f2d817dd0412a8f20ddedf6
        ;;
    memcached)
        repository=php-memcached-dev/php-memcached
        source_name=php-memcached-0b52d3657140750fa0eddd20cdbfc6edc8fbdadd
        sha256=464238bc82b70dde84b8ae40bf4bb466281b976e545fd67b8ab2af83bd0b1448
        options+=(--disable-memcached-sasl)
        ;;
    mongodb)
        source_name=mongodb-2.5.9
        sha256=9ecf4f6005e1adbb0e5c59c55ff2e9c8347983060aac472043ee3b8570e816f3
        ;;
    xhprof)
        ini_setting='xhprof.output_dir=/tmp/xhprof'
        source_name=xhprof-2.3.10
        source_subdir=/extension
        sha256=251aee99c2726ebc6126e1ff0bb2db6e2d5fd22056aa335e84db9f1055d59d95
        ;;
    yac)
        source_name=yac-3.0.2
        sha256=93fd14c02bfd6f49cf7cfec0e19480e0ed2fe7a2924008c5dcff8db2634a82e4
        ;;
    yaml)
        repository=php/pecl-file_formats-yaml
        source_name=pecl-file_formats-yaml-a77fb491dd4614290db8e56e87bd3b03b3e8fd01
        sha256=d7fa9fa9cd2d77c65280fcfcb03bcabbcc867ec967937f47fbad419bec46b0b0
        ;;
    sodium|pgsql)
        source_name=php-8.6.0
        source_subdir="/ext/$module"
        source_url=https://www.php.net/distributions/php-8.6.0.tar.xz
        sha256=5f84beaa3d763aee1e4feed99bf54ec692c383b322e25626807b589238c3a087
        ;;
    *) echo "未知的 PHP 8.6 扩展：$module" >&2; exit 1 ;;
esac

if [ -n "$repository" ]; then
    source_url="https://codeload.github.com/$repository/tar.gz/${source_name##*-}"
elif [ -z "$source_url" ]; then
    source_url="https://pecl.php.net/get/$source_name.tgz"
fi

extension_dir=$("$php_dir/bin/php-config" --extension-dir) || exit 1
module_file="$extension_dir/$module.so"
ini_entry="^[[:space:]]*extension[[:space:]]*=[[:space:]]*\"?$module[.]so\"?[[:space:]]*(;.*)?$"

if [ "$action" = install ]; then
    if ! [ -f "$module_file" ]; then
        build_dir=$(mktemp -d) || exit 1
        trap 'rm -rf "$build_dir"' EXIT
        cd "$build_dir" || exit 1
        curl -fL --retry 3 --retry-all-errors -o source.archive "$source_url" || exit 1
        hash_command=sha256sum
        if ! command -v sha256sum >/dev/null 2>&1; then
            hash_command="shasum -a 256"
        fi
        printf '%s  %s\n' "$sha256" source.archive | $hash_command -c - || exit 1
        tar -xf source.archive && cd "$source_name$source_subdir" || exit 1
        "$php_dir/bin/phpize" && ./configure --with-php-config="$php_dir/bin/php-config" "${options[@]}" &&
            make -j2 && make install || exit 1
    fi
    MW_PHP_MODULE="$module" "$php_dir/bin/php" -n -d "extension=$module_file" \
        -r 'exit(extension_loaded(getenv("MW_PHP_MODULE")) ? 0 : 1);' || exit 1
    if [ "$module" = xhprof ] && [ ! -d /tmp/xhprof ]; then
        mkdir /tmp/xhprof || exit 1
        if id www >/dev/null 2>&1; then
            chown www:www /tmp/xhprof || exit 1
        fi
    fi
    if ! grep -Eq "$ini_entry" "$php_ini"; then
        printf '\n[%s]\nextension=%s.so\n' "$module" "$module" >> "$php_ini" || exit 1
        if [ -n "$ini_setting" ]; then
            printf '%s\n' "$ini_setting" >> "$php_ini" || exit 1
        fi
    fi
elif [ "$action" = uninstall ]; then
    # Keep unrelated directives and section content in the shared php.ini.
    if grep -Eq "$ini_entry" "$php_ini"; then
        ini_copy=$(mktemp "$php_ini.XXXXXX") || exit 1
        trap 'rm -f "$ini_copy"' EXIT
        grep -Ev "$ini_entry" "$php_ini" > "$ini_copy"
        cat "$ini_copy" > "$php_ini" || exit 1
    fi
    rm -f "$module_file" || exit 1
else
    exit 1
fi

cd "$versions_dir/common" && bash "$versions_dir/lib.sh" 86 restart
