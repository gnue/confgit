# coding: UTF-8

=begin

= 設定ファイルを git で管理するためのツール


== 使い方

  $ confgit.rb repo						# リポジトリ一覧の表示
  $ confgit.rb repo	リポジトリ名			# カレントリポジトリの変更
  $ confgit.rb add ファイル名				# ファイルを追加
  $ confgit.rb rm ファイル名				# ファイルを削除
  $ confgit.rb rm -rf ディレクトリ名		# ディレクトリを削除
  $ confgit.rb backup					# バックアップ（更新されたもののみ）
  $ confgit.rb backup -f				# 強制バックアップ
  $ confgit.rb restore					# リストア（更新されたもののみ、まだ実際のファイルコピーは行えません）
  $ confgit.rb restore -f				# 強制リストア（まだ実際のファイルコピーは行えません）
  $ confgit.rb tree						# ツリー表示（要treeコマンド）
  $ confgit.rb tig						# tigで表示（要tigコマンド）
  $ confgit.rb path						# リポジトリのパスを表示
  $ confgit.rb list						# 一覧表示

== ディレクトリ構造

  ~/.etc/confgit
  ├── confgit.conf			-- 設定ファイル
  └── repos
      ├── current			-- カレントリポジトリへのシンボリックリンク
      └── `hostname`		-- リポジトリ（デフォルト）

== 設定ファイル

confgit.conf

  {
  }

== 動作環境

* 以下のライブラリが必要です（gem でインストールできます）
  * json

== TODO

* user/group の情報を保存
* user/group の情報を復元
* リストアで書込み権限がない場合は sudo でファイルコピーを行えるようにする

=end


require 'fileutils'
require 'pathname'
require 'etc'
require 'shellwords'

require 'rubygems'
require 'json'

require 'confgit/with_color'


module Confgit

class Repo
	include WithColor

	def initialize(path = '~/.etc/confgit')
		@base_path = File.expand_path(path)
		@repos_path = File.join(@base_path, 'repos')

		FileUtils.mkpath(@repos_path)

		@config = read_config(File.join(@base_path, 'confgit.conf'))
		@repo_path = File.expand_path('current', @repos_path)

		valid_repo unless File.symlink?(@repo_path)
	end

	# ホスト名
	def hostname
		`hostname`.chop
	end

	# カレントリポジトリがない場合の処理
	def valid_repo
		repo = nil

		repo_each { |file, is_current|
			repo = file
			break
		}

		chrepo(repo || hostname)
	end

	# リポジトリの変更
	def chrepo(repo)
		Dir.chdir(@repos_path) { |path|
			begin
				if File.symlink?('current')
					return if File.readlink('current') == repo
					File.unlink('current')
				end

				unless File.exist?(repo)
					FileUtils.mkpath(repo)

					Dir.chdir(repo) { |path|
						begin
							system('git', 'init');
						rescue => e
							FileUtils.rmtree(repo)
							abort e.to_s
						end
					}
				end

				File.symlink(repo, 'current') 
			rescue => e
				abort e.to_s
			end
		}
	end

	# リポジトリの削除
	def rmrepo(repo, force = false)
		Dir.chdir(@repos_path) { |path|
			begin
				if File.symlink?('current') && File.readlink('current') == repo
					abort "'#{repo}' is current repository!" unless force
					File.unlink('current')
				end

				FileUtils.rmtree(repo)

				valid_repo unless File.symlink?('current')
			rescue => e
				abort e.to_s
			end
		}
	end

	# 設定の初期値
	def default_config
		{}
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

	# 外部コマンドを定義する
	def self.define_command(command, *opts)
		define_method "confgit_#{command}" do |options, *args|
			args = getargs(args)

			Dir.chdir(@repo_path) { |path|
				begin
					system(command, *(opts + args))
				rescue => e
					abort e.to_s
				end
			}
		end
	end

	# メソッドがない場合
	def method_missing(name, *args, &block)
		if name.to_s =~ /^confgit_(.+)$/
			options = args.shift
			args = git_args(args)

			command = $1.gsub(/_/, '-')
			git(command, *args)

