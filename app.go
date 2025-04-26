package main

import (
	"context"
	"net/http"
	"runtime"
	"os/exec"
)


type APP struct {
	ctx context.Context
}


func NewApp() *APP {
	return &APP{}
}


func (app *APP) startup(ctx context.Context) {
	app.ctx = ctx
}


func (app *APP) SynchronizeSettings(data map[string]interface{}) {
	HOST_IPv4 = data["ipAddress"].(string)
	HOST_PORT = data["port"].(string)
	SHARE_DIR = data["shareFolder"].(string)
	UPLOAD_DIR = data["savePath"].(string)
	MAX_SIZE = data["maxSize"].(string)
	LOGIN_PASSWORD = data["password"].(string)
	UPLOAD_STATUS = data["enableUpload"].(bool)
	DELETE_STATUS = data["enableDelete"].(bool)
	RENAME_STATUS = data["enableRename"].(bool)
	SEARCH_STATUS = data["enableSearch"].(bool)
	ANNOUNCEMENT_STATUS = data["enableBoard"].(bool)
	MKDIR_STATUS = data["enableMkdir"].(bool)
	COPY_STATUS = data["enableCopy"].(bool)
	MOVE_STATUS = data["enableMove"].(bool)

	USER_LOCK = map[string]bool{"localhost+curl": false, "127.0.0.1+curl": false}

	if IS_RUNNING {
		UpdateShareHandler()
		SERVER.Shutdown(context.TODO())
		SERVER = &http.Server{Addr: HOST_IPv4 + ":" + HOST_PORT}
		go func() { SERVER.ListenAndServe() }()
	} else {
		UpdateShareHandler()
	}
}


func (app *APP) SynchronizeServer(status bool) {
	if status {
		IS_RUNNING = true
		SERVER = &http.Server{Addr: HOST_IPv4 + ":" + HOST_PORT}
		go func() { SERVER.ListenAndServe() }()

		url := "http://" + HOST_IPv4 + ":" + HOST_PORT
		switch runtime.GOOS {
			case "windows":
				cmd := exec.Command("cmd", "/c", "start", url)
				cmd.Run()
			case "darwin":
				cmd := exec.Command("open", url)
				cmd.Run()
			case "linux":
				cmd := exec.Command("xdg-open", url)
				cmd.Run()
			default:
				println("未知操作系统, 自行打开浏览器.")
		}
	} else {
		IS_RUNNING = false
		SERVER.Shutdown(context.TODO())
	}
}


func (app *APP) InitConfig() map[string]string {
	return map[string]string{"ip": HOST_IPv4, "port": HOST_PORT, "share_dir": SHARE_DIR, "upload_dir": UPLOAD_DIR, "max_size": MAX_SIZE, "password": LOGIN_PASSWORD}
}