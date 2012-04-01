#!/usr/bin/env ruby
# coding: UTF-8

=begin

= 設定ファイルを git で管理するためのツール


== 使い方

  $ confgit.rb add ファイル名				# ファイルを追加
  $ confgit.rb rm ファイル名				# ファイルを削除
  $ confgit.rb rm -rf ディレクトリ名		# ディレクトリを削除
  $ confgit.rb backup					# バックアップ（更新されたもののみ）
  $ confgit.rb backup -f				# 強制バックアップ
  $ confgit.rb restore					# リストア（更新されたもののみ、まだ実際のファイルコピーは行えません）
  $ confgit.rb restore -f				# 強制リストア（まだ実際のファイルコピーは行えません）
  $ confgit.rb tree						# ツリー表示（要treeコマンド）
  $ confgit.rb pwd						# リポジトリのパスを表示

== ディレクトリ構造

  ~/.etc/confgit
  ├── confgit.conf			-- 設定ファイル
  └── repos
      └── `hostname`		-- リポジトリ（デフォルト）

== 設定ファイル

confgit.rb

  {
     "repo":	"hostname",		// リポジトリの場所（デフォルトは hostname が設定される）
  }

== 動作環境

* 以下のライブラリが必要です（gem でインストールできます）
  * json

== TODO

* 更新確認を hash で行う（現在は日付で確認）
* user/group の情報を保存
* user/group の情報を復元
* リストアで実際のファイルコピーを行えるようにする

=end


require 'optparse'
require 'fileutils'
require 'etc'

require 'rubygems'
require 'json'


module WithColor
	ESC_CODES = {
		# Text attributes
		:clear		=> 0,
		:bold		=> 1,
		:underscore => 4,
		:blink		=> 5,
		:reverse	=> 7,
		:concealed	=> 8,

		# Foreground colors
		:fg_black	=> 30,
		:fg_red 	=> 31,
		:fg_green	=> 32,
		:fg_yellow	=> 33,
		:fg_blue	=> 34,
		:fg_magenta	=> 35,
		:fg_Cyan	=> 36,
		:fg_White	=> 37,

		# Background colors
		:bg_black	=> 40,
		:bg_red 	=> 41,
		:bg_green	=> 42,
		:bg_yellow	=> 43,
		:bg_blue	=> 44,
		:bg_magenta	=> 45,
		:bg_Cyan	=> 46,
		:bg_White	=> 47,
	}

	# エスケープシーケンスをセットする
	def set_color(*colors)
		colors.each { |color|
			print "\e[", ESC_CODES[color], "m"
		}
	end

	# カラー表示する
	def with_color(*colors)
		begin
			set_color(*colors)
			yield
		ensure
			set_color(0)
		end
	end
end


class Confgit
	include WithColor

	def initialize(path = '~/.etc/confgit')
		@base_path = File.expand_path(path)
		@repos_path = File.join(@base_path, 'repos')

#		FileUtils.mkpath(@base_path)
		FileUtils.mkpath(@repos_path)

		@config = read_config(File.join(@base_path, 'confgit.conf'))
		@repo_path = File.expand_path(@config['repo'], @repos_path)

		@dir_stack = []
	end

	# 設定の初期値
	def default_config
		{'repo' => `hostname`.chop}
	end

	# 設定の読込み
	def read_config(file)
		if File.exist?(file)
			config = JSON.parse(File.read(file))
		else
			config = default_config
			File.write(file, JSON.pretty_generate(config)+"\n")
		end

		return config
	end

	def method_missing(name, *args, &block)
		if name.to_s =~ /^confgit_(.+)$/
			command = $1.gsub(/_/, '-')
			git(command, *args)

