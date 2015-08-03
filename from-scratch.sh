#!/bin/bash
set -e
set -x

system_packages=""

NIX_BOOT=`pwd`/nixboot
NIX_ROOT=`pwd`/nixroot
rootdir=$(pwd)
export nix_boot=${NIX_BOOT-$HOME/tmp/nix-boot}
export nix_root=${NIX_ROOT-$HOME/nix}
export RUN_EXPENSIVE_TESTS=no
export PATH=$nix_root/bin:$nix_boot/bin:$PATH
export PKG_CONFIG_PATH=$nix_boot/lib/pkgconfig:$PKG_CONFIG_PATH
export LDFLAGS="-L$nix_boot/lib -L$nix_boot/lib64 $LDFLAGS"
export LD_LIBRARY_PATH="$nix_boot/lib:$nix_boot/lib64:$LD_LIBRARY_PATH"
export CPPFLAGS="-I$nix_boot/include $CPPFLAGS"
#export PERL5OPT="-I$nix_boot/lib/perl"
#export PERL5OPT="-I$nix_boot/lib64/perl5"
export NIXPKGS=$NIX_ROOT/nixpkgs
all="perl dbi dbd wwwcurl bootstrap nix"
pkgs=$(pwd)/packages
srcs=$(pwd)/sources

function linelogger {
    local fn="$1"
    local inc=0

    while read ln; do
        inc=$(($inc+1))
        if [[ -n "$DEBUG" ]]; then
            echo ln
        elif [[ $inc -gt 100 ]]; then
            echo "[$fn: $(date "+%H:%M:%S")] produced $inc lines..."
            inc=0
        fi
    done
}

function extract {
    if [ -z "$1" ]; then
        # display usage if no parameters given
        echo "Usage: extract ."
        return
    fi

    local pkg="$(cd "$(dirname "$1")"; pwd)/$(basename "$1")"
    if [ -n "$2" ]; then
        cd "$2";
    fi

    if [ -f $pkg ] ; then
        case $pkg in
            *.tar.bz2) tar xjf $pkg ;;
            *.tar.gz) tar xzf $pkg;;
            *.tar.xz) tar xJf $pkg;;
            *.lzma) unlzma $pkg ;;
            *.bz2) bunzip2 $pkg ;;
            *.rar) unrar x -ad $pkg ;;
            *.gz) gunzip $pkg ;;
            *.tar) tar xf $pkg ;;
            *.tbz2) tar xjf $pkg ;;
            *.tgz) tar xzf $pkg ;;
            *.zip) unzip $pkg ;;
            *.Z) uncompress $pkg ;;
            *.7z) 7z x $pkg ;;
            *.xz) unxz $pkg ;;
            *) echo "extract: '$pkg' - unknown archive method" ;;
        esac
    else
        echo "$pkg - file does not exist"
    fi
}

for d in "$nix_root" "$nix_boot" "$pkgs" "$srcs"; do
    if ! [ -d $d ]; then
        mkdir -p $d;
    fi
done

function maybe_use_system {
    for i in "$system_packages"; do
        if [[ "$i" = "$1" ]]; then
            echo "";
            return 0
        fi
    done
    return 1
}

function new_file {
    echo $1/$(ls -t "$1" | head -1)
}

# with_pkg <url> [<root-dir-in-pack>]
function with_pkg {
    local url="$1"
    local pack="$pkgs/$(basename "$1")"
    local srcdir=$srcs/${2:-$(basename "$1" | sed -n 's/\.\(tar\|zip\).*//p')}

    if [[ ! -f "$pack" ]]; then
        wget "$url" -O "$pack";
    fi

    if [[ ! -d "$srcdir" ]]; then
        extract "$pack" "$srcs"
    fi

    if [[ ! "$(new_file "$srcs")" = "$srcdir" ]]; then
        echo "Expected to extract '$srcdir' but extracted '$(new_file "$srcs")'" 1>&2
        exit 1;
    fi

    cd $(new_file "$srcs/")
}

function package_bzip2 {
    case "$1" in
        "deps") echo "";;
        "build")
            (with_pkg "http://bzip.org/1.0.6/bzip2-1.0.6.tar.gz"
             make -f Makefile-libbz2_so;
             make install PREFIX=$nix_boot;
             cp libbz2.so.1.0 libbz2.so.1.0.6 $nix_boot/lib) ;;
        *) return 1;;
    esac
}


function package_curl {
    case "$1" in
        "deps") echo "";;
        "build")
            (with_pkg "http://curl.haxx.se/download/curl-7.35.0.tar.lzma"
             ./configure --prefix=$nix_boot;
             make;
             make install; )
            ;;
        *) return 1;;
    esac
}


function package_sqlite {
    case "$1" in
        "deps") echo "";;
        "build")
            (with_pkg "http://www.sqlite.org/2014/sqlite-autoconf-3080300.tar.gz"
             ./configure --prefix=$nix_boot;
             make;
             make install; )
            ;;
        *) return 1;;
    esac
}


function package_libxml2 {
    case "$1" in
        "deps") echo "";;
        "build")
            (cd $srcs/libxml2-2.9.2; ./configure --prefix=$nix_boot;
             make;
             cp ./libxml2-2.9.2/xmllint $nix_boot/bin
             # make install;
            )
            ;;
        *) return 1;;
    esac
}


function package_libxslt {
    case "$1" in
        "deps") echo "";;
        "build")
            (cd $srcs/libxslt-1.1.28;  ./configure --prefix=$nix_boot;
             make;
             make install; )
            ;;
        *) return 1;;
    esac
}


