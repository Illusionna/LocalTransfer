package main

import (
	"archive/zip"
	"bytes"
	"fmt"
	"io"
	"mime/multipart"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
	"unsafe"
	"runtime"
	"github.com/wangshizebin/jiebago"
)

/*
# include "main.c"
*/
import "C"

// 根据用户锁确定是否授权.
func AuthorizeUser(user string) bool {
	if _, ok := USER_LOCK[user]; ok {
		return USER_LOCK[user]
    } else {
		USER_LOCK[user] = (*LOGIN_PASSWORD != "")
		return USER_LOCK[user]
    }
}

// 授权文件传输服务中间件.
func AuthorizeShareFileMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		user := strings.Split(r.RemoteAddr, ":")[0] + "+" + r.Header.Get("User-Agent")
		if AuthorizeUser(user) {
			http.Redirect(w, r, "/login/", http.StatusMovedPermanently)
			return
		}
		next.ServeHTTP(w, r)
	})
}


/* 把字节数转换成通常的单位.
  >>> ConvertStorageUnit(1536)
  >>> "1.50 KB" */
func ConvertStorageUnit(x int64) string {
	y := ""
	if x < (1 << 10) {
		y = fmt.Sprintf("%d B", x)
	} else if x < (1 << 20) {
		y = fmt.Sprintf("%.2f KB", float64(x) / (1 << 10))
	} else if x < (1 << 30) {
		y = fmt.Sprintf("%.2f MB", float64(x) / (1 << 20))
	} else {
		y = fmt.Sprintf("%.2f GB", float64(x) / (1 << 30))
	}
	return y
}


func CleanIllegalCharacter(path string) string {
	path = strings.Replace(path, "../", "", -1)
	path = strings.Replace(path, "..\\", "", -1)
	path = strings.Replace(path, "./", "", -1)
	path = strings.Replace(path, ".\\", "", -1)
	re := regexp.MustCompile("[\\/:*?\"<>|]")
	return re.ReplaceAllString(path, " ")
}


func SortDict(m map[string]int) []string {
	ans := make([]string, 0, len(m))
	for key := range m {
		ans = append(ans, key)
	}
	sort.Slice(ans, func(i, j int) bool {return m[ans[i]] > m[ans[j]]})
	return ans
}

// 把单位解析成计算机字节.
func ParseStorageUnit(size string) int64 {
	re := regexp.MustCompile(`(?i)^([\d.]+)\s*([KMGT]B?|B)$`)
	match := re.FindStringSubmatch(strings.TrimSpace(size))
	if len(match) != 3 {
        // 默认值 1.2GB.
		return 1288490188
	}
	value, err := strconv.ParseFloat(match[1], 64)
	if err != nil {
        // 默认值 1.2GB.
		return 1288490188
	}
	unit := strings.ToUpper(match[2])
	var multiplier int64
	switch unit {
        case "B":
            multiplier = 1
        case "K":
            multiplier = 1 << 10
        case "KB":
            multiplier = 1 << 10
        case "M":
            multiplier = 1 << 20
        case "MB":
            multiplier = 1 << 20
        case "G":
            multiplier = 1 << 30
        case "GB":
            multiplier = 1 << 30
        case "T":
            multiplier = 1 << 40
        case "TB":
            multiplier = 1 << 40
        default:
            // 默认值 1.2GB.
            return 1288490188
	}
	return int64(value * float64(multiplier))
}


// 根据 Zeller 公式将日期转化成星期.
func ZellerFunction(year, month, day int) string {
	var weekday = [7]string{"星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"}
	var y, m, c int
    if month >= 3 {
        m = month
        y = year % 100
        c = year / 100
    } else {
        m = month + 12
        y = (year - 1) % 100
        c = (year - 1) / 100
    }
    week := y + (y / 4) + (c / 4) - 2 * c + ((26 * (m + 1)) / 10) + day - 1
    if week < 0 {
        week = 7 - (-week) % 7
    } else {
        week = week % 7
    }
    return weekday[week]
}


