# CodexPetWatchSprite

Codex pets の `8 x 9` スプライトシートを iOS / watchOS の SwiftUI で再生するための Swift Package です。

## Requirements

- iOS 15+
- watchOS 8+
- Swift 6.3+

このパッケージは Swift 6 言語モードでビルドします。Xcode プロジェクト側も `SWIFT_VERSION = 6.0` に設定しています。

## Usage

このリポジトリを Swift Package として Xcode プロジェクトに追加し、表示したい View で import します。

```swift
import CodexPetWatchSprite
import SwiftUI

struct ContentView: View {
    var body: some View {
        CodexPetSpriteView(animation: .idle, scale: 0.45)
    }
}
```

Apple Watch では `scale: 0.35` から `0.6` 程度が扱いやすいサイズです。

## Apple Watch Complication

Watch アプリには WidgetKit complication を同梱しています。watchOS 9 以降の時計盤で `Codex Pet` を追加すると、pet の代表フレームや `Codex Pet` ラベルを表示し、タップで Watch アプリを開けます。

iPhone 経由で実機 Apple Watch に入れる場合は、Xcode で iOS 側の `Codex Pet` scheme を iPhone 実機に対して Run してください。iOS app の `Watch/` 配下に `Codex Pet Watch App.app` が同梱されるため、Watch app 単体を直接接続してインストールできない場合でも、ペアリング済み iPhone から Watch アプリとして配布できます。

対応 family:

- `accessoryCircular`
- `accessoryRectangular`
- `accessoryInline`
- `accessoryCorner`

時計盤上の WidgetKit complication は glanceable な静的表示が前提です。watchOS 26 では Liquid Glass、Smart Stack Relevance API、Control Widget API などで見せ方や出し分けの幅は増えますが、pet を時計盤上で常時アニメーションさせる用途には向きません。

## Animations

- `idle`
- `runningRight`
- `runningLeft`
- `waving`
- `jumping`
- `failed`
- `waiting`
- `running`
- `review`

## AI Behavior

iOS / Watch のデモアプリでは、単純なランダム移動ではなく `CodexPetBehaviorEngine` で pet の行動を決めています。

エンジンは energy / curiosity / sociability と画面端への近さをもとに、探索、近場の確認、休憩、挨拶、ジャンプ、中央付近への復帰を重み付きで選びます。iOS デモでは右下の調整ボタンから `AI Behavior` をオン / オフできます。

詳しい設計と UI 連携は [Behavior Engine](docs/BehaviorEngine.md) にまとめています。

## Display Presets

iOS / Watch のデモアプリでは、細かい数値調整ではなくプリセットで見た目を変更できます。

- `CodexPetAnimationSpeedPreset`: ゆっくり / 標準 / 元気。アニメーションごとに表示時間を調整し、走り・待機・ジャンプがそれぞれ自然な速度になるようにします。
- `CodexPetSizePreset`: 極小 / 小 / 中 / 大 / 特大。各プラットフォームの基準サイズに対して、見やすい範囲でサイズを切り替えます。

## Sprite Sheet Format

このパッケージに同梱している `spritesheet.png` / `spritesheet.webp` は Codex pets 形式です。watchOS では PNG を優先して読み込みます。

- atlas: `1536 x 1872`
- grid: `8 columns x 9 rows`
- cell: `192 x 208`

各行のアニメーション時間は `CodexPetSpriteView.Animation` に定義しています。

## Petdex Gallery

iOS デモアプリには Petdex manifest (`https://petdex.crafter.run/api/manifest`) から一覧を取得し、選択した pet の `spritesheetUrl` をアプリ内キャッシュへ保存して表示するギャラリーを入れています。右下の調整ボタンから `Petdex Gallery` を押すと、別画面で検索とインストールができます。

## Development

テストは Swift Testing で実装しています。

```sh
swift test
```

iOS / watchOS のデモアプリは Xcode の以下の scheme で確認できます。

- `Codex Pet`
- `Codex Pet Watch App`
