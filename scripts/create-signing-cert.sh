#!/usr/bin/env bash
# 一次性生成一个自签名的代码签名证书，塞进登录钥匙串。
# 之后 build.sh 会用它签名，TCC 权限在重新编译后不会丢失。
#
# 删除证书：打开"钥匙串访问" → 登录 → 我的证书 → 删除 "MacTranslator Dev"

set -euo pipefail

CERT_NAME="MacTranslator Dev"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning | grep -q "${CERT_NAME}"; then
    echo "✅ 证书已存在：${CERT_NAME}"
    exit 0
fi

echo "生成自签名证书：${CERT_NAME}"
TMP_DIR="$(mktemp -d)"
trap "rm -rf ${TMP_DIR}" EXIT

# 生成 RSA 私钥
openssl genrsa -out "${TMP_DIR}/key.pem" 2048 2>/dev/null

# 生成自签名 X.509 证书，扩展包含 codeSigning
cat > "${TMP_DIR}/cert.cnf" <<CONF
[req]
distinguished_name = dn
x509_extensions    = v3
prompt             = no

[dn]
CN = ${CERT_NAME}

[v3]
basicConstraints       = critical,CA:FALSE
keyUsage               = critical,digitalSignature
extendedKeyUsage       = critical,codeSigning
subjectKeyIdentifier   = hash
CONF

openssl req -x509 -new -sha256 -days 3650 \
    -key    "${TMP_DIR}/key.pem" \
    -out    "${TMP_DIR}/cert.pem" \
    -config "${TMP_DIR}/cert.cnf" 2>/dev/null

# 打包成 p12 给 security 导入（macOS 的 security 不直接吃 pem+key）
openssl pkcs12 -export \
    -inkey "${TMP_DIR}/key.pem" \
    -in    "${TMP_DIR}/cert.pem" \
    -out   "${TMP_DIR}/cert.p12" \
    -name  "${CERT_NAME}" \
    -passout pass:temppw \
    -legacy 2>/dev/null

# 导入私钥+证书到登录钥匙串，允许 codesign 无交互访问
security import "${TMP_DIR}/cert.p12" \
    -k "${KEYCHAIN}" \
    -P "temppw" \
    -A \
    -t priv \
    -f pkcs12 >/dev/null

# 把证书也单独加进钥匙串作为可信 codeSigning 证书
security add-certificates -k "${KEYCHAIN}" "${TMP_DIR}/cert.pem" 2>/dev/null || true

# 关键：把证书设为本机信任用于 codeSigning
security add-trusted-cert \
    -d -r trustRoot \
    -p codeSign \
    -k "${KEYCHAIN}" \
    "${TMP_DIR}/cert.pem" 2>/dev/null || \
security add-trusted-cert \
    -r trustAsRoot \
    -p codeSign \
    -k "${KEYCHAIN}" \
    "${TMP_DIR}/cert.pem" 2>/dev/null || true

# 允许 codesign 静默使用私钥（避免每次签名弹窗）
security set-key-partition-list \
    -S 'apple-tool:,apple:,codesign:' \
    -s -k "" "${KEYCHAIN}" >/dev/null 2>&1 || true

echo ""
echo "当前 codesigning 可用身份："
security find-identity -v -p codesigning
