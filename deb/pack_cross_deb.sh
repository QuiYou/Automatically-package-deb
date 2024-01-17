#!/bin/bash
echo "
  老特无根适配脚本
"
echo -e "=================
请填写下方内容并且不可使用中文⬇️
=================\n"

# 设置默认的DEB_ARCHITECTURE变量为iphoneos-arm，通常不需要手动更改它，因为它会在rootless模式下自动更改为arm64
DEB_ARCHITECTURE="iphoneos-arm"

echo "包名->:"
read DEB_NAME

echo "作者->:"
read DEB_AUTHOR

echo "安装包简介->:"
read DEB_DES

echo "游戏进程名->:"
read TARGET_PROCESS

echo "游戏唯一标识符->:"
read TARGET_BUNDLE

echo "版本号(比如: 1.0.0)->:"
read DEB_VERSION
# 验证版本号是否符合要求，必须是 "1.0.0" 的格式
if [[ ! "$DEB_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "版本号格式无效, 应该是这样的->'1.0.0'"
  exit 1
fi

SAFE_GUARD(){
    if [ $? -ne 0 ]
    then
        echo "❎: $1"
        exit 1
    else
		if [ "$2" ]
    	then
        echo "✅: $2"
    	fi
    fi
}

# 检查依赖命令是否存在
COMMANDS=("dpkg-deb" "file" "otool" "install_name_tool")
for CMD in ${COMMANDS[@]}; do
  if ! command -v $CMD &>/dev/null; then
    SAFE_GUARD "$CMD could not be found" "Environmental legality"
  fi
done

# 进入脚本所在目录
cd "$(dirname "$0")"
SAFE_GUARD "Failed to change directory to $(dirname "$0")"

# 遍历当前目录下的.dylib文件，对每个文件进行处理
for dylib in *.dylib
do
    if [ -f "$dylib" ]; then
        echo "Processing $dylib"
        
        # 创建必要的目录结构
        # mkdir -p debpack/usr
        # mkdir -p debpack/usr/bin
        mkdir -p debpack/DEBIAN
        mkdir -p debpack/Library/MobileSubstrate/DynamicLibraries
        cp "$dylib" debpack/Library/MobileSubstrate/DynamicLibraries/
        SAFE_GUARD "Failed to copy $dylib to debpack/Library/MobileSubstrate/DynamicLibraries/"
        
        # 创建.plist文件，用于指定Tweak注入的目标进程和Bundle ID
        cat <<EOF > debpack/Library/MobileSubstrate/DynamicLibraries/$(basename $dylib .dylib).plist
{
    Filter = {
        Executables = (
            $TARGET_PROCESS
        );
        Bundles = (
            "${TARGET_BUNDLE[0]}",
            "${TARGET_BUNDLE[1]}"
        );
    };
}

EOF
    SAFE_GUARD "无法创建 plist 文件 $dylib"
    
    # 创建DEB包的控制文件
        cat <<EOF > debpack/DEBIAN/control
Package: ${DEB_NAME}
Version: ${DEB_VERSION}
Section: custom
Priority: optional
Architecture: ${DEB_ARCHITECTURE}
Replaces: ${DEB_NAME}
Provides: ${DEB_NAME}
Conflicts: ${DEB_NAME}
Essential: no
Maintainer: ${DEB_AUTHOR} <MustangYM@yeah.net>
Depends: mobilesubstrate
Description: ${DEB_DES}
Name: ${DEB_NAME}
Author: ${DEB_AUTHOR}
EOF
        SAFE_GUARD "无法创建control文件 $dylib"
        
        # 生成postinst文件，用于安装后执行的操作
        POSTINST_FILE="debpack/DEBIAN/postinst"
        echo "#!/bin/sh" > "$POSTINST_FILE"
        echo "killall -9 SpringBoard" >> "$POSTINST_FILE"
        chmod +x "$POSTINST_FILE"
        
        # --------------------不需要则删除----------------------
        # 创建 bossTool 脚本文件
        # BOSS_TOOL_SCRIPT="debpack/usr/bin/bossTool"
        # echo -e "#!/bin/sh\n" > "$BOSS_TOOL_SCRIPT"

        # 添加删除文件的函数
        # echo 'ace() {' >> "$BOSS_TOOL_SCRIPT"
        # echo '    if [ -f "$1" ]; then' >> "$BOSS_TOOL_SCRIPT"
        # echo '        rm -f "$1"' >> "$BOSS_TOOL_SCRIPT"
        # echo '        echo "1：$1"' >> "$BOSS_TOOL_SCRIPT"
        # echo '    else' >> "$BOSS_TOOL_SCRIPT"
        # echo '        echo "2：$1"' >> "$BOSS_TOOL_SCRIPT"
        # echo '    fi' >> "$BOSS_TOOL_SCRIPT"
        # echo -e '}\n' >> "$BOSS_TOOL_SCRIPT"

        # 添加删除文件的命令
        # echo 'ace /Library/MobileSubstrate/DynamicLibraries/boss.plist' >> "$BOSS_TOOL_SCRIPT"
        # echo 'ace /Library/MobileSubstrate/DynamicLibraries/boss.dylib' >> "$BOSS_TOOL_SCRIPT"

        # 添加杀死 SpringBoard 的命令
        # echo -e '\nkillall -9 SpringBoard' >> "$BOSS_TOOL_SCRIPT"
        # chmod +x "$BOSS_TOOL_SCRIPT"

        # ------------------结束删除文件-------------------------
        
        # 打包DEB包
        dpkg-deb -b debpack ${DEB_NAME}_${DEB_VERSION}_${DEB_ARCHITECTURE}.deb
        SAFE_GUARD "无法创建 deb 包 $dylib"
        
        # 删除临时目录
        rm -rf debpack
        SAFE_GUARD "无法删除 debpack"

        ### 创建 Deb 结束

        # 开始处理rootless
        OS=`uname -s`
        ARCH=`uname -m`
        
        case "$OS" in
          Linux*)
            OS_TYPE="linux"
            ;;
          Darwin*)
            OS_TYPE="macosx"
            ;;
          *)
            SAFE_GUARD "Unsupported OS"
            exit
            ;;
        esac

        case "$ARCH" in
          x86_64)
            ARCH_TYPE="x86_64"
            ;;
          aarch64|arm64)
            if [ "$OS_TYPE" == "macosx" ]; then
                ARCH_TYPE="arm64"
            else
                ARCH_TYPE="aarch64"
            fi
            ;;
          *)
            SAFE_GUARD "Unsupported architecture"
            exit
            ;;
        esac
        
        # 设置LDID变量为用于签名的ldid工具路径，根据操作系统和架构选择不同的工具
        LDID="./ldid_${OS_TYPE}_${ARCH_TYPE} -Hsha256"
        
        # 更改ldid工具的执行权限，使其可执行
        chmod +x ldid_${OS_TYPE}_${ARCH_TYPE}
        
        # 检查是否成功更改了ldid工具的执行权限
        SAFE_GUARD "Failed to change permissions for ldid_${OS_TYPE}_${ARCH_TYPE}" "Change permissions for ldid_${OS_TYPE}_${ARCH_TYPE}"
        
        # 定义DEB文件名，包括包名、版本和架构信息
        DEB_FILE=${DEB_NAME}_${DEB_VERSION}_${DEB_ARCHITECTURE}.deb
        
        # 创建临时目录，用于解压DEB文件的内容
        TEMPDIR_OLD="$(mktemp -d)"
        TEMPDIR_NEW="$(mktemp -d)"
        
        # 解压DEB文件到临时目录TEMPDIR_OLD中
        dpkg-deb -R "$DEB_FILE" "$TEMPDIR_OLD"
        
        # 检查是否成功解压了DEB文件到TEMPDIR_OLD目录
        SAFE_GUARD "Failed to extract $DEB_FILE to $TEMPDIR_OLD"
        
        # 更改DEB包中usr目录下文件的权限为755，以确保脚本等可执行文件可以正常运行
        # chmod 755 $TEMPDIR_OLD/usr/*
        # SAFE_GUARD "无法更改权限 $TEMPDIR_OLD/usr/*" "更改权限 $TEMPDIR_OLD/usr/*"
        
        # 更改DEB包中DEBIAN目录下文件的权限为755，以确保脚本等可执行文件可以正常运行
        chmod 755 $TEMPDIR_OLD/DEBIAN/*
        
        # 检查是否成功更改了DEBIAN目录下文件的权限为755
        SAFE_GUARD "Failed to change permissions for $TEMPDIR_OLD/DEBIAN/*" "Change permissions for $TEMPDIR_OLD/DEBIAN/*"
        
        # 更改DEB包中DEBIAN/control文件的权限为644
        chmod 644 $TEMPDIR_OLD/DEBIAN/control
        
        # 检查是否成功更改了DEBIAN/control文件的权限为644
        SAFE_GUARD "Failed to change permissions for $TEMPDIR_OLD/DEBIAN/control" "Change permissions for $TEMPDIR_OLD/DEBIAN/control"
        
         # 创建目录结构
        mkdir -p "$TEMPDIR_NEW"/var/jb
        cp -a "$TEMPDIR_OLD"/DEBIAN "$TEMPDIR_NEW"
        
        # 替换DEB包的架构为arm64
        sed 's|iphoneos-arm|iphoneos-arm64|' < "$TEMPDIR_OLD"/DEBIAN/control > "$TEMPDIR_NEW"/DEBIAN/control
        SAFE_GUARD "Failed to replace iphoneos-arm with iphoneos-arm64 in $TEMPDIR_OLD/DEBIAN/control and write to $TEMPDIR_NEW/DEBIAN/control" "Replace iphoneos-arm with iphoneos-arm64"
        
        # 移动文件
        rm -rf "$TEMPDIR_OLD"/DEBIAN
        mv -f "$TEMPDIR_OLD"/.* "$TEMPDIR_OLD"/* "$TEMPDIR_NEW"/var/jb >/dev/null 2>&1 || true
        
        # 如果存在DynamicLibraries目录，将其移动到usr/lib/TweakInject目录
        if [ -d "$TEMPDIR_NEW/var/jb/Library/MobileSubstrate/DynamicLibraries" ]; then
            mkdir -p "$TEMPDIR_NEW/var/jb/usr/lib"
            mv "$TEMPDIR_NEW/var/jb/Library/MobileSubstrate/DynamicLibraries" "$TEMPDIR_NEW/var/jb/usr/lib/TweakInject"
        fi
        
        # 遍历文件并进行处理
        find "$TEMPDIR_NEW" -type f | while read -r file; do
            if file -b "$file" | grep -q "Mach-O"; then
                INSTALL_NAME=$(otool -D "$file" | grep -v -e ":$" -e "^Archive :" | head -n1)
                otool -L "$file" | tail -n +2 | grep /usr/lib/'[^/]'\*.dylib | cut -d' ' -f1 | tr -d "[:blank:]" > "$TEMPDIR_OLD"/._lib_cache
                if [ -n "$INSTALL_NAME" ]; then
                    install_name_tool -id @rpath/"$(basename "$INSTALL_NAME")" "$file"
                fi
                if otool -L "$file" | grep -q CydiaSubstrate; then
                    install_name_tool -change /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate @rpath/libsubstrate.dylib "$file"
                fi
                if [ -f "$TEMPDIR_OLD"/._lib_cache ]; then
                    cat "$TEMPDIR_OLD"/._lib_cache | while read line; do
                        install_name_tool -change "$line" @rpath/"$(basename "$line")" "$file"
                    done
                fi
                install_name_tool -add_rpath "/usr/lib" "$file"
                install_name_tool -add_rpath "/var/jb/usr/lib" "$file"
                $LDID -s "$file"
                SAFE_GUARD "Failed to sign $file with ldid" "Sign $file with ldid"
            fi
        done
        
        # 生成新的DEB包
        PACKAGE_FULLNAME="$(pwd)"/"$(grep Package: "$TEMPDIR_NEW"/DEBIAN/control | cut -f2 -d ' ')"_"$(grep Version: "$TEMPDIR_NEW"/DEBIAN/control | cut -f2 -d ' ')"_"$(grep Architecture: "$TEMPDIR_NEW"/DEBIAN/control | cut -f2 -d ' ')"
        sudo dpkg-deb -b "$TEMPDIR_NEW" ${PACKAGE_FULLNAME}_rootless.deb
        
        # 清理临时文件
        rm -rf "$TEMPDIR_OLD" "$TEMPDIR_NEW"
        rm -rf ${PACKAGE_FULLNAME}
        SAFE_GUARD "Failed to remove $TEMPDIR_NEW" "🍻🍻🍻🍻🍻🍻打包成功🍻🍻🍻🍻🍻🍻"
        
        # 结束rootless部分处理
    else
        SAFE_GUARD "没有找到Dylib文件"
    fi
done

