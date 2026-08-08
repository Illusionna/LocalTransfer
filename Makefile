.PHONY: build clean

CACHE_LOCAL := ./.zig-cache/local
CACHE_GLOBAL := ./.zig-cache/global

ZIG_FLAGS := --cache-dir $(CACHE_LOCAL) --global-cache-dir $(CACHE_GLOBAL) --prefix . --prefix-exe-dir .

build:
	zig build $(ZIG_FLAGS)

clean:
	find . -type d -name 'zig-cache' -prune -exec rm -rf -- {} +
	find . -type d -name '.zig-cache' -prune -exec rm -rf -- {} +
	find . -type d -name 'zig-out' -prune -exec rm -rf -- {} +
	find . -type d -name '.DS_Store' -prune -exec rm -rf -- {} +
	rm -rf ziger