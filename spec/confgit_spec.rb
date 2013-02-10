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
			options = arg_last_options(argv)
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

	before do
		require 'tmpdir'

		@hostname = `hostname`.chop
		@home = ENV['HOME']
		ENV['HOME'] = @tmpdir = Dir.mktmpdir
	end

	describe "repo" do
		it "repo" do
			out, err = capture_io { confgit 'repo' }
			out.must_equal "* #{@hostname}\n"
		end

		it "repo REPO" do
			name = '_foo_'
			out, err = capture_io {
				confgit 'repo', name
				confgit 'repo'
			}

			out.must_equal <<-EOD.gsub(/^\t+/,'')
				* #{name}
				  #{@hostname}
			EOD
		end

		it "repo -d REPO (not current)" do
			name1 = '_foo_'
			name2 = '_bar_'
			out, err = capture_io {
				confgit 'repo', name1
				confgit 'repo', name2
				confgit 'repo', '-d', name1
				confgit 'repo'
			}

			out.must_equal <<-EOD.gsub(/^\t+/,'')
				* #{name2}
				  #{@hostname}
			EOD
		end

		it "repo -d REPO (current)" do
			name = '_foo_'
			out, err = capture_io {
				confgit 'repo', name
				confgit 'repo', '-d', name
				@abort == "'#{name}' is current repository!\n"
				confgit 'repo'
			}

			out.must_equal <<-EOD.gsub(/^\t+/,'')
				* #{name}
				  #{@hostname}
			EOD
		end

		it "repo -D REPO" do
			name = '_foo_'
			out, err = capture_io {
				confgit 'repo', name
				confgit 'repo', '-D', name
				confgit 'repo'
			}

			out.must_equal "* #{@hostname}\n"
		end
	end

	describe "root" do
		it "root" do
			out, err = capture_io { confgit 'root' }
			out.must_equal "/\n"
		end

		it "root PATH" do
			path = ENV['HOME']

			confgit 'root', path
			out, err = capture_io { confgit 'root' }
			out.must_equal "#{path}\n"
		end

		it "root -d" do
			path = ENV['HOME']

			confgit 'root', path
			confgit 'root', '-d'
			out, err = capture_io { confgit 'root' }
			out.must_equal "/\n"
		end
	end

	describe "add" do
		it "add FILE" do
			chroot('README') { |root, file|
				confgit 'add', file
				out, err = capture_io { confgit 'status', :interactive => false }

				out.must_equal <<-EOD.gsub(/^\t+/,'')
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
				out, err = capture_io { confgit 'status', :interactive => false }

				out.must_equal <<-EOD.gsub(/^\t+/,'')
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
				capture_io { confgit 'commit', '-m', "add #{file}", :interactive => false }

				out, err = capture_io { confgit 'rm', file }
				out.must_equal "rm '#{file}'\n"

				out, err = capture_io { confgit 'status', :interactive => false }
				out.must_equal <<-EOD.gsub(/^\t+/,'')
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

				out, err = capture_io { confgit 'rm', '-f', file }
				out.must_equal "rm '#{file}'\n"

				out, err = capture_io { confgit 'status', :interactive => false }
				out.must_equal <<-EOD.gsub(/^\t+/,'')
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
				capture_io { confgit 'commit', '-m', "add #{dir}", :interactive => false }

				out, err = capture_io { confgit 'rm', '-r', dir }
				out.must_equal "rm '#{file}'\n"

				out, err = capture_io { confgit 'status', :interactive => false }
				out.must_equal <<-EOD.gsub(/^\t+/,'')
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

				out, err = capture_io { confgit 'rm', '-rf', dir }
				out.must_equal "rm '#{file}'\n"

				out, err = capture_io { confgit 'status', :interactive => false }
				out.must_equal <<-EOD.gsub(/^\t+/,'')
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
		it "backup"
	end

	describe "restore" do
		it "restore"
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
