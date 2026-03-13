---
description: Terraform の構成から AWS 構成図（PNG）を生成する
argument-hint: [ハンズオンディレクトリパス（例: db-network-design）]
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, Agent, mcp__playwright__browser_run_code, mcp__playwright__browser_close]
---

# 構成図生成 Skill

Terraform の main.tf を解析し、HTML テンプレートベースで AWS 構成図を生成する。

## 引数

ハンズオンディレクトリ: $ARGUMENTS

## Step 1: 構成の解析

対象ディレクトリ内の各 `option-*/main.tf` を読み込み、以下を抽出する:

- VPC / サブネット構成（CIDR、パブリック/プライベート）
- ゲートウェイ（IGW, NAT GW）
- EC2 インスタンス（用途、サブネット配置、パブリックIP有無）
- ルートテーブル設定
- セキュリティグループのルール
- その他のリソース（RDS, ALB, S3 等）
- 正解/不正解の判定（main.tf 冒頭コメントから）

## Step 2: HTML 生成

`shared/diagram-templates/base-template.html` を参考に、各選択肢の構成図 HTML を生成する。

### デザインルール

リファレンス実装: `db-network-design/images/architecture-option-d.html`

#### キャンバス
- **960x540px** 固定（Marp スライド埋め込み用、body に width/height 指定）
- フォント: `'Noto Sans JP', 'Helvetica Neue', Arial, sans-serif`
- 全体パディング: `10px 120px`（左右に余白を取って中央寄せ）
- Flexbox 縦積みレイアウト（diagram > title > internet > vpc-box）

#### カラースキーム
- **VPC 枠・ヘッダー**: `#3b3f5c`（ダークネイビー）
- **パブリックサブネット**: 枠 `#248814`（緑）、背景 `#f2f6e8`
- **プライベートサブネット**: 枠 `#147d8c`（青緑）、背景 `#e6f7f7`
- **接続線・矢印・ラベル文字**: 全て `#00084d`（統一）
- **テキスト**: タイトル `#232F3E`、サブテキスト `#687078`
- **バナー（正解）**: 背景 `rgba(39,174,96,0.1)`、文字 `#27ae60`
- **バナー（不正解）**: 背景 `rgba(231,76,60,0.1)`、文字 `#e74c3c`

#### アイコン
- AWS 公式アイコン SVG を使用（`shared/aws-icons/` から相対パス `../../shared/aws-icons/`）
- リソースアイコン: 40x40px
- ヘッダーアイコン（VPC/サブネット）: 12-14px、`filter: brightness(10)` で白色化

#### リソースカード（`.res`）
- 白背景 `rgba(255,255,255,0.85)` + `border-radius: 6px` + `padding: 4px 6px`
- `z-index: 20`（接続線の上に表示）
- ラベル: 8px 太字、詳細: 7px グレー
- id 属性必須（JS で座標取得に使用）

#### サブネット
- 実線枠（`border: 2px solid`）、角丸 6px
- ヘッダーバー: 色付き背景 + 白文字 + CIDR 右寄せ
- ボディ: ルートテーブル情報（7px グレー pill）+ リソース横並び

#### 接続線（SVG オーバーレイ）
- **全てカーブ線**（`makeCurve` 関数: CSS Cubic Bezier）
- 線幅: 2px、色: `#00084d`
- 矢印マーカー: `markerWidth="8" markerHeight="5"`
- **JS で `getBoundingClientRect()` を使い動的に座標計算**（ハードコード禁止）
- `document.fonts.ready.then()` で描画タイミングを保証
- 双方向接続: 2本のカーブ線を ±5px オフセットで並べる

#### 接続ラベル
- 白背景 pill: `rgba(255,255,255,0.92)` + 薄い枠線 `#00084d` 0.8px + `rx: 4`
- テキスト: 9px 太字 `#00084d`
- `svg.insertBefore(rect, text)` で背景を先に描画

#### バナー
- VPC ボックス下部に正解/不正解バナー
- 正解: ✅ + 緑系、不正解: ❌ + 赤系

### ファイル出力先

各 HTML を対象ディレクトリの `images/` に保存（.gitignore で除外済み）:
```
<handson-dir>/images/architecture-option-a.html
<handson-dir>/images/architecture-option-b.html
...
```

## Step 3: スクリーンショット撮影 & セルフレビュー

### 前準備: ローカル HTTP サーバー起動

`file://` プロトコルはブロックされるため、リポジトリルートで HTTP サーバーを起動する:

```bash
cd <repo-root> && python3 -m http.server 8767
```

（Bash の `run_in_background: true` で起動）

### 撮影: Headless Chromium スクリプト

Chrome が起動中でも動作する headless Chromium を使う。`/tmp/screenshot.mjs` を作成して実行:

```javascript
import { chromium } from 'playwright';

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();
await page.setViewportSize({ width: 960, height: 540 });

const base = '<absolute-path-to-handson-dir>/images';
const options = ['a', 'b', 'c', 'd'];
for (const opt of options) {
  await page.goto(`http://localhost:8767/<handson-dir>/images/architecture-option-${opt}.html`, { waitUntil: 'load' });
  await page.waitForTimeout(500);
  await page.screenshot({ path: `${base}/architecture-option-${opt}.png`, type: 'png', scale: 'css' });
}
await browser.close();
```

実行: `node --experimental-vm-modules /tmp/screenshot.mjs`

前提: `npx playwright install chromium` で bundled Chromium をインストール済みであること。

### セルフレビュー: スクショを自分で確認して品質判定

撮影後、**必ず Read ツールで PNG を読み込み、以下の品質基準でセルフチェック**する。
問題があれば HTML を修正して再撮影。合格するまでサイクルを回す。

#### 品質判定基準

1. **ラベル重なりなし**: 接続ラベル同士、ラベルとリソースカード、ラベルとサブネットヘッダー/CIDR が重ならないこと
2. **線の接続先が明確**: カーブ線がどのリソースからどのリソースに繋がっているか一目で分かること。同一サブネット内の横並びリソース間は線を引かない（ルーティングは暗黙）
3. **矢印の向きがデータフローと一致**: 通信を開始する側から矢先が出ること（例: DB → NAT GW、Internet → IGW）
4. **失敗する通信の表現**: 赤い破線 `stroke: #cc0000; stroke-dasharray: 4,3` + 「× 転送されない」ラベルで表現
5. **未使用リソースの表現**: 薄い opacity（0.4）またはラベルで「無意味な配置」等を明示
6. **テキストの可読性**: 最小フォント 7px でも背景との十分なコントラストがあること
7. **キャンバス内に収まる**: 全要素が 960x540px 内に収まり、端が切れていないこと
8. **4枚の統一感**: 全選択肢で同じカラースキーム、フォントサイズ、カード形式を使っていること

### 後片付け

HTTP サーバーのバックグラウンドプロセスを停止する。
HTML ファイルは残す（デバッグ・再生成用、.gitignore で除外済み）。

## Step 4: slides.md への統合（オプション）

ユーザーに確認の上、slides.md 内の構成図を画像参照に差し替える:

```markdown
## A: 構成図

![選択肢Aの構成図](./images/architecture-option-a.png)
```

## 注意事項

- Playwright の bundled Chromium を使えば Chrome が開いていてもスクショ撮影可能
- HTML ファイルは中間成果物として images/ に残す（.gitignore で除外）
- 画像サイズは 960x540px で固定（Marp スライドに最適化）
- `npx playwright install chromium` が未実行の場合は先に実行すること
