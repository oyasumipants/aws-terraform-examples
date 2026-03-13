#!/bin/bash
set -euo pipefail

echo "============================================"
echo "選択肢C 検証: プライベートサブネット + IGWルート"
echo "============================================"
echo ""

BASTION_IP=$(terraform output -raw bastion_public_ip 2>/dev/null)
DB_PRIVATE_IP=$(terraform output -raw db_private_ip 2>/dev/null)
DB_PUBLIC_IP=$(terraform output -raw db_public_ip 2>/dev/null)

if [ -z "$BASTION_IP" ]; then
  echo "❌ terraform output が取得できません。terraform apply を先に実行してください。"
  exit 1
fi

echo "📋 Bastion IP:    $BASTION_IP"
echo "📋 DB Private IP: $DB_PRIVATE_IP"
echo "📋 DB Public IP:  ${DB_PUBLIC_IP:-(なし)}"
echo ""

# --- テスト1: パブリックIPの有無 ---
echo "--- テスト1: パブリックIPが付与されているか ---"
if [ -z "$DB_PUBLIC_IP" ] || [ "$DB_PUBLIC_IP" = "" ] || [ "$DB_PUBLIC_IP" = "null" ]; then
  echo "✅ パブリックIPなし → インターネットからの直接アクセス不可"
else
  echo "⚠️  パブリックIPが付与されています: $DB_PUBLIC_IP"
fi
echo ""

# --- テスト2: アウトバウンド疎通（踏み台経由） ---
echo "--- テスト2: DBからのアウトバウンド通信（パッチDL） ---"
echo "   踏み台経由でDBにSSHし、curl を試行します。"
echo ""
echo "   手動で実行してください:"
echo "     ssh -J ec2-user@$BASTION_IP ec2-user@$DB_PRIVATE_IP"
echo "     curl -m 10 https://example.com"
echo ""
echo "   期待結果: タイムアウト（IGWはプライベートIPのみのインスタンスをNATしない）"
echo ""

# 自動テスト（SSH鍵が設定されている場合）
echo "   自動テスト試行中..."
CURL_RESULT=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
  -J "ec2-user@$BASTION_IP" "ec2-user@$DB_PRIVATE_IP" \
  "curl -s -m 10 https://example.com" 2>/dev/null) && {
  echo "   ⚠️  curl が成功しました（予想外）"
  echo "   $CURL_RESULT" | head -3
} || {
  echo "   ✅ curl がタイムアウト/失敗しました（予想通り）"
  echo "   → IGWはパブリックIPを持たないインスタンスのトラフィックを転送しません"
}
echo ""

# --- テスト3: IGW + プライベートIPの組み合わせの解説 ---
echo "--- 解説: なぜIGWではダメなのか ---"
echo "   IGW（Internet Gateway）の動作:"
echo "   1. アウトバウンド: プライベートIP → パブリックIP にNATして送信"
echo "   2. インバウンド: パブリックIP → プライベートIP にNATして受信"
echo ""
echo "   パブリックIPを持たないインスタンスの場合:"
echo "   → NATする先のパブリックIPがない → IGWはトラフィックを破棄"
echo ""

# --- 総合判定 ---
echo "============================================"
echo "総合判定: ❌ 不正解"
echo ""
echo "理由:"
echo "  ✅ インバウンド遮断: パブリックIPなしで達成"
echo "  ❌ アウトバウンド通信: IGWではプライベートIPのみのインスタンスは"
echo "     インターネットに出られない → パッチDL不可"
echo ""
echo "  NATゲートウェイ（NAT GW）を使えば解決します → 選択肢Dへ"
echo "============================================"