// 把计算机时间切换成人类口语.
func TimeSwitchTongue(modified_time time.Time) string {
	// 这些我日常生活中常用的枚举类.
	const (
		now TIME_RANGE = iota
		one_minute
		three_minutes
		one_quarter
		half_hour
		one_hour
		one_Chinese_zodiac_time
		half_day
		one_day
		two_days
		three_days
		one_week
		half_month
	)

	F := func(t TIME_RANGE) string {
		switch t {
			case now:
				return "刚刚"
			case one_minute:
				return "一分钟前"
			case three_minutes:
				return "三分钟前"
			case one_quarter:
				return "一刻钟前"
			case half_hour:
				return "半小时前"
			case one_hour:
				return "一小时前"
			case one_Chinese_zodiac_time:
				return "一个时辰前"
			case half_day:
				return "半天前"
			case one_day:
				return "一天前"
			case two_days:
				return "两天前"
			case three_days:
				return "三天前"
			case one_week:
				return "一周前"
			case half_month:
				return "半个月前"
			default:
				return "NULL"
		}
	}

	SinceYear := func(date time.Time) int {
		today := time.Now()
		year1 := date.Year()
		year2 := today.Year()
		year_diff := year2 - year1
		if (date.Month() > today.Month() || (date.Month() == today.Month() && date.Day() > today.Day())) {
			year_diff--
		}
		return year_diff
	}

	SinceMonth := func(date time.Time) int {
		now := time.Now()
		years := now.Year() - date.Year()
		months := int(now.Month()) - int(date.Month())
		if months < 0 {
			years--
			months = months + 12
		}
		if now.Day() < date.Day() {
			months--
		}
		total_months := years * 12 + months
		if total_months < 0 {
			return 0
		}
		return total_months
	}

	diff := time.Since(modified_time)
	// diff := time.Now().Sub(modified_time)
	var ans string

	if diff < time.Minute {
		ans = F(now)
	} else if diff < 3 * time.Minute {
		ans = F(one_minute)
	} else if diff < 15 * time.Minute {
		ans = F(three_minutes)
	} else if diff < 30 * time.Minute {
		ans = F(one_quarter)
	} else if diff < 1 * time.Hour {
		ans = F(half_hour)
	} else if diff < 2 * time.Hour {
		ans = F(one_hour)
	} else if diff < 12 * time.Hour {
		ans = F(one_Chinese_zodiac_time)
	} else if diff < 24 * time.Hour {
		ans = F(half_day)
	} else if diff < 48 * time.Hour {
		ans = F(one_day)
	} else if diff < 72 * time.Hour {
		ans = F(two_days)
	} else if diff < 168 * time.Hour {
		ans = F(three_days)
	} else if diff < 360 * time.Hour {
		ans = F(one_week)
	} else if diff < 720 * time.Hour {
		ans = F(half_month)
	} else {
		years := SinceYear(modified_time)
		if years < 1 {
			ans = fmt.Sprintf("%d 个月前", SinceMonth(modified_time))
		} else {
			ans = fmt.Sprintf("%d 年前", years)
		}
	}
	return ans + "（" + ZellerFunction(modified_time.Year(), int(modified_time.Month()), modified_time.Day()) + "）"
}


/* 获取目录文件信息列表.
  >>> GetFileInfo("../Illusionna/Desktop")
  >>> [{"FileName": "Ollava.exe", "FileSize": "10 MB", "FileIcon": "exe", "ModifiedTime": "2025-01-16 12:12:12"}, {"FileName": "bin", "FileSize": "----", "FileIcon": "FOLDER", "ModifiedTime": "2025-01-16 12:12:11"}, ...] */
func GetFileInfo(dir string) []FILE_INFO {
	var file_list []FILE_INFO
	entries, err := os.ReadDir(dir)
	if err != nil {
		// 如果读取异常, 返回空结构体数组.
		return file_list
	}

	for _, entry := range entries {
		info, err := entry.Info()
		if err != nil {
			// 如果有异常, 则跳过该文件.
			continue
		}
	
		var file_size string
		var file_icon string

		if info.IsDir() {
			file_size = "----"
			file_icon = "FOLDER"
		} else {
			file_size = ConvertStorageUnit(info.Size())
			file_icon = filepath.Ext(info.Name())
			// 如果文件无后缀扩展, 则图标为 NULL.svg 类型.
			if file_icon == "" {
				file_icon = "NULL"
			} else {
				// 后缀扩展不区分大小写.
				file_icon = strings.ToLower(file_icon[1:])
			}
		}

		file_list = append(file_list, FILE_INFO{
			FileName: info.Name(),
			FileSize: file_size,
			FileIcon: file_icon,
			ModifiedTime: info.ModTime().Format("2006-01-02 15:04:05"),
		})
	}
	return file_list
}


