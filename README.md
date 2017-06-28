kakuyomu-dl.pl
===============================

カクヨム投稿小説自動ダウンローダ
-------------------------------

　カクヨムの投稿小説を青空文庫形式に変換してダウンロードする。

### 特徴

- ルビ対応
- 傍点対応
- cp932対応
- 追加分取得機能

# 導入方法

## 必要ライブラリ

```
    LWP::UserAgent
    HTML::TagParser;
    File::Basename
```

## インストール

`  git clone  https://github.com/yama-natuki/kakuyomu-dl.git `

# 使い方

　落としたい小説の目次ページのurlをコピーしたら、

`    ./kakuyomu-dl.pl 目次のurl  >  保存先ファイル名 `

でファイルに保存される。


# ライセンス
　GPLv2

