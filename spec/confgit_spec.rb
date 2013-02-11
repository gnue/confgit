require File.expand_path('../spec_helper', __FILE__)
require 'confgit'


describe Confgit do
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
			proc {
				confgit 'repo', name
				confgit 'repo'
			}.must_output <<-EOD.gsub(/^\t+/,'')
				* #{name}
				  #{@hostname}
			EOD
		end

		it "repo -d REPO (not current)" do
			name1 = '_foo_'
			name2 = '_bar_'
			proc {
				confgit 'repo', name1
				confgit 'repo', name2
				confgit 'repo', '-d', name1
				confgit 'repo'
			}.must_output <<-EOD.gsub(/^\t+/,'')
				* #{name2}
				  #{@hostname}
			EOD
		end

		it "repo -d REPO (current)" do
			name = '_foo_'
			proc {
				confgit 'repo', name
				confgit 'repo', '-d', name
				@abort == "'#{name}' is current repository!\n"
				confgit 'repo'
			}.must_output <<-EOD.gsub(/^\t+/,'')
				* #{name}
				  #{@hostname}
			EOD
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
				proc { confgit 'status' }.must_output <<-EOD.gsub(/^\t+/,'')
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
				proc { confgit 'status' }.must_output <<-EOD.gsub(/^\t+/,'')
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
	end

	describe "rm" do
		it "rm FILE" do
			chroot('README') { |root, file|
				confgit 'add', file

				capture_io { confgit 'commit', '-m', "add #{file}" }
				proc { confgit 'rm', file }.must_output "rm '#{file}'\n"
				proc { confgit 'status' }.must_output <<-EOD.gsub(/^\t+/,'')
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
				proc { confgit 'status' }.must_output <<-EOD.gsub(/^\t+/,'')
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
				proc { confgit 'status' }.must_output <<-EOD.gsub(/^\t+/,'')
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
				proc { confgit 'status' }.must_output <<-EOD.gsub(/^\t+/,'')
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
		it "backup -n" do
			chroot('README', 'VERSION', 'LICENSE.txt') { |root, *files|
				confgit 'add', *files
				capture_io { confgit 'commit', '-m', "add #{files}" }
				open('VERSION', 'w') { |f| f.puts '0.0.1' }

				proc { confgit 'backup', '-n' }.must_output <<-EOD.gsub(/^\t+/,'')
					\e[34m--> VERSION\e[m
					# On branch master
					nothing to commit (working directory clean)
				EOD
			}
		end

		it "backup -y" do
			chroot('README', 'VERSION', 'LICENSE.txt') { |root, *files|
				confgit 'add', *files
				capture_io { confgit 'commit', '-m', "add #{files}" }
				open('VERSION', 'w') { |f| f.puts '0.0.1' }

				proc { confgit 'backup', '-y' }.must_output <<-EOD.gsub(/^\t+/,'')
					\e[34m--> VERSION\e[m
					# On branch master
					# Changes not staged for commit:
					#   (use "git add <file>..." to update what will be committed)
					#   (use "git checkout -- <file>..." to discard changes in working directory)
					#
					#	modified:   VERSION
					#
					no changes added to commit (use "git add" and/or "git commit -a")
				EOD
			}
		end

		it "backup -fn" do
			chroot('README', 'VERSION', 'LICENSE.txt') { |root, *files|
				confgit 'add', *files
				capture_io { confgit 'commit', '-m', "add #{files}" }
				File.delete 'VERSION'

				proc { confgit 'backup', '-fn' }.must_output <<-EOD.gsub(/^\t+/,'')
					\e[34m--> LICENSE.txt\e[m
					\e[34m--> README\e[m
					\e[31m[?] VERSION\e[m
					# On branch master
					nothing to commit (working directory clean)
				EOD
			}
		end
	end

	describe "restore" do
		it "restore -n" do
			file = 'VERSION'

			chroot(file, 'README', 'LICENSE.txt') { |root, *files|
				confgit 'add', *files
				capture_io { confgit 'commit', '-m', "add #{files}" }
				open(file, 'w') { |f| f.puts '0.0.1' }

				modfile(file) { |prev|
					proc { confgit 'restore', '-n' }.must_output <<-EOD.gsub(/^\t+/,'')
						\e[34m<-- #{file}\e[m
					EOD
					open(file).read.must_equal prev
				}
			}
		end

		it "restore -y" do
			file = 'VERSION'

			chroot(file, 'README', 'LICENSE.txt') { |root, *files|
				confgit 'add', *files
				capture_io { confgit 'commit', '-m', "add #{files}" }

				modfile(file) { |prev|
					open(file, 'w') { |f| f.puts '0.0.1' }

					proc { confgit 'restore', '-y' }.must_output <<-EOD.gsub(/^\t+/,'')
						\e[34m<-- #{file}\e[m
					EOD
					open(file).read.must_equal prev
				}
			}
		end

		it "restore -fn" do
			chroot('README', 'VERSION', 'LICENSE.txt') { |root, *files|
				confgit 'add', *files
				capture_io { confgit 'commit', '-m', "add #{files}" }
				File.delete 'VERSION'

				proc { confgit 'restore', '-fn' }.must_output <<-EOD.gsub(/^\t+/,'')
					\e[34m<-- LICENSE.txt\e[m
					\e[34m<-- README\e[m
					\e[35m<-- VERSION\e[m
				EOD
			}
		end
	end

	describe "git" do
		it "commit -a"
	end

	describe "utilities" do
		it "tree"
		it "tig"
		it "path"
		it "list"
	end

	after do
		FileUtils.remove_entry_secure @tmpdir
		ENV['HOME'] = @home
	end
end