/* 获取文件夹的字节数和所有文件的数量. 
  >>> GetFolderSizeAndFileCount(".")
  >>> 2560, 7, nil */
func GetFolderSizeAndFileCount(dir string) (int64, int64, error) {
	var size int64
	var count int64
	err := filepath.Walk(dir, func(_ string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() {
			size = size + info.Size()
			count++
		}
		return nil
	})
	return size, count, err
}


// 计算选中的文件累计大小、文件数量、最后修改时间、距今时间四个属性.
func CalculateProperty(selected_view_file_property []FILE_REQUEST) FILE_PROPERTY {
	if len(selected_view_file_property) == 1 {
		info, err := os.Stat(filepath.Join(*SHARE_DIR, selected_view_file_property[0].Path))
		if err != nil {
			return FILE_PROPERTY{
				FileCount: 0,
				SumSize: "NULL",
				ModifiedTime: "NULL",
				AgoTime: "NULL",
			}
		}
		if info.IsDir() {
			size, count, err := GetFolderSizeAndFileCount(filepath.Join(*SHARE_DIR, selected_view_file_property[0].Path))
			if err != nil {
				return FILE_PROPERTY{
					FileCount: 0,
					SumSize: "NULL",
					ModifiedTime: "NULL",
					AgoTime: "NULL",
				}
			}
			return FILE_PROPERTY{
				FileCount: count,
				SumSize: ConvertStorageUnit(size),
				ModifiedTime: info.ModTime().Format("2006-01-02 15:04:05"),
				AgoTime: TimeSwitchTongue(info.ModTime()),
			}
		} else {
			return FILE_PROPERTY{
				FileCount: 1,
				SumSize: ConvertStorageUnit(info.Size()),
				ModifiedTime: info.ModTime().Format("2006-01-02 15:04:05"),
				AgoTime: TimeSwitchTongue(info.ModTime()),
			}
		}
	} else {
		var file_count int64 = 0
		var sum_size int64 = 0
		var modified_time time.Time
		for _, file := range selected_view_file_property {
			info, err := os.Stat(filepath.Join(*SHARE_DIR, file.Path))
			if err != nil {
				continue
			}
			if info.IsDir() {
				size, count, err := GetFolderSizeAndFileCount(filepath.Join(*SHARE_DIR, file.Path))
				if err != nil {
					continue
				}
				file_count = file_count + count
				sum_size = sum_size + size
			} else {
				file_count++
				sum_size = sum_size + info.Size()
				
			}
			if info.ModTime().After(modified_time) {
				modified_time = info.ModTime()
			}
		}
		return FILE_PROPERTY{
			FileCount: file_count,
			SumSize: ConvertStorageUnit(sum_size),
			ModifiedTime: modified_time.Format("2006-01-02 15:04:05"),
			AgoTime: TimeSwitchTongue(modified_time),
		}
	}
}


// 删除所选中的文件.
func DeleteSelectedFile(selected_file []FILE_REQUEST) {
	AccessSuperPath := func(path string) bool {
		// 禁止使用 ".." 访问父级文件, 并且禁止使用绝对路径访问后端文件.
		if strings.Contains(path, "..") || filepath.IsAbs(path) {
			return false
		}
		return true
	}

	for _, file := range selected_file {
		if !AccessSuperPath(file.Path) {
			continue
		}
	
		info, err := os.Stat(filepath.Join(*SHARE_DIR, file.Path))
		if err != nil {
			continue
		}
		if info.IsDir() {
			err := os.RemoveAll(filepath.Join(*SHARE_DIR, file.Path))
			if err != nil {
				continue
			}
		} else {
			err := os.Remove(filepath.Join(*SHARE_DIR, file.Path))
			if err != nil {
				continue
			}
		}
	}
}