function package_gcc {
    case "$1" in
        "deps") echo "";;
        "build")
            (cd $srcs/gcc-4.9.2; ./contrib/download_prerequisites; )
            rm -rf gcc-objs;
            mkdir -p gcc-objs
            (cd $srcs/gcc-objs; ./../gcc-4.9.2/configure --prefix=$nix_boot;
             make;
             make install; )
            ;;
        *) return 1;;
    esac
}


function package_bison {
    case "$1" in
        "deps") echo "";;
        "build")
            (cd $srcs/bison-3.0; ./configure --prefix=$nix_boot;
             make;
             make install; )
            ;;
        *) return 1;;
    esac
}


function package_flex {
    case "$1" in
        "deps") echo "";;
        "build")
            (cd $srcs/flex-2.5.39;  ./configure --prefix=$nix_boot;
             make;
             make install; )
            ;;
        *) return 1;;
    esac
}


function package_coreutils {
    case "$1" in
        "deps") echo "";;
        "build")
            (cd $srcs/coreutils-8.23;  ./configure --enable-install-program=hostname --prefix=$nix_boot;
             make;
             make install; )
            ;;
        *) return 1;;
    esac
}


function package_bash {
    case "$1" in
        "deps") echo "";;
        "build")
            (cd $srcs/bash-4.3;  ./configure --prefix=$nix_boot;
             make;
             make install; )
            ;;
        *) return 1;;
    esac
}


function package_perl {
    maybe_use_system "perl" && return 0
    case "$1" in
        "deps") echo "";;
        "check")
            if ! ([[ -f $nix_boot/bin/perl ]] && [[ -f $nix_boot/bin/cpan ]]); then
                return 1
            fi ;;
        "build")
            (
                with_pkg "http://www.cpan.org/src/5.0/perl-5.20.1.tar.gz"
                ./Configure -Dprefix="$nix_boot" -des | linelogger perl_conf
                echo "Building perl..."
                make -j8 | linelogger perl_build
                make -j8 test | linelogger perl_test
                make install | linelogger perl_install
                echo "Local perl built successfuly in $(pwd)"
            )
            ;;
        *) return 1;;
    esac
}


function package_dbi {
    case "$1" in
        "deps") echo "perl";;
        "build")
            cpan DBI
            # (
            #     with_pkg "http://search.cpan.org/CPAN/authors/id/T/TI/TIMB/DBI-1.631.tar.gz"
            #     perl Makefile.PL PREFIX=$nix_boot PERLMAINCC=$nix_boot/bin/gcc;
            #     make;
            #     make install;
            # )
            ;;
        *) return 1;;
    esac
}


function package_dbd {
    case "$1" in
        "deps") echo "perl";;
        "build")
            cpan Class::HPLOO::Base DBD::SQLite
            # (
            #     with_pkg "http://search.cpan.org/CPAN/authors/id/I/IS/ISHIGAKI/DBD-SQLite-1.40.tar.gz"
            #     perl Makefile.PL PREFIX=$nix_boot PERLMAINCC=$nix_boot/bin/gcc;
            #     make;
            #     make install;
            # )
            ;;
        *) return 1;;
    esac
}

function package_wwwcurl {
    case "$1" in
        "deps") echo "perl";;
        "build")
            cpan WWW::Curl
            # (
            #     with_pkg "http://search.cpan.org/CPAN/authors/id/S/SZ/SZBALINT/WWW-Curl-4.15.tar.gz"
            #     perl Makefile.PL PREFIX=$nix_boot PERLMAINCC=$nix_boot/bin/gcc;
            #     make;
            #     make install;
            # )
            ;;
        *) return 1;;

    esac
}


function package_bootstrap {
    case "$1" in
        "deps") echo "";;
        "build")
            [[ ! -d $srcs/nix ]] && git clone https://github.com/NixOS/nix "$srcs/nix"
            (cd "$srcs/nix";
             ./bootstrap.sh )
            ;;
        *) return 1;;
    esac
}

function package_nix {
    case "$1" in
        "deps") echo "wwwcurl" "dbi" "dbd" "bootstrap";;
        "build")
            (with_pkg "https://nixos.org/releases/nix/nix-1.8/nix-1.8.tar.xz" "nix"
             echo "./configure --prefix=$nix_boot --with-store-dir=$nix_root/store --localstatedir=$nix_root/var" > myconfig.sh;
             ./configure --prefix=$nix_root --with-store-dir=$nix_root/store --localstatedir=$nix_root/var --enable-static  --enable-static-nix ;
             perl -pi -e 's#--nonet# #g' doc/manual/local.mk;
             echo "GLOBAL_LDFLAGS += -lpthread" >> doc/manual/local.mk;
             make -j8;
             make install; )
            ;;
        *) return 1;;
    esac
}

function package_nixconfig {
    case "$1" in
        "deps") echo "nix";;
        "build")
            nix-channel --add http://nixos.org/channels/nixpkgs-unstable && \
                nix-channel --update # && nix-env -iA nix -f $NIXPKGS
            ;;
        *) return 1;;
    esac
}

function install {
    cd $rootdir
    local package="$1"
    for i in $("package_$package" deps); do
        if ! "package_$i" check; then
            install "$i";
        fi
    done

    "package_$package" build
}

while [[ $# -gt 0 ]]; do
    install "$1"
    shift
done
