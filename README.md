# CodexPetWatchSprite

Codex pets の `8 x 9` スプライトシートを iOS / watchOS の SwiftUI で再生するための Swift Package です。

## Requirements

- iOS 15+
- watchOS 8+
- Swift 5.9+

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

## Sprite Sheet Format

このパッケージに同梱している `spritesheet.png` / `spritesheet.webp` は Codex pets 形式です。watchOS では PNG を優先して読み込みます。

- atlas: `1536 x 1872`
- grid: `8 columns x 9 rows`
- cell: `192 x 208`

各行のアニメーション時間は `CodexPetSpriteView.Animation` に定義しています。

## Petdex Gallery

iOS デモアプリには Petdex manifest (`https://petdex.crafter.run/api/manifest`) から一覧を取得し、選択した pet の `spritesheetUrl` をアプリ内キャッシュへ保存して表示するギャラリーを入れています。右下の調整ボタンから `Petdex Gallery` を押すと、別画面で検索とインストールができます。
