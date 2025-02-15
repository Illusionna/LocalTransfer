编译方式一：

```bash
make
```

编译方式二：

```
go clean -cache
go mod init Ollava-Browser-App
go mod tidy
go build -o webserver.exe main.go types.go utils.go handler.go
```