#			abort "#{CMD} '#{$'}' is not a git command. See '#{CMD} --help'.\n"
		else
			super
		end
	end

	def action(command, *args)
		command = command.gsub(/-/, '_')
		send "confgit_#{command}", *args
	end

	# カレントディレクトリをプッシュする
	def pushdir(subdir = '.')
		@dir_stack.push(Dir.pwd)
		Dir.chdir(File.expand_path(subdir, @repo_path))
	end

	# カレントディレクトリをポップする
	def popdir()
		Dir.chdir(@dir_stack.pop) if 0 < @dir_stack.length
	end

	# git を呼出す
	def git(*args)
		pushdir()

		begin
			system('git', *args);
		rescue => e
			print e, "\n"
		ensure
			popdir()
		end
	end

	# ファイルのコピー（属性は維持する）
	def filecopy(from, to)
		begin
			to_dir = File.dirname(to)
			FileUtils.mkpath(to_dir)
	
			if File.exist?(to) && ! File.writable_real?(to)
				# 書込みできない場合は削除を試みる
				File.unlink(to)
			end
	
			FileUtils.copy(from, to)
			stat = File.stat(from)
			File.utime(stat.atime, stat.mtime, to)
			File.chmod(stat.mode, to)

			return true
		rescue => e
			print e, "\n"
		end
	end

	# ディレクトリ内のファイルを繰返す
	def dir_each(path = '.')
		pushdir(path)

		begin
			Dir.foreach('.') { |file|
				next if /^(\.git|\.$|\.\.$)/ =~ file
	
				yield(file)
	
				if File.directory?(file)
					Dir.glob("#{file}/**/*", File::FNM_DOTMATCH) { |file|
						if /(^|\/)(\.git|\.|\.\.)$/ !~ file
							yield(file)
						end
					}
				end
			}
		ensure
			popdir()
		end
	end

	# git に管理されているファイルを繰返す
	def git_each(path = '.')
		pushdir(path)

		begin
			open("| git ls-files") {|f|
				while line = f.gets
					file = line.chomp
					next if /^\.git/ =~ file
					next if File.directory?(file)

					yield(file)
				end
			}
		ensure
			popdir()
		end
	end

	# パスを展開する
	def expand_path(path, dir = nil)
		File.expand_path(path, dir).gsub(%r|^/private/|, '/')
	end

	# オプションを取出す
	def getopts(args)
		options = []
		args.each { |opt|
			break unless /^-/ =~ opt
			options << args.shift
		}

		options
	end

	# ファイルの更新チェック
	def modfile?(from, to)
		! File.exist?(to) || File.stat(from).mtime > File.stat(to).mtime
	end

	# コマンド

	# リポジトリの初期化
	def confgit_init
		FileUtils.mkpath(@repo_path)
		git('init')
	end

	# ファイルを管理対象に追加
	def confgit_add(*files)
		confgit_init unless File.exist?(@repo_path)

		files.each { |path|
			path = expand_path(path)

			if File.directory?(path)
				dir_each(path) { |file|
					next if File.directory?(file)
	
					from = File.join(path, file)
					to = File.join(@repo_path, from)
	
					if filecopy(from, to)
						git('add', to)
					end
				}
			else
				from = path
				to = File.join(@repo_path, from)

				if filecopy(from, to)
					git('add', to)
				end
			end
		}
	end

	# ファイルを管理対象から削除
	def confgit_rm(*args)
		return unless File.exist?(@repo_path)

		options = getopts(args)

		files = args.collect { |from|
			File.join(@repo_path, expand_path(from))
		}

		git('rm', *options, *files)
	end

	# バックアップする
	def confgit_backup(*args)
		force = false

		begin
			opts = OptionParser.new
			opts.on('-f')		{ force = true }
			opts.order!(args)
		rescue
		end

		git_each { |file|
			next if File.directory?(file)

			from = File.join('/', file)
			to = File.join(@repo_path, file)

			unless File.exist?(from)
				with_color(:fg_red) { print "[?] #{file}\n" }
				next
			end

			if force || modfile?(from, to)
				with_color(:fg_blue) { print "--> #{file}\n" }
				filecopy(from, to)
			end
		}

		git('status')
	end

	# リストアする
	def confgit_restore(*args)
		force = false

		begin
			opts = OptionParser.new
			opts.on('-f')		{ force = true }
			opts.order!(args)
		rescue
		end

		git_each { |file|
			next if File.directory?(file)

			from = File.join(@repo_path, file)
			to = File.join('/', file)

			unless File.exist?(from)
				with_color(:fg_red) { print "[?] #{file}\n" }
				next
			end

			if force || modfile?(from, to)
				with_color(:fg_blue) { print "<-- #{file}\n" }
#				filecopy(from, to)
			end
		}
	end

	# 一覧表示する
	def confgit_list(*args)

		git_each { |file|
			next if File.directory?(file)

			from = File.join('/', file)
			to = File.join(@repo_path, file)

			if File.exist?(from)
				stat = File.stat(from)
				user = Etc.getpwuid(stat.uid).name
				group = Etc.getgrgid(stat.gid).name
			else
				user = '-'
				group = '-'
			end

			print "#{user}\t#{group}\t#{from}\n"
		}
	end

	# tree表示する
	def confgit_tree(*args)
		pushdir()

		begin
			system('tree', *args)
		rescue => e
			print e, "\n"
		ensure
			popdir()
		end
	end

	# カレントディレクトリを変更
	def confgit_pwd(subdir = '.')
		print File.expand_path(subdir, @repo_path), "\n"
	end

end


if __FILE__ == $0
	CMD = File.basename $0

	# 使い方
	def usage
		abort "Usage: #{CMD} [--help] <command> [<args>]\n"
	end

	# コマンド引数の解析
	config = {}

	begin
		opts = OptionParser.new
		opts.on('--help')			{ usage }
		opts.order!(ARGV)
	rescue
		usage
	end

	command = ARGV.shift
	usage unless command

	confgit = Confgit.new
	confgit.action(command, *ARGV)
end
