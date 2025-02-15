.PHONY: build run

build:
	@go clean -cache
	go mod init Ollava-Browser-App
	go mod tidy
	go build -ldflags="-w -s" -o webserver.exe main.go types.go utils.go handler.go