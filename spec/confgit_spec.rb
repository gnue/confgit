# -*- encoding: utf-8 -*-

require File.expand_path('../spec_helper', __FILE__)
require 'confgit'


describe Confgit do
	class String
		# １行目のインデントだけ全体のインデントを削除する
		def cut_indent(prefix = '')
			prefix = Regexp.escape(prefix)

			if self =~ /^(\s+#{prefix})/
				indent = Regexp.escape($1)
				self.gsub(/^#{indent}/,'')
			else
				self
			end
		end

		# カラーのエスケープコードを正規表現用にエスケープする
		def regex_escape_color
			gsub(/\e\[([0-9])*m/) { |m| Regexp.escape(m) }
		end
	end

	# 引数の最後が Hash ならオプションとして取出す
	def arg_last_options(args)
		if args.last && args.last.kind_of?(Hash)
			args.pop
		else
			{}
		end
	end

	# Confgit.run を呼出す
	def confgit(*argv)
		begin
			options = {:interactive => false}
			options.merge!(arg_last_options(argv))

			Confgit.run(argv, options)
		rescue SystemExit => err
			@abort = err.inspect
		end
	end

	# カレントディレクトリとルートを変更する
	def chroot(*args)
		options = arg_last_options(args)

		root = options[:root]
		root ||= ENV['HOME']

		Dir.chdir(root) { |path|
			confgit 'root', path

			args.each { |file|
				dir = File.dirname(file)
				FileUtils.mkpath(dir) unless dir == '.'

				open(file, 'w') { |f|
					f.puts options[:data] if options[:data]
				}
			}

			yield(path, *args)
		}
	end

	# ファイルの変更を行うために現在の内容を記録する
	def modfile(*args)
		options = arg_last_options(args)

		prevs = args.collect { |item|  open(item).read }
		yield(*prevs)

		prevs
	end

	# 行をソートする
	def sort_lines(text)
		text.split("\n").sort.join("\n")
	end

	before do
		require 'tmpdir'

		@hostname = `hostname`.chop
		@home = ENV['HOME']
		ENV['HOME'] = @tmpdir = Dir.mktmpdir
	end

	describe "repo" do
		it "repo" do
			proc { confgit 'repo' }.must_output "* #{@hostname}\n"
		end

		it "repo REPO" do
			name = '_foo_'

			out, err, status = capture_io {
				confgit 'repo', name
				confgit 'repo'
			}

			data = <<-EOD.cut_indent
				* #{name}
				  #{@hostname}
			EOD

			sort_lines(out).must_equal sort_lines(data)
		end

		it "repo -d REPO (not current)" do
			name1 = '_foo_'
			name2 = '_bar_'

			out, err, status = capture_io {
				confgit 'repo', name1
				confgit 'repo', name2
				confgit 'repo', '-d', name1
				confgit 'repo'
			}

			data = <<-EOD.cut_indent
				* #{name2}
				  #{@hostname}
			EOD

			sort_lines(out).must_equal sort_lines(data)
		end

		it "repo -d REPO (current)" do
			name = '_foo_'

			out, err, status = capture_io {
				confgit 'repo', name
				confgit 'repo', '-d', name
				@abort == "'#{name}' is current repository!\n"
				confgit 'repo'
			}

			data = <<-EOD.cut_indent
				* #{name}
				  #{@hostname}
			EOD

			sort_lines(out).must_equal sort_lines(data)
		end

		it "repo -D REPO" do
			name = '_foo_'
			proc {
				confgit 'repo', name
				confgit 'repo', '-D', name
				confgit 'repo'
			}.must_output "* #{@hostname}\n"
		end
	end

	describe "root" do
		it "root" do
			proc { confgit 'root' }.must_output "/\n"
		end

		it "root PATH" do
			path = ENV['HOME']

			confgit 'root', path
			proc { confgit 'root' }.must_output "#{path}\n"
		end

		it "root -d" do
			path = ENV['HOME']

			confgit 'root', path
			confgit 'root', '-d'
			proc { confgit 'root' }.must_output "/\n"
		end
	end

	describe "add" do
		it "add FILE" do
			chroot('README') { |root, file|
				confgit 'add', file
				proc { confgit 'status' }.must_output <<-EOD.cut_indent
					# On branch master
					#
					# Initial commit
					#
					# Changes to be committed:
					#   (use "git rm --cached <file>..." to unstage)
					#
					#	new file:   #{file}
					#
				EOD
			}
		end

		it "add DIR" do
			dir = 'misc'

			chroot(File.join(dir, 'README')) { |root, file|
				confgit 'add', dir
				proc { confgit 'status' }.must_output <<-EOD.cut_indent
					# On branch master
					#
					# Initial commit
					#
					# Changes to be committed:
					#   (use "git rm --cached <file>..." to unstage)
					#
					#	new file:   #{file}
					#
				EOD
			}
		end

		it "add SYMLINK" do
			dir = 'misc'
			dummy = 'misc_symlink'

			chroot(File.join(dir, 'README')) { |root, file|
				File.symlink(dir, dummy)
				confgit 'add', dummy
				proc { confgit 'status' }.must_output <<-EOD.cut_indent
					# On branch master
					#
					# Initial commit
					#
					# Changes to be committed:
					#   (use "git rm --cached <file>..." to unstage)
					#
					#	new file:   #{dummy}
					#
				EOD
			}
		end
	end

	describe "rm" do
		it "rm FILE" do
			chroot('README') { |root, file|
				confgit 'add', file

				capture_io { confgit 'commit', '-m', "add #{file}" }
				proc { confgit 'rm', file }.must_output "rm '#{file}'\n"
				proc { confgit 'status' }.must_output <<-EOD.cut_indent
					# On branch master
					# Changes to be committed:
					#   (use "git reset HEAD <file>..." to unstage)
					#
					#	deleted:    #{file}
					#
				EOD
			}
		end

		it "rm -f FILE" do
			chroot('README') { |root, file|
				confgit 'add', file

				proc { confgit 'rm', '-f', file }.must_output "rm '#{file}'\n"
				proc { confgit 'status' }.must_output <<-EOD.cut_indent
					# On branch master
					#
					# Initial commit
					#
					nothing to commit (create/copy files and use "git add" to track)
				EOD
			}
		end

		it "rm -r DIR" do
			dir = 'misc'

			chroot(File.join(dir, 'README')) { |root, file|
				confgit 'add', dir

				capture_io { confgit 'commit', '-m', "add #{dir}" }
				proc { confgit 'rm', '-r', dir }.must_output "rm '#{file}'\n"
				proc { confgit 'status' }.must_output <<-EOD.cut_indent
					# On branch master
					# Changes to be committed:
					#   (use "git reset HEAD <file>..." to unstage)
					#
					#	deleted:    #{file}
					#
				EOD
			}
		end

		it "rm -rf DIR" do
			dir = 'misc'

			chroot(File.join(dir, 'README')) { |root, file|
				confgit 'add', dir

				proc { confgit 'rm', '-rf', dir }.must_output "rm '#{file}'\n"
				proc { confgit 'status' }.must_output <<-EOD.cut_indent
					# On branch master
					#
					# Initial commit
					#
					nothing to commit (create/copy files and use "git add" to track)
				EOD
			}
		end

		it "rm -f SYMLINK" do
			dir = 'misc'
			dummy = 'misc_symlink'

			chroot(File.join(dir, 'README')) { |root, file|
				File.symlink(dir, dummy)
				confgit 'add', dummy

				proc { confgit 'rm', '-f', dummy }.must_output "rm '#{dummy}'\n"
				proc { confgit 'status' }.must_output <<-EOD.cut_indent
					# On branch master
					#
					# Initial commit
					#
					nothing to commit (create/copy files and use "git add" to track)
				EOD
			}
		end
	end

	describe "backup" do
		before do
			dir = 'misc'
			@mod_file = 'VERSION'
			@data = '0.0.1'
			@symlinks = {'dir_link' => dir, 'file_link' => 'VERSION', 'mod_link' => ['README', 'LICENSE.txt']}

			chroot(@mod_file, 'README', 'LICENSE.txt', File.join(dir, 'README')) { |root, *files|
				@symlinks.each { |key, value|
					file, = value
					File.symlink(file, key)
				}

				confgit 'add', *(files + @symlinks.keys)
				capture_io { confgit 'commit', '-m', "add #{files}" }
				open(@mod_file, 'w') { |f| f.puts @data }

				@symlinks.each { |key, value|
					old, file = value
					next unless file

					File.delete(key)
					File.symlink(file, key)
				}
			}
		end

		it "backup -n" do
			chroot { |root, *files|
				out, err, status = capture_io { confgit 'backup', '-n' }
				out.must_match <<-EOD.cut_indent
					\e[34m--> #{@mod_file}\e[m
					\e[34m--> mod_link\e[m
					# On branch master
				EOD
			}
		end

		it "backup -y" do
			chroot { |root, *files|
				out, err, status = capture_io { confgit 'backup', '-y' }
				out.must_match <<-EOD.cut_indent
					\e[34m--> VERSION\e[m
					\e[34m--> mod_link\e[m
					# On branch master
					# Changes not staged for commit:
					#   (use "git add <file>..." to update what will be committed)
					#   (use "git checkout -- <file>..." to discard changes in working directory)
					#
					#	modified:   #{@mod_file}
					#	modified:   mod_link
					#
					no changes added to commit (use "git add" and/or "git commit -a")
				EOD
			}
		end

		it "backup -fn" do
			chroot { |root, *files|
				File.delete @mod_file

				out, err, status = capture_io { confgit 'backup', '-fn' }
				out.must_match <<-EOD.cut_indent
					\e[34m--> LICENSE.txt\e[m
					\e[34m--> README\e[m
					\e[31m[?] #{@mod_file}\e[m
					\e[34m--> dir_link\e[m
					\e[34m--> file_link\e[m
					\e[34m--> misc/README\e[m
					\e[34m--> mod_link\e[m
					# On branch master
				EOD
			}
		end
	end

	describe "restore" do
		def udpate_data
			open(@mod_file, 'w') { |f| f.puts @data }
			File.delete @del_file
			FileUtils.remove_entry_secure(@deep_file.split('/').first)

			@symlinks.each { |key, value|
				old, file = value
				next unless file

				File.delete(key)
				File.symlink(file, key)
			}
		end

		before do
			dir = 'misc'
			@mod_file = 'VERSION'
			@del_file = 'LICENSE.txt'
			@deep_file = 'a/b/c.txt'
			@data = '0.0.1'
			@symlinks = {'dir_link' => dir, 'file_link' => 'VERSION', 'mod_link' => ['README', 'LICENSE.txt']}

			chroot(@mod_file, @del_file, @deep_file, 'README', File.join(dir, 'README')) { |root, *files|
				@symlinks.each { |key, value|
					file, = value
					File.symlink(file, key)
				}

				confgit 'add', *(files + @symlinks.keys)
				capture_io { confgit 'commit', '-m', "add #{files}" }
			}
		end

		it "restore -n" do
			chroot { |root, *files|
				udpate_data

				modfile(@mod_file) { |prev|
					proc { confgit 'restore', '-n' }.must_output <<-EOD.cut_indent
						\e[34m<-- #{@del_file}\e[m
						\e[34m<-- #{@mod_file}\e[m
						\e[34m<-- #{@deep_file}\e[m
						\e[34m<-- mod_link\e[m
					EOD
					open(@mod_file).read.must_equal prev
				}
			}
		end

		it "restore -y" do
			chroot { |root, *files|
				modfile(@mod_file) { |prev|
					udpate_data

					proc { confgit 'restore', '-y' }.must_output <<-EOD.cut_indent
						\e[34m<-- #{@del_file}\e[m
						\e[34m<-- #{@mod_file}\e[m
						\e[34m<-- #{@deep_file}\e[m
						\e[34m<-- mod_link\e[m
					EOD
					open(@mod_file).read.must_equal prev
				}
			}
		end

		it "restore -fn" do
			chroot { |root, *files|
				udpate_data

				proc { confgit 'restore', '-fn' }.must_output <<-EOD.cut_indent
					\e[34m<-- #{@del_file}\e[m
					\e[34m<-- README\e[m
					\e[34m<-- #{@mod_file}\e[m
					\e[34m<-- #{@deep_file}\e[m
					\e[34m<-- dir_link\e[m
					\e[34m<-- file_link\e[m
					\e[34m<-- misc/README\e[m
					\e[34m<-- mod_link\e[m
				EOD
			}
		end
	end

	describe "git" do
		it "commit" do
			chroot('README') { |root, file|
				confgit 'add', file
				out, err, status = capture_io { confgit 'commit', '-m', "add #{file}" }
				#err.must_be_empty
				status.must_be_nil
				out.must_match <<-EOD.cut_indent('|')
					| create mode 100644 #{file}
				EOD
			}
		end
	end

	describe "list" do
		before do
			dir = 'misc'
			symlinks = {'dir_link' => dir, 'file_link' => 'VERSION', 'mod_link' => ['README', 'LICENSE.txt']}

			chroot('VERSION', 'README', 'LICENSE.txt', File.join(dir, 'README')) { |root, *files|
				symlinks.each { |key, value|
					file, = value
					File.symlink(file, key)
				}

				confgit 'add', *(files + symlinks.keys)
				capture_io { confgit 'commit', '-m', "add #{files}" }
			}
		end

		it "list" do
			chroot { |root, *files|
				out, err, status = capture_io { confgit 'list' }
				out.must_match Regexp.new <<-EOD.cut_indent
					-rw-r.-r--	.+	.+	#{root}/LICENSE\.txt
					-rw-r.-r--	.+	.+	#{root}/README
					-rw-r.-r--	.+	.+	#{root}/VERSION
					l---------	.+	.+	#{root}/dir_link
					l---------	.+	.+	#{root}/file_link
					-rw-r.-r--	.+	.+	#{root}/misc/README
					l---------	.+	.+	#{root}/mod_link
				EOD
			}
		end

		it "list -8" do
			chroot { |root, *files|
				out, err, status = capture_io { confgit 'list', '-8' }
				out.must_match Regexp.new <<-EOD.cut_indent
					1006.4	.+	.+	#{root}/LICENSE\.txt
					1006.4	.+	.+	#{root}/README
					1006.4	.+	.+	#{root}/VERSION
					120000	.+	.+	#{root}/dir_link
					120000	.+	.+	#{root}/file_link
					1006.4	.+	.+	#{root}/misc/README
					120000	.+	.+	#{root}/mod_link
				EOD
			}
		end
	end

	describe "tree" do
		before do
			@dir = 'misc'
			chroot('.version', 'VERSION', 'README', File.join(@dir, 'LICENSE.txt')) { |root, *files|
				confgit 'add', *files
			}
		end

		it "tree" do
			chroot { |root, *files|
				proc { confgit 'tree' }.must_output <<-EOD.cut_indent
					.
					├── README
					├── VERSION
					└── #{@dir}
					    └── LICENSE.txt

					1 directory, 3 files
				EOD
			}
		end

		it "tree -a" do
			chroot { |root, *files|
				proc { confgit 'tree', '-a' }.must_output <<-EOD.cut_indent
					.
					├── .version
					├── README
					├── VERSION
					└── #{@dir}
					    └── LICENSE.txt

					1 directory, 4 files
				EOD
			}
		end

		it "tree DIR" do
			chroot { |root, *files|
				proc { confgit 'tree', @dir }.must_output <<-EOD.cut_indent
					#{@dir}
					└── LICENSE.txt

					0 directories, 1 file
				EOD
			}
		end
	end

	describe "utilities" do
		it "tig"

		it "path" do
			home = File.realpath(ENV['HOME'])
			path = File.join(home, '.etc/confgit/repos', `hostname`.chomp)

			proc { confgit 'path' }.must_output "#{path}\n"
		end
	end

	after do
		FileUtils.remove_entry_secure @tmpdir
		ENV['HOME'] = @home
	end
end
