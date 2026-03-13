# 発表者ガイド: DBサーバーを守るネットワーク設計

30分 / デモ形式 / AWS経験者20名向け

## ゼミ前の準備（開始15分前まで）

### 1. AWS 認証

```bash
aws --profile aws-semi sts get-caller-identity
```

Slack DM に認証リクエストが来たら許可。

### 2. 全選択肢を apply

NAT GW の作成に約2分かかるので、先に全部 apply しておく。

```bash
export AWS_PROFILE=aws-semi

# タブ1
cd ~/Programming/private-repos/aws-terraform-examples/db-network-design/option-a
terraform init && terraform apply -auto-approve

# タブ2
cd ~/Programming/private-repos/aws-terraform-examples/db-network-design/option-b
terraform init && terraform apply -auto-approve

# タブ3
cd ~/Programming/private-repos/aws-terraform-examples/db-network-design/option-c
terraform init && terraform apply -auto-approve

# タブ4
cd ~/Programming/private-repos/aws-terraform-examples/db-network-design/option-d
terraform init && terraform apply -auto-approve
```

### 3. IP をメモ

各タブで `terraform output` を実行し、以下をメモしておく。

```bash
# option-a
terraform output db_public_ip       # → メモ

# option-b
terraform output db_public_ip       # → メモ
terraform output nat_gateway_ip     # → メモ

# option-c
terraform output bastion_public_ip  # → メモ
terraform output db_private_ip      # → メモ

# option-d
terraform output bastion_public_ip  # → メモ
terraform output db_private_ip      # → メモ
terraform output nat_gateway_ip     # → メモ
```

### 4. SSH 接続確認（option-c, d）

key pair のパス:

```bash
PEM=~/Programming/private-repos/aws-terraform-examples/db-network-design/saa-q07-handson.pem
```

※ key pair が削除済みの場合は再作成:

```bash
AWS_PROFILE=aws-semi aws ec2 create-key-pair \
  --key-name saa-q07-handson \
  --query 'KeyMaterial' --output text > "$PEM"
chmod 600 "$PEM"
```

再作成した場合は option-c, d の Terraform に `key_name = "saa-q07-handson"` が入っていることを確認し、再 apply が必要。

接続テスト:

```bash
# option-d（正解）で確認
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -i "$PEM" \
  -o "ProxyCommand ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $PEM -W %h:%p ec2-user@<BASTION_IP>" \
  ec2-user@<DB_PRIVATE_IP> \
  "curl -s -m 10 https://checkip.amazonaws.com"
```

NAT GW の IP が返ってくれば OK。

### 5. 画面の準備

- **ブラウザ**: slides.html を開いておく（プレゼンモード: `p` キーで発表者ノート）
- **ターミナル**: 4タブ（option-a〜d）+ フォントサイズ大きめ
- **順番**: slides.html → ターミナルタブ切替でデモ

---

## 進行台本（30分）

### 0:00-2:00 — 導入（スライド1〜3）

> 「今日は SAA の問題を Terraform で全選択肢をデプロイして、正解・不正解を実際に検証します。暗記じゃなくて体で覚えましょう。」

### 2:00-5:00 — 問題提示（スライド: exam）

> 「まずこの問題を読んでみてください。」

15秒くらい読む時間を取る。

> 「どれが正解だと思いますか？ A だと思う人？ B？ C？ D？」

挙手させる。ここで盛り上がるとその後の検証が楽しくなる。

### 5:00-8:00 — 前提知識（スライド: IGW vs NAT GW）

AWS 経験者なので**軽めに**。

> 「IGW と NAT GW の違いだけ確認しておきます。」
> 「IGW は双方向。NAT GW はアウトバウンドのみ。」
> 「重要なのは、**IGW はパブリック IP を持たないインスタンスのトラフィックを転送しない**。これ、後で実際に見ます。」

### 8:00-10:00 — 選択肢 A デモ（2分、サクッと）

ターミナルのタブ1（option-a）に切り替え。

```bash
terraform output db_public_ip
```

> 「はい、パブリック IP が出ましたね。`52.xx.xx.xx`。この時点でインターネットからルーティング可能です。SG で絞ってはいますが、構造的にアウトです。A を選んだ方、残念でした。」

