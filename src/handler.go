package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)


// 登录页面处理.
func LoginHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodGet {
		data, err := ui.ReadFile("UI/login.html")
		if err != nil {
			http.Error(w, "[* HTTP 500]: fail to load \"login.html\" webpage.", http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "text/html")
		w.Write(data)
		return
	}

	if r.Method != http.MethodPost {
        http.Error(w, "[* HTTP 405]: only POST request is allowed.", http.StatusMethodNotAllowed)
        return
    }

	err := r.ParseForm()
    if err != nil {
        http.Error(w, "[* HTTP 400]: invalid request body.", http.StatusBadRequest)
        return
    }
	password := r.FormValue("password")
	user := strings.Split(r.RemoteAddr, ":")[0] + "+" + r.Header.Get("User-Agent")

	if password == *LOGIN_PASSWORD {
		USER_LOCK[user] = false
		go func (user string)  {
			// 用户登录成功后半小时, 再次开启锁, 需要再次登录.
			time.Sleep(30 * time.Minute)
			delete(USER_LOCK, user)
		}(user)
		http.Redirect(w, r, "/", http.StatusMovedPermanently)
		return
	} else {
		http.Error(w, "[* HTTP 401]: wrong password.", http.StatusUnauthorized)
		return
	}
}


// 加载 index.html 入口网页.
func IndexHandler(w http.ResponseWriter, r *http.Request) {
	user := strings.Split(r.RemoteAddr, ":")[0] + "+" + r.Header.Get("User-Agent")
	if AuthorizeUser(user) {
		http.Redirect(w, r, "/login/", http.StatusMovedPermanently)
		return
	}

	if r.URL.Path != "/" {
		// 如果路由不存在, 重定向到 HTTP 404 页面.
		http.Redirect(w, r, "/HTTP404", http.StatusMovedPermanently)
		return
	}

	// 渲染 index.html 页面.
	data, err := ui.ReadFile("UI/index.html")
	if err != nil {
		http.Error(w, "[* HTTP 500]: fail to load \"index.html\" webpage.", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/html")
	w.Write(data)
}

// 加载渲染网页 UI 的静态文件.
func UIHandler(w http.ResponseWriter, r *http.Request) {
	user := strings.Split(r.RemoteAddr, ":")[0] + "+" + r.Header.Get("User-Agent")
	if AuthorizeUser(user) {
		http.Redirect(w, r, "/login/", http.StatusMovedPermanently)
		return
	}

	data, err := ui.ReadFile(r.URL.Path[1:])
	if err != nil {
		http.Error(w, "[* HTTP 404]: fail to find file \""+r.URL.Path[1:]+"\"", http.StatusNotFound)
		return
	}

	switch filepath.Ext(r.URL.Path) {
	case ".css":
		w.Header().Set("Content-Type", "text/css")
	case ".js":
		w.Header().Set("Content-Type", "application/javascript")
	case ".svg":
		w.Header().Set("Content-Type", "image/svg+xml")
	default:
		w.Header().Set("Content-Type", "text/plain")
	}

	w.Write(data)
}

// 重定向到 HTTP 404 页面.
func HTTP404Handler(w http.ResponseWriter, r *http.Request) {
	user := strings.Split(r.RemoteAddr, ":")[0] + "+" + r.Header.Get("User-Agent")
	if AuthorizeUser(user) {
		http.Redirect(w, r, "/login/", http.StatusMovedPermanently)
		return
	}

	data, err := ui.ReadFile("UI/404.html")
	if err != nil {
		http.Error(w, "[* HTTP 500]: fail to load \"404.html\" webpage.", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/html")
	w.Write(data)
}

// 重定向到 HTTP 500 页面.
func HTTP500Handler(w http.ResponseWriter, r *http.Request) {
	user := strings.Split(r.RemoteAddr, ":")[0] + "+" + r.Header.Get("User-Agent")
	if AuthorizeUser(user) {
		http.Redirect(w, r, "/login/", http.StatusMovedPermanently)
		return
	}

	data, err := ui.ReadFile("UI/500.html")
	if err != nil {
		http.Error(w, "[* HTTP 500]: fail to load \"500.html\" webpage.", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/html")
	w.Write(data)
}

/*
	处理当前目录的文件列表页面, 可使用 GET 请求调用接口.

>>> [√] curl "http://localhost:8888/api/file-list?path=/UI/"
>>> [x] curl "http://localhost:8888/api/file-list?path=../"
*/
func FileInfoHandler(w http.ResponseWriter, r *http.Request) {
	user := strings.Split(r.RemoteAddr, ":")[0] + "+" + r.Header.Get("User-Agent")
	if AuthorizeUser(user) {
		http.Redirect(w, r, "/login/", http.StatusMovedPermanently)
		return
	}

	AccessSuperDirectory := func(dir string) bool {
		// 禁止使用 ".." 访问父级目录, 并且禁止使用绝对路径访问后端目录.
		if strings.Contains(dir, "..") || filepath.IsAbs(dir) {
			return false
		}
		return true
	}

	var file_list []FILE_INFO
	path := r.URL.Query().Get("path")
	if path != "." {
		file_list = append(file_list, FILE_INFO{
			FileName:     ". .",
			FileSize:     "",
			FileIcon:     "NULL",
			ModifiedTime: "",
		})
	}

	if !AccessSuperDirectory(path) {
		http.Error(w, "[* HTTP 400]: forbid accessing parent directory of the shared folder.", http.StatusBadRequest)
		return
	}

	file_list = append(file_list, GetFileInfo(filepath.Join(*SHARE_DIR, path))...)

	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(file_list)
}


// 处理当前目录文件列表选中删除的文件.
func ViewFilePropertyHandler(w http.ResponseWriter, r *http.Request) {
	user := strings.Split(r.RemoteAddr, ":")[0] + "+" + r.Header.Get("User-Agent")
	if AuthorizeUser(user) {
		http.Redirect(w, r, "/login/", http.StatusMovedPermanently)
		return
	}

	if r.Method != http.MethodPost {
		http.Error(w, "[* HTTP 405]: only POST request is allowed.", http.StatusMethodNotAllowed)
		return
	}

	var selected_view_file_property []FILE_REQUEST
	if err := json.NewDecoder(r.Body).Decode(&selected_view_file_property); err != nil {
		http.Error(w, "[* HTTP 400]: invalid request body.", http.StatusBadRequest)
		return
	}

	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(CalculateProperty(selected_view_file_property))
}

func DeleteFileHandler(w http.ResponseWriter, r *http.Request) {
	user := strings.Split(r.RemoteAddr, ":")[0] + "+" + r.Header.Get("User-Agent")
	if AuthorizeUser(user) {
		http.Redirect(w, r, "/login/", http.StatusMovedPermanently)
		return
	}

	if r.Method != http.MethodPost {
		http.Error(w, "[* HTTP 405]: only POST request is allowed.", http.StatusMethodNotAllowed)
		return
	}
	var selected_file []FILE_REQUEST
	if err := json.NewDecoder(r.Body).Decode(&selected_file); err != nil {
		http.Error(w, "[* HTTP 400]: invalid request body.", http.StatusBadRequest)
		return
	}
	DeleteSelectedFile(selected_file)
}

// 查看 API 文档页面.
func APIDocsHandler(w http.ResponseWriter, r *http.Request) {
	user := strings.Split(r.RemoteAddr, ":")[0] + "+" + r.Header.Get("User-Agent")
	if AuthorizeUser(user) {
		http.Redirect(w, r, "/login/", http.StatusMovedPermanently)
		return
	}

	data, err := ui.ReadFile("UI/docs.html")
	if err != nil {
		http.Error(w, "[* HTTP 500]: fail to load \"docs.html\" webpage.", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/html")
	w.Write(data)
}

// 批量下载功能.
func BatchDownloadHandler(w http.ResponseWriter, r *http.Request) {
	user := strings.Split(r.RemoteAddr, ":")[0] + "+" + r.Header.Get("User-Agent")
	if AuthorizeUser(user) {
		http.Redirect(w, r, "/login/", http.StatusMovedPermanently)
		return
	}

	if r.Method != http.MethodPost {
		http.Error(w, "[* HTTP 405]: only POST request is allowed.", http.StatusMethodNotAllowed)
		return
	}

	var selected_file []FILE_REQUEST
	if err := json.NewDecoder(r.Body).Decode(&selected_file); err != nil {
		http.Error(w, "[* HTTP 400]: invalid request body.", http.StatusBadRequest)
		return
	}

	buffer := ArchiveZip(selected_file)

	if buffer == nil {
		http.Error(w, "[* HTTP 500]: fail to archive the compressed zip file.", http.StatusInternalServerError)
		return
	} else {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "POST")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		w.Header().Set("Content-Type", "application/zip")
		w.Header().Set("Content-Disposition", "attachment; filename=archive.zip")
		w.Header().Set("Content-Length", fmt.Sprintf("%d", buffer.Len()))
		if _, err := buffer.WriteTo(w); err == nil {
			http.Error(w, "[* HTTP 500]: fail to archive the compressed zip file.", http.StatusInternalServerError)
			return
		}
	}
}

// 获取公告栏编辑的数据来修改 golang 内存变量.
func EditAnnouncementBoardHandler(w http.ResponseWriter, r *http.Request) {
	user := strings.Split(r.RemoteAddr, ":")[0] + "+" + r.Header.Get("User-Agent")
	if AuthorizeUser(user) {
		http.Redirect(w, r, "/login/", http.StatusMovedPermanently)
		return
	}

	if r.Method != http.MethodPost {
		http.Error(w, "[* HTTP 405]: only POST request is allowed.", http.StatusMethodNotAllowed)
		return
	}

	var contenteditable CONTENTEDITABLE_REQUEST
	if err := json.NewDecoder(r.Body).Decode(&contenteditable); err != nil {
		http.Error(w, "[* HTTP 400]: invalid request body.", http.StatusBadRequest)
		return
	}

	CONTENTEDITABLE = contenteditable.Content
}

// 发送内存变量数据到前端公告栏.
func PublishAnnouncementBoardHandler(w http.ResponseWriter, r *http.Request) {
	user := strings.Split(r.RemoteAddr, ":")[0] + "+" + r.Header.Get("User-Agent")
	if AuthorizeUser(user) {
		http.Redirect(w, r, "/login/", http.StatusMovedPermanently)
		return
	}

	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Content-Type", "application/json")
	response := map[string]string{"Content": CONTENTEDITABLE}
	json.NewEncoder(w).Encode(response)
}

// 创建递归文件夹.
func MakeDirectoryHandler(w http.ResponseWriter, r *http.Request) {
	user := strings.Split(r.RemoteAddr, ":")[0] + "+" + r.Header.Get("User-Agent")
	if AuthorizeUser(user) {
		http.Redirect(w, r, "/login/", http.StatusMovedPermanently)
		return
	}

	if r.Method != http.MethodPost {
		http.Error(w, "[* HTTP 405]: only POST request is allowed.", http.StatusMethodNotAllowed)
		return
	}
	var makedir FILE_REQUEST
	if err := json.NewDecoder(r.Body).Decode(&makedir); err != nil {
		http.Error(w, "[* HTTP 400]: invalid request body.", http.StatusBadRequest)
		return
	}
	err := os.MkdirAll(filepath.Join(*SHARE_DIR, makedir.CurrentDir, makedir.Path), os.ModePerm)
	if err != nil {
		http.Error(w, "[* HTTP 500]: fail to create directory.", http.StatusInternalServerError)
		return
	} else {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(nil)
	}
}

// 移动文件.
func MoveFileHandler(w http.ResponseWriter, r *http.Request) {
	user := strings.Split(r.RemoteAddr, ":")[0] + "+" + r.Header.Get("User-Agent")
	if AuthorizeUser(user) {
		http.Redirect(w, r, "/login/", http.StatusMovedPermanently)
		return
	}

	if r.Method != http.MethodPost {
		http.Error(w, "[* HTTP 405]: only POST request is allowed.", http.StatusMethodNotAllowed)
		return
	}
	var selected_file []FILE_REQUEST
	if err := json.NewDecoder(r.Body).Decode(&selected_file); err != nil {
		http.Error(w, "[* HTTP 400]: invalid request body.", http.StatusBadRequest)
		return
	}
	MoveSelectedFile(selected_file)
}

// 重命名文件.
func RenameFileHandler(w http.ResponseWriter, r *http.Request) {
	user := strings.Split(r.RemoteAddr, ":")[0] + "+" + r.Header.Get("User-Agent")
	if AuthorizeUser(user) {
		http.Redirect(w, r, "/login/", http.StatusMovedPermanently)
		return
	}

	if r.Method != http.MethodPost {
		http.Error(w, "[* HTTP 405]: only POST request is allowed.", http.StatusMethodNotAllowed)
		return
	}
	var selected_file []FILE_RENAME
	if err := json.NewDecoder(r.Body).Decode(&selected_file); err != nil {
		http.Error(w, "[* HTTP 400]: invalid request body.", http.StatusBadRequest)
		return
	}
	RenameSelectedFile(selected_file)
}

// 复制文件.
func CopyFileHandler(w http.ResponseWriter, r *http.Request) {
	user := strings.Split(r.RemoteAddr, ":")[0] + "+" + r.Header.Get("User-Agent")
	if AuthorizeUser(user) {
		http.Redirect(w, r, "/login/", http.StatusMovedPermanently)
		return
	}

	if r.Method != http.MethodPost {
		http.Error(w, "[* HTTP 405]: only POST request is allowed.", http.StatusMethodNotAllowed)
		return
	}
	var selected_file []FILE_REQUEST
	if err := json.NewDecoder(r.Body).Decode(&selected_file); err != nil {
		http.Error(w, "[* HTTP 400]: invalid request body.", http.StatusBadRequest)
		return
	}
	CopySelectedFile(selected_file)
}

// 处理文件上传.
func UploadFileHandler(w http.ResponseWriter, r *http.Request) {
	user := strings.Split(r.RemoteAddr, ":")[0] + "+" + r.Header.Get("User-Agent")
	if AuthorizeUser(user) {
		http.Redirect(w, r, "/login/", http.StatusMovedPermanently)
		return
	}

	if r.Method != http.MethodPost {
		http.Error(w, "[* HTTP 405]: only POST request is allowed.", http.StatusMethodNotAllowed)
		return
	}

	content_length := r.ContentLength
	if content_length > ParseStorageUnit(*MAX_SIZE) {
		http.Error(w, "[* HTTP 403]: request is too large.", http.StatusRequestEntityTooLarge)
        return
	}

	if err := r.ParseMultipartForm(ParseStorageUnit(*MAX_SIZE)); err != nil {
		http.Error(w, "[* HTTP 400]: fail to parse form.", http.StatusBadRequest)
        return
	}

	upload_files := r.MultipartForm.File["File"]
	upload_file_relative_paths := r.MultipartForm.Value["RelativePath"]
	current_dirs := r.MultipartForm.Value["CurrentDir"]

	SaveUploadFile(upload_files, upload_file_relative_paths, current_dirs)

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(nil)
}

// 搜索文件.
func SearchFileHandler(w http.ResponseWriter, r *http.Request) {
	user := strings.Split(r.RemoteAddr, ":")[0] + "+" + r.Header.Get("User-Agent")
	if AuthorizeUser(user) {
		http.Redirect(w, r, "/login/", http.StatusMovedPermanently)
		return
	}

	if r.Method != http.MethodPost {
		http.Error(w, "[* HTTP 405]: only POST request is allowed.", http.StatusMethodNotAllowed)
		return
	}

	var selected_file []STANDARD_SEARCH
	if err := json.NewDecoder(r.Body).Decode(&selected_file); err != nil {
		http.Error(w, "[* HTTP 400]: invalid request body.", http.StatusBadRequest)
		return
	}

	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Content-Type", "application/json")

	start := time.Now()
	data := SearchFile(selected_file)
	diff := time.Since(start).Seconds() * 1000

	if diff < 1000 {
		json.NewEncoder(w).Encode(map[string]interface{}{"data": data, "time": fmt.Sprintf("%.2fms", diff)})
	} else {
		json.NewEncoder(w).Encode(map[string]interface{}{"data": data, "time": fmt.Sprintf("%.2fs", diff / 1000)})
	}
}