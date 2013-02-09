# coding: UTF-8


require 'optparse'


module Confgit

class CLI

	COMMANDS = <<EOD
commands:
    repo                             リポジトリ一覧の表示
    repo REPO                        カレントリポジトリの変更
    root                             ルートの表示
    root PATH                        ルートの変更
    add FILE…                        ファイルを追加
    rm FILE…                         ファイルを削除
    rm -rf DIRECTORY                 ディレクトリを削除
    backup                           バックアップ（更新されたもののみ）
    restore                          リストア（更新されたもののみ、まだ実際のファイルコピーは行えません）
    tree                             ツリー表示（要treeコマンド）
    tig                              tigで表示（要tigコマンド）
    path                             リポジトリのパスを表示
    list                             一覧表示
EOD

	def self.run(argv = ARGV, options = {})
		CLI.new.run(argv, options)
	end

	def run(argv = ARGV, options = {})
		trap ('SIGINT') { abort '' }

		# コマンド引数の解析
		command = nil

		OptionParser.new { |opts|
			begin
				opts.version = VERSION if defined?(VERSION)
				opts.banner = "Usage: #{opts.program_name} <command> [<args>]"

				opts.on('-h', '--help', 'Show this message')	{ abort opts.help }
				opts.separator ''
				opts.separator COMMANDS

				opts.order!(argv)
				command = argv.shift
				abort opts.help unless command
			rescue => e
				abort e.to_s
			end
		}

		action(command, argv, options)
	end

	# アクションの実行
	def action(command, argv, options = {})
		command = command.gsub(/-/, '_')

		# オプション解析
		options_method = "options_#{command}"
		options.merge!(send(options_method, argv)) if respond_to?(options_method)

		confgit = Repo.new
		confgit.send("confgit_#{command}", options, *argv)
	end

	# サブコマンド・オプションのバナー作成
	def banner(opts, method, *args)
		subcmd = method.to_s.gsub(/^.+_/, '')
		["Usage: #{opts.program_name} #{subcmd}", *args].join(' ')
	end

	# オプション解析を定義する
	def self.define_options(command, *banner, &block)
		define_method "options_#{command}" do |argv|
			options = {}

			OptionParser.new { |opts|
				begin
					opts.banner = banner(opts, command, *banner)
					block.call(opts, argv, options)
				rescue => e
					abort e.to_s
				end
			}

			options
		end
	end

	# オプション解析

	# カレントリポジトリの表示・変更
	define_options(:repo, '[options] [<repo>]') { |opts, argv, options|
		opts.on('-d', 'remove repo') { options[:remove] = true }
		opts.on('-D', 'remove repo (even if current repository)') {
				options[:remove] = true
				options[:force] = true
			}
		opts.parse!(argv)
	}

	# ルートの表示・変更
	define_options(:root, '[PATH]') { |opts, argv, options|
		opts.on('-d', 'default root') { options[:remove] = true }
		opts.parse!(argv)
	}

	# ファイルを管理対象に追加
	define_options(:add, '<file>…') { |opts, argv, options|
		opts.parse!(argv)
		abort opts.help if argv.empty?
	}

	# バックアップする
	define_options(:backup, '[options] [<file>…]') { |opts, argv, options|
		opts.on('-n', '--dry-run', 'dry run')	{ options[:yes] = false }
		opts.on('-y', '--yes', 'yes')			{ options[:yes] = true }
		opts.on('-f', 'force')					{ options[:force] = true }
		opts.parse!(argv)
	}

	# リストアする
	define_options(:restore, '[options] [<file>…]') { |opts, argv, options|
		opts.on('-n', '--dry-run', 'dry run')	{ options[:yes] = false }
		opts.on('-y', '--yes', 'yes')			{ options[:yes] = true }
		opts.on('-f', 'force')					{ options[:force] = true }
		opts.parse!(argv)
	}

	# 一覧表示する
	define_options(:list, '[options] [<file>…]') { |opts, argv, options|
		opts.on('-8', 'mode display octal')	{ options[:octal] = true }
		opts.parse!(argv)
	}
end

end
