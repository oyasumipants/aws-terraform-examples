#!/bin/bash
set -euo pipefail

echo "============================================"
echo "選択肢B 検証: パブリックサブネット + NATルート"
echo "============================================"
echo ""

DB_PUBLIC_IP=$(terraform output -raw db_public_ip 2>/dev/null)
NAT_IP=$(terraform output -raw nat_gateway_ip 2>/dev/null)

if [ -z "$DB_PUBLIC_IP" ]; then
  echo "❌ terraform output が取得できません。terraform apply を先に実行してください。"
  exit 1
fi

echo "📋 DB Public IP: $DB_PUBLIC_IP"
echo "📋 NAT GW IP:    $NAT_IP"
echo ""

# --- テスト1: パブリックIPの有無 ---
echo "--- テスト1: パブリックIPが付与されているか ---"
if [ "$DB_PUBLIC_IP" != "" ] && [ "$DB_PUBLIC_IP" != "null" ]; then
  echo "⚠️  パブリックIPが付与されています: $DB_PUBLIC_IP"
  echo "   → DBがパブリックサブネットにいるため"
else
  echo "✅ パブリックIPなし"
fi
echo ""

# --- テスト2: 外部からのポートスキャン ---
echo "--- テスト2: 外部からport 3306 への到達性 ---"
if command -v nmap &>/dev/null; then
  RESULT=$(nmap -Pn -p 3306 --host-timeout 10s "$DB_PUBLIC_IP" 2>/dev/null | grep "3306" || true)
  echo "   結果: $RESULT"
else
  echo "   (nmap未インストール)"
fi
echo ""

# --- テスト3: NATの無駄を確認 ---
echo "--- テスト3: NAT Gateway の役割 ---"
echo "   NAT GW ($NAT_IP) はプライベートサブネットのルートテーブルに設定されています。"
echo "   しかし、DBはパブリックサブネットにいるので NAT GW は使われません。"
echo "   → NAT GW の料金（〜$0.062/h + データ転送料）が無駄にかかります。"
echo ""

# --- 総合判定 ---
echo "============================================"
echo "総合判定: ❌ 不正解"
echo ""
echo "理由:"
echo "  選択肢Aと同様、DBがパブリックサブネットにいる時点で"
echo "  インバウンド遮断の要件を満たしません。"
echo "  さらにNAT GWの費用が無駄にかかるため、コスト面でも劣ります。"
echo "============================================"
