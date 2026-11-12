#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成 RSEsignKey.h —— ESign(轻松签) 源解密密钥

密钥来源于开源项目 Nyasami/Ksign (GPL-3.0)：
  AltSourceKit/Sources/AltSourceKit/Utilities/Key/EsignSourceKey.swift

用法：
    python3 tools/gen_esign_key.py                 # 从上游下载并生成
    python3 tools/gen_esign_key.py --local FILE    # 用本地已有的 swift 文件
    python3 tools/gen_esign_key.py --check         # 只校验已生成的 .h

为什么用脚本而不是直接提交常量表：
  1. 32KB 纯十六进制数组对 diff / review 不友好
  2. 密钥若有更新，重新跑一次即可，不必手工比对
  3. 明确记录来源与许可证，便于合规
"""

import argparse
import os
import re
import sys
import urllib.request

UPSTREAM_RAW = (
    "https://raw.githubusercontent.com/Nyasami/Ksign/main/"
    "AltSourceKit/Sources/AltSourceKit/Utilities/Key/EsignSourceKey.swift"
)

OUT_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "RS", "Models", "RSEsignKey.h",
)

HEADER = """//
//  RSEsignKey.h
//  RepoStore — ESign 源解密密钥
//
//  来源：Nyasami/Ksign (AltSourceKit/Utilities/Key/EsignSourceKey.swift)
//  上游：Feather / ESign 生态，GPL-3.0
//  用途：解密 source[...] 形式的 ESign 加密源，实现格式兼容
//
//  ⚠️ 本文件由 tools/gen_esign_key.py 自动生成，请勿手工编辑。
//

#ifndef RS_ESIGN_KEY_H
#define RS_ESIGN_KEY_H

#include <stddef.h>

#define RS_ESIGN_KEY_LEN %d

static const unsigned char rs_esign_key[RS_ESIGN_KEY_LEN] = {
"""

FOOTER = """};

#endif /* RS_ESIGN_KEY_H */
"""


def fetch_source(path=None):
    if path:
        with open(path, encoding="utf-8") as f:
            return f.read()
    sys.stderr.write("下载密钥源: %s\n" % UPSTREAM_RAW)
    req = urllib.request.Request(
        UPSTREAM_RAW, headers={"User-Agent": "RepoStore-keygen/1.0"}
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode("utf-8")


def parse_key(src):
    m = re.search(r"let\s+esign_key\s*:\s*\[UInt8\]\s*=\s*\[(.*?)\]", src, re.S)
    if not m:
        raise SystemExit("错误：未能从源码中找到 esign_key 数组")
    vals = re.findall(r"0x([0-9a-fA-F]{2})", m.group(1))
    if not vals:
        raise SystemExit("错误：数组里没有解析出任何字节")

    declared = re.search(r"let\s+esign_key_len\s*:\s*Int\s*=\s*(\d+)", src)
    if declared:
        n = int(declared.group(1))
        if n != len(vals):
            sys.stderr.write(
                "警告：声明长度 %d 与实际字节数 %d 不一致，以实际为准\n"
                % (n, len(vals))
            )
    return [v.lower() for v in vals]


def render(vals):
    lines = []
    for i in range(0, len(vals), 12):
        chunk = vals[i:i + 12]
        lines.append("    " + ", ".join("0x" + v for v in chunk) + ",")
    return HEADER % len(vals) + "\n".join(lines) + "\n" + FOOTER


def check():
    if not os.path.exists(OUT_PATH):
        print("✗ 未生成：%s" % OUT_PATH)
        return 1
    txt = open(OUT_PATH, encoding="utf-8").read()
    vals = re.findall(r"0x([0-9a-f]{2})", txt)
    print("文件存在：%s" % OUT_PATH)
    print("密钥长度：%d 字节" % len(vals))
    ok = len(vals) == 5055
    print("长度校验：%s" % ("✓ 5055 字节" if ok else "✗ 非 5055 字节"))
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description="生成 ESign 源解密密钥头文件")
    ap.add_argument("--local", metavar="FILE", help="使用本地 swift 文件而非联网下载")
    ap.add_argument("--check", action="store_true", help="只校验已生成的头文件")
    args = ap.parse_args()

    if args.check:
        return check()

    src = fetch_source(args.local)
    vals = parse_key(src)
    out = render(vals)

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        f.write(out)

    print("✓ 已生成 %s" % OUT_PATH)
    print("  密钥长度：%d 字节" % len(vals))
    return 0


if __name__ == "__main__":
    sys.exit(main())