#			abort "#{CMD} '#{$'}' is not a git command. See '#{CMD} --help'.\n"
		else
			super
		end
	end

	# 引数を利用可能にする
	def getargs(args, force = false)
		args.collect { |x|
			run = false

			case x
			when /^-/
			when /\//
				run = true
			else
				run = force
			end

			if run
				repo = File.realpath(@repo_path)
				path = File.join(repo, x)
				x = Pathname(path).relative_path_from(Pathname(repo)).to_s
			end

			x
		}
	end

	# git を呼出す
	def git(*args)
		Dir.chdir(@repo_path) { |path|
			begin
				system('git', *args);
			rescue => e
				abort e.to_s
			end
		}
	end

	# git コマンドの引数を生成する
	def git_args(args)
		args.collect { |item|
			item = $' if %r|^/| =~ item
			item
		}
	end

	# ファイルの hash値を求める
	def hash_object(file)
		path = File.expand_path(file)
		open("| git hash-object \"#{path}\"") {|f|
			return f.gets.chomp
		}
	end

	# 確認プロンプトを表示する
	def yes?(prompt, y = true)
		yn = y ? 'Yn' : 'yN'
		print "#{prompt} [#{yn}]: "

		result = $stdin.gets.chomp

		return y if result.empty?

		if /^(y|yes)$/i =~ result
			y = true
		else
			y = false
		end

		y
	end

	# ファイルのコピー（属性は維持する）
	def filecopy(from, to, exiting = false)
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
			abort e.to_s if exiting
			$stderr.puts e.to_s
		end
	end

	# ディレクトリ内のファイルを繰返す
	def dir_each(subdir = '.')
		Dir.chdir(File.expand_path(subdir, @repo_path)) { |path|
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
		}
	end

	# git に管理されているファイルを繰返す
	def git_each(*args)
		args = getargs(args, true)
		files = args.collect { |f| f.shellescape }

		Dir.chdir(@repo_path) { |path|
			open("| git ls-files --stage --full-name " + files.join(' ')) {|f|
				while line = f.gets
					mode, hash, stage, file = line.split

#					file = line.chomp
					next if /^\.git/ =~ file
					next if File.directory?(file)

					yield(file, hash)
				end
			}
		}
	end

	# リポジトリを繰返す
	def repo_each
		Dir.chdir(@repos_path) { |path|
			begin
				current = File.expand_path(File.readlink('current'))
			rescue
			end

			Dir.glob('*') { |file|
				next if /^current$/ =~ file

				if current && File.realpath(file) == current
					is_current = true
					current = nil
				else
					is_current = false
				end

				yield(file, is_current)
			}

			yield(File.readlink('current'), true) if current
		}
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
		! File.exist?(to) || hash_object(from) != hash_object(to)
	end

	# ファイル属性を文字列にする
	def mode2str(bits)
		case bits & 0170000	# S_IFMT
		when 0010000	# S_IFIFO	パイプ
			mode = 'p'
		when 0020000	# S_IFCHR	キャラクタ・デバイス
			mode = 'c'
		when 0040000	# S_IFDIR	ディレクトリ
			mode = 'd'
		when 0060000	# S_IFBLK	ブロック・デバイス
			mode = 'b'
		when 0100000	# S_IFREG	通常ファイル
			mode = '-'
		when 0120000	# S_IFLNK	シンボリックリンク
			mode = 'l'
		when 0140000	# S_IFSOCK	ソケット
			mode = 's'
		when 0160000	# S_IFWHT	BSD空白ファイル
			mode = 'w'
		end

		mode += 'rwx'*3

		(0..8).each { |i| 
			mask = 1<<i
			mode[-(i+1)] = '-' if (bits & mask) == 0
		}

		if (bits & 0001000) != 0	# S_ISVTX	スティッキービット
			if mode[-1] == '-'
				mode[-1] = 'T'
			else
				mode[-1] = 't'
			end
		end

		mode
	end

	# コマンド

	# カレントリポジトリの表示・変更
	def confgit_repo(options, *args)
		if args.length == 0
			repo_each { |file, is_current|
				mark = is_current ? '*' : ' '
				print "#{mark} #{file}\n"
			}
		else
			repo = args.first

			if options[:remove]
				rmrepo(repo, options[:force])
			else
				chrepo(repo)
			end
		end
	end

	# リポジトリの初期化
	def confgit_init(options)
		FileUtils.mkpath(@repo_path)
		git('init')
	end

	# ファイルを管理対象に追加
	def confgit_add(options, *files)
		confgit_init unless File.exist?(@repo_path)
		repo = File.realpath(@repo_path)

		files.each { |path|
			path = expand_path(path)

			if File.directory?(path)
				dir_each(path) { |file|
					next if File.directory?(file)
	
					from = File.join(path, file)
					to = File.join(repo, from)
	
					if filecopy(from, to)
						git('add', to)
					end
				}
			else
				from = path
				to = File.join(repo, from)

				if filecopy(from, to)
					git('add', to)
				end
			end
		}
	end

	# ファイルを管理対象から削除
	def confgit_rm(options, *args)
		return unless File.exist?(@repo_path)

		options = getopts(args)
		repo = File.realpath(@repo_path)

		files = args.collect { |from|
			File.join(repo, expand_path(from))
		}

		git('rm', *(options + files))
	end

	# バックアップする
	def confgit_backup(options, *args)
		git_each(*args) { |file, hash|
			next if File.directory?(file)

			from = File.join('/', file)
			to = File.join(@repo_path, file)

			unless File.exist?(from)
				with_color(:fg_red) { print "[?] #{file}\n" }
				next
			end

			if options[:force] || modfile?(from, to)
				with_color(:fg_blue) { print "--> #{file}" }
				write = options[:yes]

				if write == nil
					# 書込みが決定していない場合
					write = yes?(nil, false)
				else
					puts
				end

				filecopy(from, to) if write
			end
		}

		git('status')
	end

	# リストアする
	def confgit_restore(options, *args)
		git_each(*args) { |file, hash|
			next if File.directory?(file)

			from = File.join(@repo_path, file)
			to = File.join('/', file)

			unless File.exist?(from)
				with_color(:fg_red) { print "[?] #{file}\n" }
				next
			end

			if options[:force] || modfile?(from, to)
				color = File.writable_real?(to) ? :fg_blue : :fg_magenta
				with_color(color) { print "<-- #{file}" }
				write = options[:yes]

				if write == nil
					# 書込みが決定していない場合
					write = yes?(nil, false)
				else
					puts
				end

				filecopy(from, to) if write
			end
		}
	end

	# 一覧表示する
	def confgit_list(options, *args)
		git_each(*args) { |file, hash|
			next if File.directory?(file)

			from = File.join('/', file)
			to = File.join(@repo_path, file)

			if File.exist?(from)
				stat = File.stat(from)
				mode = options[:octal] ? stat.mode.to_s(8) : mode2str(stat.mode)
				user = Etc.getpwuid(stat.uid).name
				group = Etc.getgrgid(stat.gid).name
			else
				mode = ' ' * (options[:octal] ? 6 : 10)
				user = '-'
				group = '-'
			end

			print "#{mode}\t#{user}\t#{group}\t#{from}\n"
		}
	end

	# リポジトリのパスを表示
	def confgit_path(options, subdir = '.')
		path = File.realpath(File.expand_path(subdir, @repo_path))
		print path, "\n"
	end

	# 外部コマンド
	define_command('tree', '-I', '.git')	# tree表示する
	define_command('tig')					# tigで表示する
end

end
