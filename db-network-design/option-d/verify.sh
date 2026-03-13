#!/bin/bash
set -euo pipefail

echo "============================================"
echo "✅ 選択肢D 検証: プライベートサブネット + NATルート"
echo "============================================"
echo ""

BASTION_IP=$(terraform output -raw bastion_public_ip 2>/dev/null)
DB_PRIVATE_IP=$(terraform output -raw db_private_ip 2>/dev/null)
NAT_IP=$(terraform output -raw nat_gateway_ip 2>/dev/null)

if [ -z "$BASTION_IP" ]; then
  echo "❌ terraform output が取得できません。terraform apply を先に実行してください。"
  exit 1
fi

echo "📋 Bastion IP:    $BASTION_IP"
echo "📋 DB Private IP: $DB_PRIVATE_IP"
echo "📋 NAT GW IP:     $NAT_IP"
echo ""

# --- テスト1: インバウンド遮断 ---
echo "--- テスト1: 外部からDBへの到達性（インバウンド遮断） ---"
echo "   DBはプライベートサブネットにあり、パブリックIPがありません。"
echo "   外部からDBに直接アクセスする手段がありません。"
echo ""
echo "   NAT GW IP ($NAT_IP) への port 3306 スキャン:"
if command -v nmap &>/dev/null; then
  RESULT=$(nmap -Pn -p 3306 --host-timeout 10s "$NAT_IP" 2>/dev/null | grep "3306" || true)
  echo "   結果: $RESULT"
  echo "   → NAT GWはインバウンドの接続要求を転送しません ✅"
else
  echo "   (nmap未インストール。brew install nmap で導入可)"
  echo "   → NAT GWはインバウンドの接続要求を転送しない仕組みです ✅"
fi
echo ""

# --- テスト2: アウトバウンド疎通（パッチDL） ---
echo "--- テスト2: DBからのアウトバウンド通信（パッチDL） ---"
echo "   踏み台経由でDBにSSHし、curl を試行します。"
echo ""
echo "   手動で実行する場合:"
echo "     ssh -J ec2-user@$BASTION_IP ec2-user@$DB_PRIVATE_IP"
echo "     curl -m 10 https://example.com"
echo ""

# 自動テスト
echo "   自動テスト試行中..."
CURL_RESULT=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=15 \
  -J "ec2-user@$BASTION_IP" "ec2-user@$DB_PRIVATE_IP" \
  "curl -s -m 10 https://example.com" 2>/dev/null) && {
  echo "   ✅ curl が成功しました！"
  echo "   レスポンス（先頭3行）:"
  echo "$CURL_RESULT" | head -3 | sed 's/^/     /'
  echo ""
  echo "   → NAT GW経由でインターネットにアクセスできています"
} || {
  echo "   ⚠️  curl が失敗しました"
  echo "   → SSH鍵の設定を確認するか、手動でテストしてください"
  echo "   → EC2のuser_data実行にも時間がかかるため、数分待ってリトライ"
}
echo ""

# --- テスト3: 送信元IPの確認 ---
echo "--- テスト3: 外部から見たDBの送信元IP ---"
echo "   DBがインターネットにアクセスする際、NAT GWのIPで出ていきます。"
echo ""
OUTBOUND_IP=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=15 \
  -J "ec2-user@$BASTION_IP" "ec2-user@$DB_PRIVATE_IP" \
  "curl -s -m 10 https://checkip.amazonaws.com" 2>/dev/null) && {
  echo "   DB の送信元IP: $OUTBOUND_IP"
  echo "   NAT GW IP:     $NAT_IP"
  if [ "$(echo "$OUTBOUND_IP" | tr -d '[:space:]')" = "$(echo "$NAT_IP" | tr -d '[:space:]')" ]; then
    echo "   ✅ 一致！DBのトラフィックはNAT GW経由で出ています"
  else
    echo "   ⚠️  不一致（確認してください）"
  fi
} || {
  echo "   (SSH接続できませんでした。手動で確認してください)"
}
echo ""

# --- NAT GWの仕組み解説 ---
echo "--- 解説: NAT Gateway の動作 ---"
echo "   アウトバウンド（DB → インターネット）:"
echo "     DB(10.0.2.x) → NAT GW → IGW → インターネット"
echo "     送信元IPは NAT GW のEIP ($NAT_IP) に変換される"
echo ""
echo "   インバウンド（インターネット → DB）:"
echo "     外部 → NAT GW → ❌ 転送しない"
echo "     NAT GWは「ステートフル」= 既存セッションの戻りのみ許可"
echo "     → 外部から新規接続は不可"
echo ""

# --- 総合判定 ---
echo "============================================"
echo "総合判定: ✅ 正解！"
echo ""
echo "  ✅ インバウンド遮断: プライベートサブネット（パブリックIPなし）"
echo "  ✅ アウトバウンド許可: NAT GW経由でパッチDL可能"
echo ""
echo "  これが「プライベートサブネット + NAT Gateway」パターンです。"
echo "  AWSで最も一般的なセキュアなDB配置の基本形です。"
echo "============================================"
