.PHONY: build diag tsan release docker-amd64 docker-arm64 clean

DOCKER_IMAGE ?= illusionna/localtransfer
DOCKER_TAG ?= latest

CACHE_LOCAL := ./.zig-cache/local
CACHE_GLOBAL := ./.zig-cache/global
ZIG_FLAGS := --cache-dir $(CACHE_LOCAL) --global-cache-dir $(CACHE_GLOBAL) --prefix . --prefix-exe-dir .

build:
	zig build $(ZIG_FLAGS)

diag:
	zig build $(ZIG_FLAGS) -Ddiagnostic=true

tsan:
	zig build $(ZIG_FLAGS) -Dsanitize-thread=true

release:
	zig build $(ZIG_FLAGS) -Dcpu=baseline -Dtarget=x86_64-linux-musl -Dname=ziger-linux-x86_64
	zig build $(ZIG_FLAGS) -Dcpu=baseline -Dtarget=aarch64-linux-musl -Dname=ziger-linux-aarch64
	zig build $(ZIG_FLAGS) -Dcpu=baseline -Dtarget=x86_64-macos -Dname=ziger-macos-x86_64
	zig build $(ZIG_FLAGS) -Dcpu=baseline -Dtarget=aarch64-macos -Dname=ziger-macos-aarch64
	zig build $(ZIG_FLAGS) -Dcpu=baseline -Dtarget=x86_64-windows-gnu -Dname=ziger-windows-x86_64
	zig build $(ZIG_FLAGS) -Dcpu=baseline -Dtarget=aarch64-windows-gnu -Dname=ziger-windows-aarch64

docker-amd64:
	zig build $(ZIG_FLAGS) -Dcpu=baseline -Dtarget=x86_64-linux-musl -Dname=ziger-linux-x86_64
	docker buildx build --platform linux/amd64 --build-arg ZIGER_BINARY=ziger-linux-x86_64 --tag "$(DOCKER_IMAGE)-amd64:$(DOCKER_TAG)" --load .

docker-arm64:
	zig build $(ZIG_FLAGS) -Dcpu=baseline -Dtarget=aarch64-linux-musl -Dname=ziger-linux-aarch64
	docker buildx build --platform linux/arm64 --build-arg ZIGER_BINARY=ziger-linux-aarch64 --tag "$(DOCKER_IMAGE)-arm64:$(DOCKER_TAG)" --load .

clean:
	find . -type d -name 'zig-cache' -prune -exec rm -rf -- {} +
	find . -type d -name '.zig-cache' -prune -exec rm -rf -- {} +
	find . -type d -name '.DS_Store' -prune -exec rm -rf -- {} +
	rm -rf ziger*
