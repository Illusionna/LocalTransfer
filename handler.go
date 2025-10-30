package main

import (
	"html/template"
	"net/http"
	"path/filepath"
	"strings"
	"time"
	"fmt"
	"os"
	"encoding/json"
)


func RegisterRouter() {
	http.HandleFunc("/login/", LoginHandler)
	http.HandleFunc("/", IndexHandler)
	http.HandleFunc("/UI/", UIHandler)
	http.HandleFunc("/docs/", APIDocsHandler)

	UpdateShareHandler()

	http.Handle("/api/share/", &DynamicHandler{})
	http.HandleFunc("/api/file-list/", FileInfoHandler)

	http.HandleFunc("/api/file-property/", ViewFilePropertyHandler)
	http.HandleFunc("/api/edit-announcement/", AuthorizeStatusMiddleware(&ANNOUNCEMENT_STATUS)(EditAnnouncementBoardHandler))
	http.HandleFunc("/api/announcement-content/", AuthorizeStatusMiddleware(&ANNOUNCEMENT_STATUS)(PublishAnnouncementBoardHandler))
	http.HandleFunc("/api/upload-file/", AuthorizeStatusMiddleware(&UPLOAD_STATUS)(UploadFileHandler))
	http.HandleFunc("/api/search-file/", AuthorizeStatusMiddleware(&SEARCH_STATUS)(SearchFileHandler))
	http.HandleFunc("/api/delete-file/", AuthorizeStatusMiddleware(&DELETE_STATUS)(DeleteFileHandler))
	http.HandleFunc("/api/batch-download/", BatchDownloadHandler)
	http.HandleFunc("/api/make-directory/", AuthorizeStatusMiddleware(&MKDIR_STATUS)(MakeDirectoryHandler))
	http.HandleFunc("/api/copy-file/", AuthorizeStatusMiddleware(&COPY_STATUS)(CopyFileHandler))
	http.HandleFunc("/api/move-file/", AuthorizeStatusMiddleware(&MOVE_STATUS)(MoveFileHandler))
	http.HandleFunc("/api/rename-file/", AuthorizeStatusMiddleware(&RENAME_STATUS)(RenameFileHandler))
}



func LoginHandler(w http.ResponseWriter, r *http.Request) {
	// 如果是 GET 请求, 直接返回 login.html 页面.
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

	// 必须通过 POST 请求登录前端页面.
	if r.Method != http.MethodPost {
		http.Error(w, "[* HTTP 405]: only POST request is allowed.", http.StatusMethodNotAllowed)
		return
	}

	// 解析前端输入框密码表单.
	err := r.ParseForm()
	if err != nil {
		http.Error(w, "[* HTTP 400]: invalid request body.", http.StatusBadRequest)
		return
	}

	// 获取用户登录密码.
	password := r.FormValue("password")
	/* 获取用户记录, 采用 ip + user-agent 格式.
	比如用户用 Edge 浏览器登录, 再用 Chrome 浏览器登录, 这属于两个 user, 每次都需要登录. */
	user := strings.Split(r.RemoteAddr, ":")[0] + "+" + r.Header.Get("User-Agent")

	// 如果用户登录密码等于文件传输服务登录密码, 则取消该用户登录锁.
	if password == LOGIN_PASSWORD {
		USER_LOCK[user] = false
		go func(user string) {
			// 启动该用户的登录锁协程, 半小时后再次给该 user 设置锁, 需要重新登录.
			time.Sleep(30 * time.Minute)
			delete(USER_LOCK, user)
		}(user)
		// 登录成功, 重定向到 index.html 页面.
		http.Redirect(w, r, "/", http.StatusMovedPermanently)
		return
	} else {
		// 如果 user 登录密码不正确, 前端打印错误信息.
		http.Error(w, "[* HTTP 401]: wrong password.", http.StatusUnauthorized)
		return
	}
}

func IndexHandler(w http.ResponseWriter, r *http.Request) {
	// 判断用户是否有登录锁, 若有锁, 则重定向到 login.html 页面.
	user := strings.Split(r.RemoteAddr, ":")[0] + "+" + r.Header.Get("User-Agent")
	if AuthorizeUser(user) {
		http.Redirect(w, r, "/login/", http.StatusMovedPermanently)
		return
	}

	if r.URL.Path != "/" {
		// 如果路由不存在, 返回 HTTP 404.
		http.Error(w, "[* HTTP 404]: not found.", http.StatusNotFound)
		return
	}

	// 渲染 HTML 模板, 渲染参数 utils.PARAMS.
	data, err := template.ParseFS(ui, "UI/index.html")
	if err != nil {
		http.Error(w, "[* HTTP 500]: fail to load \"index.html\" webpage.", http.StatusInternalServerError)
		return
	}

	data.Execute(w, SERVER_PARAMS{
		ANNOUNCEMENT_STATUS_: ANNOUNCEMENT_STATUS,
		UPLOAD_STATUS_: UPLOAD_STATUS,
		SEARCH_STATUS_: SEARCH_STATUS,
		DELETE_STATUS_: DELETE_STATUS,
		MKDIR_STATUS_: MKDIR_STATUS,
		COPY_STATUS_: COPY_STATUS,
		MOVE_STATUS_: MOVE_STATUS,
		RENAME_STATUS_: RENAME_STATUS,
	})
}

