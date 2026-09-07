#!/bin/sh
# Deliberately POSIX and dependency-free: the desktop image is minimal.
# Any one of these succeeding is enough.
if command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | grep -q ':5901'; then exit 0; fi
if command -v netstat >/dev/null 2>&1 && netstat -ltn 2>/dev/null | grep -q ':5901'; then exit 0; fi
if grep -qi ':170D' /proc/net/tcp 2>/dev/null; then exit 0; fi   # 5901 == 0x170D
exit 1
