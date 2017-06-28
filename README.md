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
- 巡回機能

# 導入方法

## 必要ライブラリ

```
    LWP::UserAgent
    HTML::TagParser
    File::Basename
```

## インストール

`  git clone  https://github.com/yama-natuki/kakuyomu-dl.git `

# 使い方

　落としたい小説の目次ページのurlをコピーしたら、

`    ./kakuyomu-dl.pl 目次のurl  >  保存先ファイル名 `

でファイルに保存される。

# 巡回

　巡回リストを用意すれば自動で巡回してまとめて落とす。

　保存先は指定ディレクト以下にサブディレクトリを自動的に作成して個別に保存される。

　例えば巡回リスト __check.lst__ で、保存先ベースディレクトリを __~/book__ 以下に保存したい場合、

`    ./kakuyomu-dl.pl -c check.lst -s ~/book `

とする。

　次回以降は保存した後に追加された部分だけダウンロードする。

## 巡回リスト

```
    title = 作品名
    file_name = 保存するファイル名
    url = https://kakuyomu.jp/works/xxxxxxxxxxxxxxxxxxx
```
　の形式でリストを記述。各レコードは空行で区切る。

　同梱のサンプル参照。


# ライセンス
　GPLv2