func UIHandler(w http.ResponseWriter, r *http.Request) {
	// 判断用户是否有登录锁, 若有锁, 则重定向到 login.html 页面.
	user := strings.Split(r.RemoteAddr, ":")[0] + "+" + r.Header.Get("User-Agent")
	if AuthorizeUser(user) {
		http.Redirect(w, r, "/login/", http.StatusMovedPermanently)
		return
	}

	// 加载 index.html 所有的静态资源.
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


func FileInfoHandler(w http.ResponseWriter, r *http.Request) {
	// 判断用户是否有登录锁, 若有锁, 则重定向到 login.html 页面.
	user := strings.Split(r.RemoteAddr, ":")[0] + "+" + r.Header.Get("User-Agent")
	if AuthorizeUser(user) {
		http.Redirect(w, r, "/login/", http.StatusMovedPermanently)
		return
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

	if !AccessSuperPath(path) {
		http.Error(w, "[* HTTP 400]: forbid accessing parent directory of the shared folder.", http.StatusBadRequest)
		return
	}

	file_list = append(file_list, GetFileInfo(filepath.Join(SHARE_DIR, path))...)

	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(file_list)
}


// 处理当前目录文件列表选中删除的文件.
func ViewFilePropertyHandler(w http.ResponseWriter, r *http.Request) {
	var selected_view_file_property []FILE_REQUEST
	if err := json.NewDecoder(r.Body).Decode(&selected_view_file_property); err != nil {
		http.Error(w, "[* HTTP 400]: invalid request body.", http.StatusBadRequest)
		return
	}

	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(CalculateProperty(selected_view_file_property))
}


// 获取公告栏编辑的数据来修改 golang 内存变量.
func EditAnnouncementBoardHandler(w http.ResponseWriter, r *http.Request) {
	var contenteditable CONTENTEDITABLE_REQUEST
	if err := json.NewDecoder(r.Body).Decode(&contenteditable); err != nil {
		http.Error(w, "[* HTTP 400]: invalid request body.", http.StatusBadRequest)
		return
	}
	CONTENTEDITABLE = contenteditable.Content
}


// 发送内存变量数据到前端公告栏.
func PublishAnnouncementBoardHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Content-Type", "application/json")
	response := map[string]string{"Content": CONTENTEDITABLE}
	json.NewEncoder(w).Encode(response)
}


// 处理文件上传.
func UploadFileHandler(w http.ResponseWriter, r *http.Request) {
	content_length := r.ContentLength
	if content_length > ParseStorageUnit(MAX_SIZE) {
		http.Error(w, "[* HTTP 413]: request is too large.", http.StatusRequestEntityTooLarge)
		return
	}

	if err := r.ParseMultipartForm(ParseStorageUnit(MAX_SIZE)); err != nil {
		http.Error(w, "[* HTTP 500]: fail to parse form.", http.StatusInternalServerError)
		return
	}

	upload_files := r.MultipartForm.File["File"]
	upload_file_relative_paths := r.MultipartForm.Value["RelativePath"]
	current_dirs := r.MultipartForm.Value["CurrentDir"]

	SaveUploadFile(upload_files, upload_file_relative_paths, current_dirs)

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(nil)
}


func SearchFileHandler(w http.ResponseWriter, r *http.Request) {
	var selected_file FILE_SEARCH
	if err := json.NewDecoder(r.Body).Decode(&selected_file); err != nil {
		http.Error(w, "[* HTTP 400]: invalid request body.", http.StatusBadRequest)
		return
	}

	ans := SearchFile(selected_file)

	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(ans)
}


func DeleteFileHandler(w http.ResponseWriter, r *http.Request) {
	var selected_file []FILE_REQUEST
	if err := json.NewDecoder(r.Body).Decode(&selected_file); err != nil {
		http.Error(w, "[* HTTP 400]: invalid request body.", http.StatusBadRequest)
		return
	}
	DeleteSelectedFile(selected_file)
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
		if _, err := buffer.WriteTo(w); err != nil {
			http.Error(w, "[* HTTP 500]: fail to archive the compressed zip file.", http.StatusInternalServerError)
			return
		}
	}
}


// 创建递归文件夹.
func MakeDirectoryHandler(w http.ResponseWriter, r *http.Request) {
	var makedir FILE_REQUEST
	if err := json.NewDecoder(r.Body).Decode(&makedir); err != nil {
		http.Error(w, "[* HTTP 400]: invalid request body.", http.StatusBadRequest)
		return
	}

	err := os.MkdirAll(filepath.Join(SHARE_DIR, makedir.CurrentDir, makedir.Path), os.ModePerm)
	if err != nil {
		http.Error(w, "[* HTTP 500]: fail to create directory.", http.StatusInternalServerError)
		return
	} else {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(nil)
	}
}


func CopyFileHandler(w http.ResponseWriter, r *http.Request) {
	var selected_file []FILE_REQUEST
	if err := json.NewDecoder(r.Body).Decode(&selected_file); err != nil {
		http.Error(w, "[* HTTP 400]: invalid request body.", http.StatusBadRequest)
		return
	}
	CopySelectedFile(selected_file)
}


// 移动文件.
func MoveFileHandler(w http.ResponseWriter, r *http.Request) {
	var selected_file []FILE_REQUEST
	if err := json.NewDecoder(r.Body).Decode(&selected_file); err != nil {
		http.Error(w, "[* HTTP 400]: invalid request body.", http.StatusBadRequest)
		return
	}
	MoveSelectedFile(selected_file)
}


// 重命名文件.
func RenameFileHandler(w http.ResponseWriter, r *http.Request) {
	var selected_file []FILE_RENAME
	if err := json.NewDecoder(r.Body).Decode(&selected_file); err != nil {
		http.Error(w, "[* HTTP 400]: invalid request body.", http.StatusBadRequest)
		return
	}
	RenameSelectedFile(selected_file)
}
