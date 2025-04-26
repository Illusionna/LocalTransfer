package main

import (
	"embed"
	"net/http"
)

//go:embed UI/*
var ui embed.FS

var SERVER *http.Server
var IS_RUNNING bool = false

var HOST_IPv4 string = GetLocalIPv4Addresses()
var HOST_PORT string = "8888"
var SHARE_DIR string = "."
var UPLOAD_DIR string = "."
var MAX_SIZE string = "1.2 GB"
var LOGIN_PASSWORD string = ""

var ANNOUNCEMENT_STATUS bool = true   // 公告栏状态, 若为 false, 则禁用前后端该功能, 以此类推.
var UPLOAD_STATUS       bool = true   // 上传状态.
var SEARCH_STATUS       bool = true   // 搜索状态.
var DELETE_STATUS       bool = true   // 删除状态.
var MKDIR_STATUS        bool = true   // 创建文件夹状态.
var COPY_STATUS         bool = true   // 复制粘贴状态.
var MOVE_STATUS         bool = true   // 移动放置状态.
var RENAME_STATUS       bool = true   // 重命名状态.

var USER_LOCK map[string]bool = map[string]bool{"localhost+curl": false, "127.0.0.1+curl": false}

var CURRENT_HANDLER http.Handler = http.NotFoundHandler()

var CONTENTEDITABLE string = "" // 公告栏富文本内容.

type DynamicHandler struct{}

type SERVER_PARAMS struct{
	ANNOUNCEMENT_STATUS_ bool   // 公告栏状态, 若为 false, 则禁用前后端该功能, 以此类推.
	UPLOAD_STATUS_       bool   // 上传状态.
	SEARCH_STATUS_       bool   // 搜索状态.
	DELETE_STATUS_       bool   // 删除状态.
	MKDIR_STATUS_        bool   // 创建文件夹状态.
	COPY_STATUS_         bool   // 复制粘贴状态.
	MOVE_STATUS_         bool   // 移动放置状态.
	RENAME_STATUS_       bool   // 重命名状态.
}

type FILE_INFO struct {
	FileName     string `json:"FileName"`     // 文件名称.
	FileSize     string `json:"FileSize"`     // 文件尺寸.
	FileIcon     string `json:"FileIcon"`     // 文件图标.
	ModifiedTime string `json:"ModifiedTime"` // 文件最后修改时间
}


type FILE_REQUEST struct {
	Path       string `json:"Path"`       // 请求文件的相对路径.
	CurrentDir string `json:"CurrentDir"` // 请求文件所在的当前目录.
}


type FILE_PROPERTY struct {
	FileCount    int64  `json:"FileCount"`    // 文件累计个数.
	SumSize      string `json:"SumSize"`      // 文件累计大小.
	ModifiedTime string `json:"ModifiedTime"` // 最后修改时间.
	AgoTime      string `json:"AgoTime"`      // 多久前.
}

type CONTENTEDITABLE_REQUEST struct {
	Content string `json:"Content"` // 公告栏内容.
}


type FILE_SEARCH struct {
	Path       []string `json:"Path"`
	Target     string   `json:"Target"`
	CurrentDir string   `json:"CurrentDir"`
}


type FILE_RENAME struct {
	CurrentDir string `json:"CurrentDir"`
	OldName    string `json:"OldName"`
	NewName    string `json:"NewName"`
	Prefix     string `json:"Prefix"`
	Suffix     string `json:"Suffix"`
}