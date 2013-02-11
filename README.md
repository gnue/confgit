# Confgit

設定ファイルを git で管理するためのツール

## Installation

Add this line to your application's Gemfile:

    gem 'confgit'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install confgit

## Usage

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
	$ confgit restore					# リストア（更新されたもののみ、まだ実際のファイルコピーは行えません）
	$ confgit restore -f				# 強制リストア（まだ実際のファイルコピーは行えません）
	$ confgit tree						# ツリー表示（要treeコマンド）
	$ confgit tig						# tigで表示（要tigコマンド）
	$ confgit path						# リポジトリのパスを表示
	$ confgit list						# 一覧表示

## Directory

	~/.etc/confgit
	├── confgit.conf		-- 設定ファイル
	└── repos
	    ├── current			-- カレントリポジトリへのシンボリックリンク
	    └── `hostname`		-- リポジトリ（デフォルト）

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## TODO

* user/group の情報を保存
* user/group の情報を復元
* リストアで書込み権限がない場合は sudo でファイルコピーを行えるようにする
