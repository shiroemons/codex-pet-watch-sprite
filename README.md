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
