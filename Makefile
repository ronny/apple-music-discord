default:
	zig build

Music.h:
	# Both sdef and sdp require Xcode (CommandLineTools only won't work)
	sdef /System/Applications/Music.app | sdp -fh --basename Music