// 归档成 zip 压缩包.
func ArchiveZip(selected_file []FILE_REQUEST) *bytes.Buffer {
	AccessSuperPath := func(path string) bool {
		// 禁止使用 ".." 访问父级文件, 并且禁止使用绝对路径访问后端文件.
		if strings.Contains(path, "..") || filepath.IsAbs(path) {
			return false
		}
		return true
	}

	buffer := new(bytes.Buffer)
	zip_writer := zip.NewWriter(buffer)
	defer zip_writer.Close()

	for _, file := range selected_file {
		if !AccessSuperPath(file.Path) {
			// 禁止批量下载越界文件.
			continue
		}

		full_path := filepath.Join(*SHARE_DIR, file.Path)

		err := filepath.Walk(full_path, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}
			var relative_path string
			relative_path, err = filepath.Rel(filepath.Join(*SHARE_DIR, file.CurrentDir), path)
			relative_path = strings.ReplaceAll(relative_path, "\\", "/")
			if err != nil {
				return err
			}
			header, err := zip.FileInfoHeader(info)
			if err != nil {
				return err
			}
			header.Name = relative_path
			if info.IsDir() {
				header.Name = header.Name + "/"
			} else {
				header.Method = zip.Deflate
			}
			writer, err := zip_writer.CreateHeader(header)
			if err != nil {
				return err
			}
			if info.IsDir() {
				return nil
			}
			f, err := os.Open(path)
			if err != nil {
				return err
			}
			defer f.Close()
			_, err = io.Copy(writer, f)
			return err
		})

		if err != nil {
			buffer = nil
			break
		}
	}

	err := zip_writer.Close()
	if err != nil {
		buffer = nil
	}
	return buffer
}


// 移动被选中的文件.
func MoveSelectedFile(selected_file []FILE_REQUEST) {
	AccessSuperPath := func(path string) bool {
		// 禁止使用 ".." 访问父级文件, 并且禁止使用绝对路径访问后端文件.
		if strings.Contains(path, "..") || filepath.IsAbs(path) {
			return false
		}
		return true
	}

	for _, file := range selected_file {
		if !AccessSuperPath(file.Path) {
			// 禁止越界移动文件.
			continue
		}

		_, err := os.Stat(filepath.Join(*SHARE_DIR, file.CurrentDir, filepath.Base(file.Path)))
		if err != nil {
			// 没有目标文件.
			err := os.Rename(filepath.Join(*SHARE_DIR, file.Path), filepath.Join(*SHARE_DIR, file.CurrentDir, filepath.Base(file.Path)))
			if err != nil {
				continue
			}
		} else {
			// 有目标文件, 跳过本次循环的移动.
			continue
		}
	}
}


// 获取路径的文件扩展.
func GetMultiExtRegexp(filename string) string {
    re := regexp.MustCompile(`(\.[^.]+)+$`)
    matches := re.FindAllString(filename, -1)
    if len(matches) == 0 {
        return ""
    }
    full_ext := ""
    for i := len(matches) -1 ; i >= 0; i -- {
        full_ext = matches[i] + full_ext
		if i > 0 && matches[i-1] != ""{
			re = regexp.MustCompile(`([^.]+)$`)
			previous_match := re.FindString(filename[:len(filename)-len(full_ext)])
			if previous_match =="" {
				break
			}
		}
    }
    return full_ext
}


