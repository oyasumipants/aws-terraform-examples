---
description: SAA/AWS問題からTerraformハンズオン教材（Terraform + Marpスライド + 検証スクリプト）を自動生成する
argument-hint: [問題のスクリーンショットパスまたはテキスト]
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, Agent, AskUserQuestion]
---

# AWS ハンズオン教材生成

SAA等のAWS認定試験の問題を入力として、全選択肢のTerraform実装 + Marpスライド + 検証スクリプトを生成する。

## 引数

ユーザーの入力: $ARGUMENTS

## テンプレートの参照

既存の教材を参考にして、同じクオリティ・同じ構造で新しい教材を生成する。

**必ず以下のテンプレートを読み込んでから作業を開始すること:**

- `db-network-design/slides.md` — スライドの構造・書き方
- `db-network-design/theme.css` — Marpテーマ（共通で使用）
- `db-network-design/option-d/main.tf` — Terraform の書き方
- `db-network-design/option-d/verify.sh` — 検証スクリプトの書き方
- `db-network-design/README.md` — READMEの書き方

## Step 1: 問題の解析

引数がスクリーンショットの場合はReadで画像を読み取る。

問題から以下を抽出する:
- **問題文**: 原文そのまま
- **要件**: 問題が求めていること（箇条書き）
- **選択肢**: 全選択肢のテキスト
- **正解**: どれが正解か（理由付き）
- **各選択肢の不正解理由**: なぜダメか

## Step 2: ディレクトリ名の決定

AskUserQuestionで以下を確認:
- **ディレクトリ名**: 英語ケバブケース（例: `db-network-design`, `s3-bucket-access-control`）
- 問題番号は含めない（パブリック公開するため）

## Step 3: Terraform の生成

各選択肢ごとに `option-{a,b,c,d}/main.tf` を生成する。

### Terraform の方針
- **全選択肢を実装する**（正解も不正解も）
- 各 main.tf の冒頭に日本語コメントで「この選択肢の構成」と「なぜ正解/不正解か」を記載
- provider は `aws` で region は `ap-northeast-1`
- リソースの命名は `var.project_name` をプレフィックスにする
- EC2 は Amazon Linux 2023 の最新 AMI を data source で取得
- key_name は variable で外から渡せるようにする（デフォルト空文字）
- output に `verdict` を含め、判定結果と検証手順を表示する
- **不正解の選択肢**: 構成上の問題点が検証で明らかになるようにする
- **正解の選択肢**: 踏み台EC2（bastion）を含め、SSH経由で検証できるようにする（必要な場合）

### コスト意識
- 最小インスタンスタイプ（t3.micro）を使う
- 不要なリソースは作らない
- NAT Gateway等の課金リソースを使う場合は output で注意喚起する

## Step 4: 検証スクリプトの生成

各選択肢ごとに `option-{a,b,c,d}/verify.sh` を生成する。

### verify.sh の方針
- `terraform output` から IP 等を取得
- 自動で疎通テスト（nmap, curl, ssh 等）を実行
- 結果の判定（✅/❌）と解説を表示
- **答え合わせ用途**（参加者はまず手動で検証し、その後 verify.sh で確認）

## Step 5: Marp スライドの生成

`slides.md` を生成する。テーマは `db-network-design/theme.css` を共通利用（シンボリックリンクまたはコピー）。

### スライドの構成（テンプレート準拠）

1. **タイトル** (`_class: title`)
   - テーマに沿ったタイトル（例: "DBサーバーを守るネットワーク設計"）
   - "Terraform ハンズオン" サブタイトル
   - 「AWSゼミ」等の特定組織向け文言は入れない

2. **今日やること / ゴール**（各1枚）

3. **前提知識**（`_class: section` + 解説スライド群）
   - この問題を理解するのに必要なAWSサービスの基礎をゼロから説明
   - 1スライド1メッセージ、5行以内

4. **問題**（`_class: section` + `_class: exam`）
   - 試験UI風のスライド1枚に問題文＋選択肢をまとめる
   - exam-header, exam-body, exam-question, exam-options の div 構造を使う

5. **ハンズオン**（`_class: section` + 各選択肢の検証）
   - 環境準備 → 各選択肢（構成図 → 検証 → 判定）の順
   - 構成図はASCIIアートで（コードブロック内）
   - 検証コマンドは参加者が手動で打つ前提で記載
   - 各選択肢の最後に `terraform destroy -auto-approve`

6. **コストの話**（`_class: section` + 料金表 + 片付けチェックリスト）
   - 使用リソースの料金一覧
   - 課金が止まらないリソース（NAT GW等）の注意喚起
   - destroy 後のコンソール確認手順
   - コスト最適化 Tips（該当する場合）

7. **まとめ**（`_class: section` + 比較表 + 覚えるべきポイント + 実務応用）

8. **おつかれさまでした**（`_class: title`）

### スライドのデザインルール
- **1スライド1メッセージ**
- **5行以内**
- **改行で文が切れないようにする**（1文は1行で書く）
- 強調（`**bold**`）はアクセントカラー（オレンジ）で表示される
- テーブルは簡潔に

## Step 6: README の生成

テンプレートの `db-network-design/README.md` を参考に、手動検証手順付きの README を生成する。

## Step 7: theme.css の配置

```bash
cp db-network-design/theme.css <new-dir>/theme.css
```

## Step 8: ルート README の更新

`README.md`（リポジトリルート）のハンズオン一覧テーブルに新しい教材を追記する。

## Step 9: ビルド確認

```bash
cd <new-dir>
npx @marp-team/marp-cli --no-stdin --theme theme.css slides.md --html --output slides.html
open slides.html
```

## 注意事項

- **パブリック公開前提**: 特定組織・チーム名は含めない
- **問題番号は含めない**: ディレクトリ名もスライドも
- **日本語で記述**: Terraform のコメント・スライド・README 全て日本語
- **Terraform は destroy しやすい設計**: state ファイルの注意喚起を含める
- **コスト注意喚起を必ず含める**: 課金リソースがある場合は特に