### 10:00-12:00 — 選択肢 B デモ（2分、サクッと）

タブ2（option-b）に切り替え。

```bash
terraform output db_public_ip
terraform output nat_gateway_ip
```

> 「また パブリック IP が出ています。NAT GW も作っていますが、これはプライベートサブネットのルートテーブルに紐づいています。DB はパブリックにいるので無関係。NAT GW の費用（月 $45）が無駄にかかるだけです。」

### 12:00-18:00 — 選択肢 C デモ（6分、じっくり）

タブ3（option-c）に切り替え。

```bash
terraform output db_public_ip
# → 空
```

> 「パブリック IP がない。インバウンド遮断はできています。ではアウトバウンドは？」

SSH でDBに入る:

```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -i "$PEM" \
  -o "ProxyCommand ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $PEM -W %h:%p ec2-user@<BASTION_C_IP>" \
  ec2-user@<DB_C_PRIVATE_IP>
```

DB上で:

```bash
curl -m 10 https://example.com
# → タイムアウト
```

> 「タイムアウトしました。ルートテーブルには IGW へのルートがあるのに、なぜ通信できないか。」
> 「IGW はパブリック IP を持たないインスタンスの通信を転送しません。NAT 変換する先の IP がないからです。」

`exit` で抜ける。

### 18:00-25:00 — 選択肢 D デモ（7分、メイン）

タブ4（option-d）に切り替え。

```bash
terraform output db_public_ip
# → 空 ✅
```

SSH でDBに入る:

```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -i "$PEM" \
  -o "ProxyCommand ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $PEM -W %h:%p ec2-user@<BASTION_D_IP>" \
  ec2-user@<DB_D_PRIVATE_IP>
```

DB上で:

```bash
curl -m 10 https://example.com
# → 成功！
```

> 「来ました！レスポンスが返ってきます。」

```bash
curl -m 10 https://checkip.amazonaws.com
# → NAT GW の IP
```

> 「送信元 IP を見てください。`13.xx.xx.xx` — これは NAT Gateway の Elastic IP です。DB のプライベート IP ではなく、NAT GW の IP で外に出ている。外部から見ると DB の存在がわからない。」

`exit` で抜ける。

> 「これが正解です。D を選んだ方、おめでとうございます。」

### 25:00-28:00 — まとめ（スライド: 比較表 + 3つのポイント）

> 「まとめます。覚えてほしいのは3つ。」
>
> 1. パブリックサブネットに置いた時点でパブリック IP が付く。インターネットから到達可能。
> 2. IGW はパブリック IP がないインスタンスを無視する。
> 3. NAT GW は外向き通信だけ許可する仕組み。
>
> 「この『プライベートサブネット + NAT GW』パターンは AWS で最も基本。RDS も Lambda も ECS も同じ考え方。」

### 28:00-30:00 — コスト注意 + クロージング

> 「最後にコストの話。NAT GW は**停止できない**。消すしかない。月 $45 かかります。ハンズオンで作ったら必ず destroy してください。」
> 「今日の内容は Zenn 記事にもまとめています。後で共有します。Terraform のコードも公開しているので、手元で試してみてください。」

---

## ゼミ後の片付け

```bash
export AWS_PROFILE=aws-semi

cd ~/Programming/private-repos/aws-terraform-examples/db-network-design/option-a && terraform destroy -auto-approve
cd ~/Programming/private-repos/aws-terraform-examples/db-network-design/option-b && terraform destroy -auto-approve
cd ~/Programming/private-repos/aws-terraform-examples/db-network-design/option-c && terraform destroy -auto-approve
cd ~/Programming/private-repos/aws-terraform-examples/db-network-design/option-d && terraform destroy -auto-approve
```

AWS コンソールで確認:
- VPC → NAT ゲートウェイ → 0件
- EC2 → インスタンス → 0件
- VPC → Elastic IP → 0件
- EC2 → キーペア → `saa-q07-handson` を削除

```bash
AWS_PROFILE=aws-semi aws ec2 delete-key-pair --key-name saa-q07-handson
```