// 重命名选中的文件.
func RenameSelectedFile(selected_file []FILE_RENAME) {
	AccessSuperPath := func(path string) bool {
		// 禁止使用 ".." 访问父级文件, 并且禁止使用绝对路径访问后端文件.
		if strings.Contains(path, "..") || filepath.IsAbs(path) {
			return false
		}
		return true
	}

	if len(selected_file) == 1 {
		if !AccessSuperPath(selected_file[0].OldName) {
			// 禁止越界重命名文件.
		} else {
			_, err := os.Stat(filepath.Join(*SHARE_DIR, selected_file[0].CurrentDir, selected_file[0].NewName))
			if err != nil {
				os.Rename(
					filepath.Join(*SHARE_DIR, selected_file[0].CurrentDir, selected_file[0].OldName),
					filepath.Join(*SHARE_DIR, selected_file[0].CurrentDir, selected_file[0].NewName),
				)
			} else {
				// 如果目标文件已存在, 则不允许改为相同的名字.
			}
		}
	} else {
		for idx, file := range selected_file {
			if !AccessSuperPath(file.OldName) {
				// 禁止越界重命名文件.
				continue
			}
			old_name := filepath.Join(*SHARE_DIR, file.CurrentDir, file.OldName)
			var new_name string
			info, err := os.Stat(old_name)
			if err != nil {
				continue
			} else {
				if info.IsDir() {
					new_name = fmt.Sprintf("%s%d%s", file.Prefix, idx + 1, file.Suffix)
				} else {
					ext := GetMultiExtRegexp(filepath.Base(old_name))
					new_name = fmt.Sprintf("%s%d%s%s", file.Prefix, idx + 1, file.Suffix, ext)
				}
				new_name = filepath.Join(*SHARE_DIR, file.CurrentDir, new_name)
				_, err := os.Stat(new_name)
				if err != nil {
					os.Rename(
						old_name,
						new_name,
					)
				} else {
					// 如果目标文件已存在, 则不允许改为相同的名字.
				}
			}
		}
	}
}


func CopyFile(src, dst string) error {
	if _, err := os.Stat(dst); err == nil {
		// 如果目标文件已经存在, 则不允许覆盖.
		return err
	}

	source_file, err := os.Open(src)
	if err != nil {
		return err
	}
	defer source_file.Close()

	if err := os.MkdirAll(filepath.Dir(dst), os.ModePerm); err != nil {
		return err
	}

	destination_file, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer destination_file.Close()

	_, err = io.Copy(destination_file, source_file)
	return err
}


func CopyDirectory(src, dst string) error {
	src_info, err := os.Stat(src)
	if err != nil {
		return err
	}

	if err := os.MkdirAll(dst, src_info.Mode()); err != nil {
		return err
	}

	entries, err := os.ReadDir(src)
	if err != nil {
		return err
	}

	for _, entry := range entries {
		src_path := filepath.Join(src, entry.Name())
		dst_path := filepath.Join(dst, entry.Name())

		if entry.IsDir() {
			// 递归调用.
			if err := CopyDirectory(src_path, dst_path); err != nil {
				return err
			}
		} else {
			if err := CopyFile(src_path, dst_path); err != nil {
				return err
			}
		}
	}
	return nil
}


func CopySelectedFile(selected_file []FILE_REQUEST) {
	AccessSuperPath := func(path string) bool {
		// 禁止使用 ".." 访问父级文件, 并且禁止使用绝对路径访问后端文件.
		if strings.Contains(path, "..") || filepath.IsAbs(path) {
			return false
		}
		return true
	}

	Copy := func(src string, dst string) {
		src_info, err := os.Stat(src)
		if err != nil {
			return
		}
		if src_info.IsDir() {
			if err := CopyDirectory(src, dst); err != nil {
				return
			}
		} else {
			if err := CopyFile(src, dst); err != nil {
				return
			}
		}
	}

	for _, file := range selected_file {
		if !AccessSuperPath(file.Path) {
			// 禁止越界拷贝文件.
			continue
		}
		Copy(
			filepath.Join(*SHARE_DIR, file.Path),
			filepath.Join(*SHARE_DIR, file.CurrentDir, filepath.Base(file.Path)),
		)
	}
}


// 保持上传的文件.
func SaveUploadFile(files []*multipart.FileHeader, relative_paths, current_dirs []string) {
	var current_dir string
	if *UPLOAD_DIR != *SHARE_DIR {
		current_dir = "."
	} else {
		current_dir = current_dirs[0]
	}

	for idx, file := range files {
		dst_path := filepath.Join(*UPLOAD_DIR, current_dir, relative_paths[idx])
		if _, err := os.Stat(dst_path); err != nil {
			err := os.MkdirAll(filepath.Dir(dst_path), os.ModePerm)
			if err != nil {
				continue
			}
			src, err := file.Open()
			if err != nil {
				continue
			}
			defer src.Close()
			dst, err := os.Create(dst_path)
			if err != nil {
				continue
			}
			defer dst.Close()
			if _, err = io.Copy(dst, src); err != nil {
				continue
			}
		} else {
			// 如果目标位置已经存在同名文件, 则不允许覆盖, 跳过.
		}
	}
}




