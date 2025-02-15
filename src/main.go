package main

import (
	"os"
	"fmt"
	"flag"
	"sync"
	"embed"
	"net/http"
	"path/filepath"
	"github.com/wangshizebin/jiebago"
)


//go:embed UI/*
var ui embed.FS

var FROZEN_APP_PATH, _ = os.Executable()
var FROZEN_DIR string = filepath.Dir(FROZEN_APP_PATH)

var JIEBA_DICT *jiebago.JieBaGo
var JIEBA_DICT_LOAD_ONCE sync.Once

var HOST_IPv4 = flag.String("ip", "0.0.0.0", "")
var HOST_PORT = flag.String("port", "8888", "")
var SHARE_DIR = flag.String("share", ".", "")
var UPLOAD_DIR = flag.String("save", *SHARE_DIR, "")
var MAX_SIZE = flag.String("max", "1.2 GB", "")
var LOGIN_PASSWORD = flag.String("login", "", "")
var APP_VERSION = flag.Bool("version", false, "")


func main() {
	flag.Usage = func() {
		fmt.Printf("(e.g.) >>> ./%s -share \"C:\\Users\\Zolio Marling\\Desktop\" -max \"36 MB\" -port 443\n", filepath.Base(os.Args[0]))
		fmt.Printf("    -ip (string)\n\t服务器 IPv4 地址 (默认 \"%s\")\n", *HOST_IPv4)
		fmt.Printf("    -port (string)\n\t服务运行的端口号 (默认 \"%s\")\n", *HOST_PORT)
		fmt.Printf("    -share (string)\n\t共享文件夹的路径 (默认 \"%s\")\n", *SHARE_DIR)
		fmt.Printf("    -save (string)\n\t上传文件的保存路径 (默认 \"%s\")\n", *UPLOAD_DIR)
		fmt.Printf("    -max (string)\n\t限制上传文件的最大尺寸 (默认 \"%s\")\n", ConvertStorageUnit(ParseStorageUnit(*MAX_SIZE)))
		fmt.Printf("    -login (string)\n\t登录网页的密码 (默认 \"%s\")\n", *LOGIN_PASSWORD)
		fmt.Println("    -version\n\t查看软件版本信息")
	}
	flag.Parse()
	if *APP_VERSION {
        fmt.Println("Ollava Browser App v1 浏览器端工具")
		fmt.Println("协议：MIT License")
		fmt.Println("作者: @Illusionna")
		fmt.Println("隶属: Jarvis Engineering Tool")
		fmt.Println("主页: https://orzzz.net")
		fmt.Println("邮箱: www@orzzz.net")
        os.Exit(0)
    }
	ActivateRouters()
}



func ActivateRouters() {
	// fmt.Println(flag.Args())

	// --------------------------------------------------------------------------------
	// http.Handle("/", http.StripPrefix(
	// 	"/", http.FileServer(http.Dir(`A:\Illusionna\Desktop\ollava-browser\UI\`)),
	// ))
	// http.Handle("/UI/", http.StripPrefix(
	// 	"/UI/", http.FileServer(http.Dir(`A:\Illusionna\Desktop\ollava-browser\UI\`)),
	// ))
	// --------------------------------------------------------------------------------

	http.HandleFunc("/login/", LoginHandler)
	http.HandleFunc("/", IndexHandler)
	http.HandleFunc("/UI/", UIHandler)

	http.Handle("/UI/assets/fonts/", http.StripPrefix(
		"/UI/assets/fonts/", http.FileServer(http.Dir(filepath.Join(FROZEN_DIR, "./fonts"))),
	))

	http.HandleFunc("/HTTP404/", HTTP404Handler)
	http.HandleFunc("/HTTP500/", HTTP500Handler)

	http.HandleFunc("/api/file-list/", FileInfoHandler)
	http.HandleFunc("/api/edit-announcement/", EditAnnouncementBoardHandler)
	http.HandleFunc("/api/announcement-content/", PublishAnnouncementBoardHandler)
	http.HandleFunc("/api/file-property/", ViewFilePropertyHandler)
	http.HandleFunc("/api/delete-file/", DeleteFileHandler)
	http.HandleFunc("/api/batch-download/", BatchDownloadHandler)
	http.HandleFunc("/api/make-directory/", MakeDirectoryHandler)
	http.HandleFunc("/api/move-file/", MoveFileHandler)
	http.HandleFunc("/api/rename-file/", RenameFileHandler)
	http.HandleFunc("/api/copy-file/", CopyFileHandler)
	http.HandleFunc("/api/upload-file/", UploadFileHandler)
	http.HandleFunc("/api/search-file/", SearchFileHandler)

	http.Handle("/api/share/", AuthorizeShareFileMiddleware(
		http.StripPrefix(
			"/api/share/", http.FileServer(http.Dir(*SHARE_DIR)),
		),
	))

	http.HandleFunc("/docs/", APIDocsHandler)

	fmt.Print("\033[H\033[J")
	ipv4s, err := GetLocalIPv4Addresses()
	var ip string
	if err != nil {
		ip = "localhost"
	} else {
		ip = ipv4s[0]
	}

	fmt.Printf("共享文件夹目录位置：\"%s\"\n", *SHARE_DIR)
	fmt.Printf("保存上传文件的位置：\"%s\"\n", *UPLOAD_DIR)
	fmt.Printf("限制传输的最大大小：%s\n", ConvertStorageUnit(ParseStorageUnit(*MAX_SIZE)))
	fmt.Printf("前端登录密码：\"%s\"\n", *LOGIN_PASSWORD)
	fmt.Println("---------------------------------------")
	fmt.Printf("网络套接字：[%s:%s]\n", *HOST_IPv4, *HOST_PORT)
	fmt.Printf("本地回环地址 --> http://localhost:%s\n", *HOST_PORT)
	fmt.Printf("局域网链接 --> http://%s:%s\n", ip, *HOST_PORT)
	fmt.Println("---------------------------------------")
	fmt.Printf("帮助文档 >>> %s  --help\n", os.Args[0])
	fmt.Println("按住 ctrl + c 结束进程...\n")

    http.ListenAndServe(":" + *HOST_PORT, nil)
}