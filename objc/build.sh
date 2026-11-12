#!/bin/sh
# RepoStore iOS 交叉编译脚本
# 依赖：Theos (含 iOS SDK) + ldid + zip
set -e

ROOT=$(cd "$(dirname "$0")" && pwd)
SRC=$ROOT/RS
BUILD=$ROOT/build
TOOL=${THEOS_TOOLCHAIN:-/opt/theos/toolchain/linux/iphone/bin}
SDK=${THEOS_SDK:-/opt/theos/sdks/iPhoneOS16.5.sdk}
APPNAME=RepoStore

CC=$TOOL/arm64-apple-darwin14-clang
LD=$TOOL/arm64-apple-darwin14-ld

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

ICO="$SRC/Resources/Assets.xcassets/AppIcon.appiconset"
if [ -d "$ICO" ]; then
  cp "$ICO/icon-60@2x.png"      "$BUILD/$APPNAME.app/AppIcon60x60@2x.png"
  cp "$ICO/icon-60@3x.png"      "$BUILD/$APPNAME.app/AppIcon60x60@3x.png"
  cp "$ICO/icon-40@2x.png"      "$BUILD/$APPNAME.app/AppIcon40x40@2x.png"
  cp "$ICO/icon-40@3x.png"      "$BUILD/$APPNAME.app/AppIcon40x40@3x.png"
  cp "$ICO/icon-29@2x.png"      "$BUILD/$APPNAME.app/AppIcon29x29@2x.png"
  cp "$ICO/icon-29@3x.png"      "$BUILD/$APPNAME.app/AppIcon29x29@3x.png"
  cp "$ICO/icon-20@2x.png"      "$BUILD/$APPNAME.app/AppIcon20x20@2x.png"
  cp "$ICO/icon-20@3x.png"      "$BUILD/$APPNAME.app/AppIcon20x20@3x.png"
  cp "$ICO/icon-76@2x.png"      "$BUILD/$APPNAME.app/AppIcon76x76@2x.png"
  cp "$ICO/icon-83.5@2x.png"    "$BUILD/$APPNAME.app/AppIcon83.5x83.5@2x.png"
  cp "$ICO/icon-1024.png"       "$BUILD/$APPNAME.app/iTunesArtwork@2x.png"
fi

echo "=== 伪签名 (ldid) ==="
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