func GetLocalIPv4Addresses() ([]string, error) {
	var ipv4Addresses []string

	// 获取所有网络接口
	interfaces, err := net.Interfaces()
	if err != nil {
		return nil, fmt.Errorf("获取网络接口失败: %w", err)
	}

	for _, iface := range interfaces {
		// 忽略回环接口 (localhost)
		if iface.Flags&net.FlagLoopback != 0 {
			continue
		}
		// 忽略未激活的接口
		if iface.Flags&net.FlagUp == 0 {
			continue
		}
        
		// 获取接口的地址
		addrs, err := iface.Addrs()
		if err != nil {
			continue // 忽略错误
		}

		for _, addr := range addrs {
			var ip net.IP

			switch v := addr.(type) {
			case *net.IPNet:
				ip = v.IP
			case *net.IPAddr:
				ip = v.IP
			}

			// 判断是否为 IPv4 地址
			if ip != nil && ip.To4() != nil {
                // 忽略链路本地地址 (169.254.x.x)
				if !ip.IsLinkLocalUnicast() && !ip.IsLoopback(){
                    ipv4Addresses = append(ipv4Addresses, ip.String())
                }
			}
		}
	}

	if len(ipv4Addresses) == 0 {
		return nil, fmt.Errorf("未找到可用的 IPv4 地址")
	}
	
	return ipv4Addresses, nil
}



func RemoveDuplicateElement [T comparable] (x []T, y []T) []T {
	z := append(x, y...)
	result := []T{}
	unique := map[T]bool{}
	for _, v := range z {
		if !unique[v] {
			unique[v] = true
			result = append(result, v)
		}
	}
	return result
}


