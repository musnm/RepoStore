#!/bin/sh
# RepoStore iOS 交叉编译脚本（Alpine Linux + Theos SDK）
#
# 前置条件：
#   1. Theos 工具链与 iPhoneOS SDK 已就位（路径见下方 TOOL / SDK）
#   2. RS/Models/RSEsignKey.h 需自备 —— 它包含第 2 方 ESign 解密密钥表，
#      未随本仓库分发。需提供：
#          extern const unsigned char rs_esign_key[];
#          #define RS_ESIGN_KEY_LEN <key 长度>
#      缺此文件时 ESign(source[...]) 加密源不可用，其余功能不受影响。
#   3. 需要 ldid（用于伪签名）
set -e

ROOT=$(cd "$(dirname "$0")" && pwd)
SRC=$ROOT/RS
BUILD=$ROOT/build
TOOL=/opt/theos/toolchain/linux/iphone/bin
SDK=/opt/theos/sdks/iPhoneOS16.5.sdk
APPNAME=RepoStore
BUNDLE=com.musnm.repostore

CC=$TOOL/arm64-apple-darwin14-clang
LD=$TOOL/arm64-apple-darwin14-ld
LIPO=$TOOL/arm64-apple-darwin14-lipo
STRIP=$TOOL/arm64-apple-darwin14-strip

# ESign 解密密钥：必须自备，否则跳过加密源支持
if [ ! -f "$SRC/Models/RSEsignKey.h" ]; then
    echo "警告：缺少 RS/Models/RSEsignKey.h，ESign 加密源将不可用" >&2
    echo "      请自备该头文件后重新编译（见文件头注释）" >&2
fi

rm -rf "$BUILD"
mkdir -p "$BUILD/obj" "$BUILD/$APPNAME.app"

CFLAGS="-isysroot $SDK -arch arm64 -miphoneos-version-min=15.0 \
 -fobjc-arc -fmodules -fblocks \
 -I$SRC -I$SRC/Models -I$SRC/Services -I$SRC/Views \
 -F$SDK/System/Library/Frameworks \
 -DNDEBUG -O2 -Wall"

FRAMEWORKS="-framework Foundation -framework UIKit -framework QuartzCore \
 -framework CoreGraphics -framework ImageIO -framework CoreFoundation"

echo "=== 编译源文件 ==="
OBJS=""
for f in $(find "$SRC" -name '*.m' | sort); do
  # 缺少密钥头时跳过依赖它的解密器
  if [ ! -f "$SRC/Models/RSEsignKey.h" ] && [ "$(basename "$f")" = "RSDeobfuscator.m" ]; then
    echo "  SKIP RSDeobfuscator.m (缺少密钥)"
    continue
  fi
  base=$(basename "$f" .m)
  echo "  CC $base"
  $CC $CFLAGS -c "$f" -o "$BUILD/obj/$base.o"
  OBJS="$OBJS $BUILD/obj/$base.o"
done

echo "=== 链接 ==="
$CC -isysroot "$SDK" -arch arm64 -miphoneos-version-min=15.0 \
  -fuse-ld=$LD \
  -F$SDK/System/Library/Frameworks -F$SDK/usr/lib \
  $OBJS -o "$BUILD/$APPNAME.app/$APPNAME" \
  $FRAMEWORKS \
  -L$SDK/usr/lib -lobjc

echo "=== 打包资源 ==="
cp "$SRC/Resources/Info.plist" "$BUILD/$APPNAME.app/Info.plist"
printf 'APPL????' > "$BUILD/$APPNAME.app/PkgInfo"

# 图标：把 appiconset 里的 png 平铺进 .app
ICO="$SRC/Resources/Assets.xcassets/AppIcon.appiconset"
if [ -d "$ICO" ]; then
  cp "$ICO/icon-60@2x.png" "$BUILD/$APPNAME.app/AppIcon60x60@2x.png"
  cp "$ICO/icon-60@3x.png" "$BUILD/$APPNAME.app/AppIcon60x60@3x.png"
  cp "$ICO/icon-40@2x.png" "$BUILD/$APPNAME.app/AppIcon40x40@2x.png"
  cp "$ICO/icon-40@3x.png" "$BUILD/$APPNAME.app/AppIcon40x40@3x.png"
  cp "$ICO/icon-29@2x.png" "$BUILD/$APPNAME.app/AppIcon29x29@2x.png"
  cp "$ICO/icon-29@3x.png" "$BUILD/$APPNAME.app/AppIcon29x29@3x.png"
  cp "$ICO/icon-20@2x.png" "$BUILD/$APPNAME.app/AppIcon20x20@2x.png"
  cp "$ICO/icon-20@3x.png" "$BUILD/$APPNAME.app/AppIcon20x20@3x.png"
  cp "$ICO/icon-76@2x.png" "$BUILD/$APPNAME.app/AppIcon76x76@2x.png"
  cp "$ICO/icon-83.5@2x.png" "$BUILD/$APPNAME.app/AppIcon83.5x83.5@2x.png"
  cp "$ICO/icon-1024.png" "$BUILD/$APPNAME.app/iTunesArtwork@2x.png"
fi

echo "=== 签名 (ldid) ==="
chmod +x "$BUILD/$APPNAME.app/$APPNAME" 2>/dev/null || true
ENT=$ROOT/ent_ts.plist
if [ -f "$ENT" ]; then
  ldid -S"$ENT" "$BUILD/$APPNAME.app/$APPNAME" && echo "  已伪签名 (TrollStore entitlements)"
else
  ldid -S "$BUILD/$APPNAME.app/$APPNAME" && echo "  已伪签名 (默认)"
fi

echo "=== 打包 IPA ==="
rm -rf "$BUILD/Payload"
mkdir -p "$BUILD/Payload"
cp -R "$BUILD/$APPNAME.app" "$BUILD/Payload/"
cd "$BUILD"
rm -f "$APPNAME.ipa"
zip -q -r "$APPNAME.ipa" Payload

echo ""
echo "=== 完成 ==="
ls -lh "$APPNAME.ipa"
