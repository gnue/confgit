#!/usr/bin/env ruby
# coding: UTF-8


require 'rubygems'
require 'optparse'
require 'fileutils'
require 'json'


class Confgit
	def initialize(path = '~/.etc/confgit')
		@base_path = File.expand_path(path)
		@repos_path = File.join(@base_path, 'repos')

#		FileUtils.mkpath(@base_path)
		FileUtils.mkpath(@repos_path)

		@config = read_config(File.join(@base_path, 'confgit.conf'))
		@repo_path = File.expand_path(@config['repo'], @repos_path)
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

	def chdir(subdir = '.')
		Dir.chdir(File.expand_path(subdir, @repo_path))
	end

	def git(*args)
		begin
			chdir()
			system('git', *args);
		rescue => e
			print e, "\n"
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

	def each(subdir = '.')
		chdir(subdir)
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
	end

	# パスを展開する
	def expand_path(path, dir = nil)
		File.expand_path(path, dir).gsub(%r|^/private/|, '/')
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

		files.each { |from|
			from = expand_path(from)
			to = File.join(@repo_path, from)

			if filecopy(from, to)
				git('add', to)
			end
		}
	end

	# ファイルを管理対象から削除
	def confgit_rm(*files)
		return unless File.exist?(@repo_path)

		files.each { |from|
			from = expand_path(from)

			to = File.join(@repo_path, from)
			git('rm', '-f', to)
		}
	end

	# バックアップする
	def confgit_backup(*args)
		each { |file|
			next if File.directory?(file)

			from = File.join('/', file)
			to = File.join(@repo_path, file)

			next unless File.exist?(from)

			if ! File.exist?(to) && File.stat(from).mtime > File.stat(to).mtime
				print file, "\n"
				filecopy(from, to)
			end
		}

		git('status')
	end

	# リストアする
	def confgit_restore(*args)
		each { |file|
			next if File.directory?(file)

			from = File.join(@repo_path, file)
			to = File.join('/', file)

			next unless File.exist?(from)

			if File.exist?(to)
				if File.stat(from).mtime > File.stat(to).mtime
					print file, "\n"
#					filecopy(from, to)
				end
			else
			end
		}
	end

	# ログする
	def confgit_lg(*args)
		git('log', '--graph', '--all', '--color', '--pretty="%x09%h %cn%x09%s %Cred%d"')
	end

	# tree表示する
	def confgit_tree(*args)
		begin
			chdir()
			system('tree', *args)
		rescue => e
			print e, "\n"
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
		abort "Usage: #{CMD} <command> [<args>]\n" +
			  "  --help\n"
	end

	# コマンド引数の解析
	begin
		config = {}

		opts = OptionParser.new
		opts.on('--help')			{ usage }
		opts.parse!(ARGV)
	rescue => e
	end

	command = ARGV.shift
	usage unless command

	confgit = Confgit.new
	confgit.action(command, *ARGV)
end