func SearchFile(selected_file []STANDARD_SEARCH) []string {
	AccessSuperPath := func(path string) bool {
		// 禁止使用 ".." 访问父级文件, 并且禁止使用绝对路径访问后端文件.
		if strings.Contains(path, "..") || filepath.IsAbs(path) {
			return false
		}
		return true
	}

	StandardSearch := func(input []STANDARD_SEARCH) []string {
		var output []string
		for _, file := range input {
			if !AccessSuperPath(file.Path) {
				// 禁止越界重命名文件.
				continue
			}
			info, err := os.Stat(filepath.Join(*SHARE_DIR, file.Path))
			if err != nil {
				continue
			}
			if info.IsDir() {
				if runtime.GOOS == "linux" || runtime.GOOS == "darwin" {
					// 针对 Linux 和 macOS 进行 C 语言层面的搜索加速.
					res := C.StandardSearch(C.CString(filepath.Join(*SHARE_DIR, file.Path)), C.CString(file.Target))
					for i := 0; i < int(res.count); i++ {
						ptr := unsafe.Pointer(uintptr(unsafe.Pointer(res.path)) + uintptr(i) * unsafe.Sizeof(uintptr(0)))
						output = append(output, C.GoString(*((**C.char)(ptr))))
					}
					C.FreeStructMemory(res)
				}  else {
					/* 注意:
						1. 如果你的操作系统是 Windows, 也可以使用 C 语言加速搜索, 但由于 char* 不等价 wchar_t* 中文字符集, 所以在 Windows 下搜索中文会乱码, 但英文(ASCII 码)是完全没问题的.

						2. 我在大量测试后, 发现 C 语言层面搜索速度比 Golang 快 2 ~ 4 倍.

					-----------------------------------------------------------------------------------------------------
					res := C.StandardSearch(C.CString(filepath.Join(*SHARE_DIR, file.Path)), C.CString(file.Target))
					for i := 0; i < int(res.count); i++ {
						ptr := unsafe.Pointer(uintptr(unsafe.Pointer(res.path)) + uintptr(i) * unsafe.Sizeof(uintptr(0)))
						output = append(output, C.GoString(*((**C.char)(ptr))))
					}
					C.FreeStructMemory(res)
					-----------------------------------------------------------------------------------------------------
					*/
					filepath.Walk(filepath.Join(*SHARE_DIR, file.Path), func(path string, info os.FileInfo, err error) error {
						if err != nil {
							return err
						}
						if (strings.Contains(filepath.Base(path), file.Target)) {
							output = append(output, path)
						}
						return nil
					})
				}
			} else {
				// 如果是搜索目录的文件, 直接调用 Golang 函数搜.
				if (strings.Contains(info.Name(), file.Target)) {
					output = append(output, filepath.Join(*SHARE_DIR, file.Path))
				}
			}
		}
		return output
	}

	KeywordSearchAlgorithm := func(pattern []string, query []string) int {
		var ans int = 0
		for _, i := range query {
			for _, j := range pattern {
				if i == j {
					ans++
					break
				}
			}
		}
		return ans
	}

	KeywordSearch := func(input []STANDARD_SEARCH) []string {
		var output []string

		JIEBA_DICT_LOAD_ONCE.Do(func() {
			// 第一次调用 KeywordSearch 关键词搜索后, 加载数据到内存, 以后再次调用不需要重新加载.
			JIEBA_DICT = jiebago.NewJieBaGo(filepath.Join(FROZEN_DIR, "dictionary"))
		})

		array := map[string]int{}
		for _, file := range input {
			if !AccessSuperPath(file.Path) {
				// 禁止越界重命名文件.
				continue
			}
			info, err := os.Stat(filepath.Join(*SHARE_DIR, file.Path))
			if err != nil {
				continue
			}
			if info.IsDir() {
				filepath.Walk(filepath.Join(*SHARE_DIR, file.Path), func(path string, info os.FileInfo, err error) error {
					if err != nil {
						return err
					}
					ans := KeywordSearchAlgorithm(
						strings.Split(strings.Join(JIEBA_DICT.Cut(CleanIllegalCharacter(filepath.Base(path))), " "), " "),
						strings.Split(strings.Join(JIEBA_DICT.Cut(CleanIllegalCharacter(file.Target)), " "), " "),
					)
					if ans > 0 {
						array[path] = ans
					}
					return nil
				})
			} else {
				ans := KeywordSearchAlgorithm(
					strings.Split(strings.Join(JIEBA_DICT.Cut(CleanIllegalCharacter(filepath.Base(file.Path))), " "), " "),
					strings.Split(strings.Join(JIEBA_DICT.Cut(CleanIllegalCharacter(file.Target)), " "), " "),
				)
				if ans > 0 {
					array[file.Path] = ans
				}
			}
		}

		output = append(output, SortDict(array)...) 

		return output
	}

	if selected_file[0].StandardSearchStatus && !selected_file[0].KeywordSearchStatus {
		return StandardSearch(selected_file)
	} else if !selected_file[0].StandardSearchStatus && selected_file[0].KeywordSearchStatus {
		_, err := os.Stat(filepath.Join(FROZEN_DIR, "dictionary"))
		if err != nil {
			return []string{fmt.Sprintf("【错误】关键词搜索依赖的 \"dictionary\" 文件夹缺失, 点击更多 -- 关于 API -- GitHub 官网, 下载 \"dictionary.zip\" 压缩包, 解压成 \"dictionary\" 目录后放置到 %s 程序所在文件夹, 即可激活关键词搜索.", os.Args[0])}
		}
		return KeywordSearch(selected_file)
	} else if selected_file[0].StandardSearchStatus && selected_file[0].KeywordSearchStatus {
		_, err := os.Stat(filepath.Join(FROZEN_DIR, "dictionary"))
		if err != nil {
			return []string{fmt.Sprintf("【错误】关键词搜索依赖的 \"dictionary\" 文件夹缺失, 点击更多 -- 关于 API -- GitHub 官网, 下载 \"dictionary.zip\" 压缩包, 解压成 \"dictionary\" 目录后放置到 %s 程序所在文件夹, 即可激活关键词搜索.", os.Args[0])}
		}
		return RemoveDuplicateElement(StandardSearch(selected_file), KeywordSearch(selected_file))
	} else {
		return []string{"请至少选择一种搜索算法."}
	}
}