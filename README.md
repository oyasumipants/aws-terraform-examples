# AWS Terraform Examples

SAA の問題を Terraform で全選択肢を構築し、正解・不正解を自分の手で検証するハンズオン教材集。

## ハンズオン一覧

| # | テーマ | ディレクトリ | 学べること |
|---|--------|-------------|-----------|
| 1 | [DBサーバーのネットワーク設計](./db-network-design/) | `db-network-design/` | パブリック/プライベートサブネット、IGW vs NAT GW |
| - | [CloudFront カスタムドメイン](./cloudfront-custom-domain/) | `cloudfront-custom-domain/` | CloudFront + ACM + Route53 |

## 使い方

```bash
# 1. 各ハンズオンのディレクトリに移動
cd db-network-design/option-a

# 2. 構築
terraform init
terraform apply -auto-approve

# 3. 検証（READMEの手順に従う）

# 4. 片付け
terraform destroy -auto-approve
```

## スライド

各ハンズオンにはMarp スライドが含まれています。

```bash
cd db-network-design
npx @marp-team/marp-cli --no-stdin --theme theme.css slides.md --html --output slides.html
open slides.html
```
