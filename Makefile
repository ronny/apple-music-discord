app:
ifdef DISCORD_SOCIAL_SDK_PATH
	zig build -Ddiscord-social-sdk=$(DISCORD_SOCIAL_SDK_PATH)
else
	zig build
endif

Music.h:
	# Both sdef and sdp require Xcode (CommandLineTools only won't work)
	sdef /System/Applications/Music.app | sdp -fh --basename Music

.PHONY: test
test:
	zig build test-all
