# -*- encoding: utf-8 -*-

module Confgit

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

end
