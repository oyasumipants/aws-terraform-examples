#!/bin/bash
set -euo pipefail

echo "============================================"
echo "選択肢A 検証: パブリックサブネット + IGWルート"
echo "============================================"
echo ""

DB_PUBLIC_IP=$(terraform output -raw db_public_ip 2>/dev/null)

if [ -z "$DB_PUBLIC_IP" ]; then
  echo "❌ terraform output が取得できません。terraform apply を先に実行してください。"
  exit 1
fi

echo "📋 DB Public IP: $DB_PUBLIC_IP"
echo ""

# --- テスト1: パブリックIPの有無 ---
echo "--- テスト1: パブリックIPが付与されているか ---"
if [ "$DB_PUBLIC_IP" != "" ] && [ "$DB_PUBLIC_IP" != "null" ]; then
  echo "⚠️  パブリックIPが付与されています: $DB_PUBLIC_IP"
  echo "   → インターネットからルーティング可能な状態"
else
  echo "✅ パブリックIPなし"
fi
echo ""

# --- テスト2: 外部からのポートスキャン ---
echo "--- テスト2: 外部からport 3306 への到達性 ---"
echo "   nmap -Pn -p 3306 $DB_PUBLIC_IP (10秒タイムアウト)"
if command -v nmap &>/dev/null; then
  RESULT=$(nmap -Pn -p 3306 --host-timeout 10s "$DB_PUBLIC_IP" 2>/dev/null | grep "3306" || true)
  echo "   結果: $RESULT"
  if echo "$RESULT" | grep -q "filtered\|closed"; then
    echo "   → SGでブロックされていますが、パブリックIPがある時点でリスクあり"
  elif echo "$RESULT" | grep -q "open"; then
    echo "   ⚠️  ポートが開いています！"
  fi
else
  echo "   (nmap未インストール。 brew install nmap で導入可)"
fi
echo ""

# --- テスト3: ICMP疎通 ---
echo "--- テスト3: 外部からの ICMP (ping) ---"
ping -c 2 -W 3 "$DB_PUBLIC_IP" 2>/dev/null && echo "   ⚠️  ping が通ります" || echo "   ping 不通（SGでブロック）"
echo ""

# --- 総合判定 ---
echo "============================================"
echo "総合判定: ❌ 不正解"
echo ""
echo "理由:"
echo "  DBがパブリックサブネットに配置され、パブリックIPが付与されています。"
echo "  SGで制限しても、パブリックIPがある限りインターネットから"
echo "  ルーティング可能であり、設定ミス一つでアクセス可能になります。"
echo "  → インバウンド遮断の要件を「構造的に」満たしていません。"
echo "============================================"
