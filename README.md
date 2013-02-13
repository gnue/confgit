# Confgit

分散している設定ファイルを git を使ってバージョン管理するためのツール

## Features

* 分散している設定ファイルを一括管理
* バージョン管理できる
* 一度ファイルを登録すると以後は backup/restore サブコマンドで簡単管理
* 慣れ親しんだ（？）git のサブコマンドがそのまま使える

## Installation

Add this line to your application's Gemfile:

    gem 'confgit'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install confgit

## 必要なソフトウェア

* 必須
  * ruby 1.9以上（1.9.3 でのみ動作確認）
  * git
* オプション
  * tree
  * tig

## Usage

固有のサブコマンドとgitのサブコマンドが使用できます

### 固有のサブコマンド一覧

	$ confgit repo						# リポジトリ一覧の表示
	$ confgit repo リポジトリ名			# カレントリポジトリの変更
	$ confgit root						# ルートの表示
	$ confgit root ディレクトリ名			# ルートの変更
	$ confgit root -d					# ルートの設定を削除する（デフォルト値 / になる）
	$ confgit add ファイル名				# ファイルを追加
	$ confgit rm ファイル名				# ファイルを削除
	$ confgit rm -rf ディレクトリ名		# ディレクトリを削除
	$ confgit backup					# バックアップ（更新されたもののみ）
	$ confgit backup -f					# 強制バックアップ
	$ confgit restore					# リストア（更新されたもののみ）
	$ confgit restore -f				# 強制リストア
	$ confgit tree						# ツリー表示（要treeコマンド）
	$ confgit tig						# tigで表示（要tigコマンド）
	$ confgit path						# リポジトリのパスを表示
	$ confgit list						# 一覧表示

### gitのサブコマンド

	$ confgit commit -m 'ログ'
	$ confgit status
	$ confgit log
	$ confgit reset --hard
	$ confgit branch ブランチ名
	$ confgit tag タグ名

* その他 git のサブコマンドがそのまま使えます

### 使用例

#### システム環境の管理

管理するファイルを追加してコミット

	$ confgit add /etc/apache2/httpd.conf
	$ confgit add /etc/postfix/aliases
	$ confgit commit -m '設定を追加'

変更されたファイルをバックアップする

	$ confgit backup
	--> etc/apache2/httpd.conf [yN]: y
	$ confgit commit -m '設定を変更'

変更されたファイルを復元する

	$ sudo confgit restore
	<-- etc/apache2/httpd.conf [yN]: y

* そのたままだと書込み権限がないので sudo で実行する

#### ユーザ環境の管理

リポジトリを変更してルートをホームディレクトリにする

	$ confgit repo myconfig
	$ confgit root ~

* ルートの変更は初回のみ行うようにする（ファイルを追加したあとに変更すると整合性がとれなくなってしまうので注意）
* ルートを変更することによりホームディレクトリからのパスで記録される（treeサブコマンドで確認すると違いが一目瞭然）
* リポジトリはいくつでも作成できるので、管理対象に合わせてルートを変更して使い分けてもよい

管理するファイルを追加してコミット

	$ confgit add ~/.bash_profile
	$ confgit add ~/.bashrc
	$ confgit commit -m '設定を追加'

変更されたファイルをバックアップする

	$ emacs ~/.bash_profile
	$ confgit backup
	--> .bash_profile [yN]: y
	$ confgit commit -m '設定を変更'

変更されたファイルを復元する

	$ confgit restore
	<-- .bash_profile [yN]: y

#### Tips

俯瞰する

	$ confgit tree -a
	.
	├── Users
	|   └── foo
	|       ├── .bash_profile
	|       └── .bashrc
	└── etc
	    ├── apache2
	    │   └── httpd.conf
	    └── postfix
	        └── aliases

* ドットファイルは -a を付けて表示する

リポジトリに cd して直接ファイルを編集や git の操作をしたいとき

	$ pushd `confgit path`
	（作業）
	$ popd

bash で補完機能を使う

	$ curl -O https://raw.github.com/gnue/confgit/master/etc/bash_completion.d/confgit
	$ cp confgit $BASH_COMPLETION_DIR
	（再ログイン）

* bash-completion がインストールされて使用可能な状態になっている必要がある
* 使える補完
  * 固有サブコマンド
  * `confgit repo` でリポジトリを補完

## Directory

	~/.etc/confgit
	├── confgit.conf		-- 設定ファイル
	└── repos
	    ├── current			-- カレントリポジトリへのシンボリックリンク
	    └── `hostname`		-- リポジトリ（デフォルト）

## FAQ

* [Q] ~/.etc って何？

  [A] ホームディレクトリにドットファイルが叛乱しているUNIX文化の悪しき伝統への提案。
      いいかげん、ホームディレクトリ直下にドットファイルをつくるのを減らしましょう。
      各ソフトの設定ファイルがひとつに場所（~/.etc）にまとまってるほうがわかりやすいし管理しやすいでしょ。

* [Q] confgit.conf って特に使われてないみたいなんですけど？

  [A] 最初の頃にカレントリポジトリを覚えておくのとかに使ってましたが、カレントリポジトリはシンボリックリンク
      に変更したりとかしてしまって現在は空の状態になってしまいました。
      将来的には表示色の変更とかカスタマイズに使えるようになるかもしれません。

## TODO

* user/group の情報を保存
* user/group の情報を復元
* リストアで書込み権限がない場合は sudo でファイルコピーを行えるようにする
* `confgit サブコマンド -h` のローカライズ

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
