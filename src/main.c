/*
标准搜索功能: 用于搜索磁盘上的文件.

编译可执行文件(注意: 需要先取消 main 函数的注释):
    Windows:    gcc -O3 -s -flto main.c -o search.exe
    Unix:       gcc -O3 -s -flto main.c -o search
编译动态(共享)链接库:
    Windows:    gcc -O3 -s -flto -shared main.c -o search.dll
    Unix:       gcc -O3 -s -flto -shared main.c -o search.so
*/

# include <time.h>
# include <stdio.h>
# include <stdlib.h>
# include <string.h>

# ifdef _WIN32
    # include <windows.h>
# elif __linux__ || __APPLE__
    # include <dirent.h>
# else
    # include <windows.h>
    # include <dirent.h>
# endif


typedef struct {
    char **path;    // 搜索结果的字符串数组.
    int count;      // 字符串数组元素个数.
    double cost;    // 累计耗时.
} SearchResult;


# ifdef _WIN32
    const char *_WIN32_BaseName(const char *path) {
        const char *base = strrchr(path, '\\');
        if (base == NULL) {
            return path;
        }
        return base + 1;
    }
# elif __linux__ || __APPLE__
    const char *_UNIX_BaseName(const char *path) {
        const char *base = strrchr(path, '/');
        if (base == NULL) {
            return path;
        }
        return base + 1;
    }
# endif


// emmm, 类似 Python 的 os.path.basename() 和 Golang 的 filepath.Base() 函数.
const char *BaseName(const char *path) {
    # ifdef _WIN32
        return _WIN32_BaseName(path);
    # elif __linux__ || __APPLE__
        return _UNIX_BaseName(path);
    # endif
}


# ifdef _WIN32
    void _WIN32_WalkDir(SearchResult *res, const char *dir, const char *target) {
        char all_files[1024];
        snprintf(all_files, sizeof(all_files), "%s\\*", dir);
        WIN32_FIND_DATA find_file_data;
        HANDLE h_find = FindFirstFile(all_files, &find_file_data);
        if (h_find == INVALID_HANDLE_VALUE) return;
        do {
            const char *file_name = find_file_data.cFileName;
            if (strcmp(file_name, ".") != 0 && strcmp(file_name, "..") != 0) {
                char path[1024];
                snprintf(path, sizeof(path), "%s\\%s", dir, file_name);
                if (find_file_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
                    if (strstr(BaseName(path), target) != NULL) {
                        res->path = (char **)realloc(res->path, (res->count + 1) * sizeof (char *));
                        res->path[res->count] = (char *)malloc((strlen(path) + 1) * sizeof (char));
                        strcpy(res->path[(res->count)++], path);
                    }
                    _WIN32_WalkDir(res, path, target);
                } else {
                    if (strstr(file_name, target) != NULL) {
                        res->path = (char **)realloc(res->path, (res->count + 1) * sizeof (char *));
                        res->path[res->count] = (char *)malloc((strlen(path) + 1) * sizeof (char));
                        strcpy(res->path[(res->count)++], path);
                    }
                }
            }
        } while (FindNextFile(h_find, &find_file_data) != 0);
        FindClose(h_find);
    }
# elif __linux__ || __APPLE__
    void _UNIX_WalkDir(SearchResult *res, const char *dir, const char *target) {
        DIR *f = opendir(dir);
        struct dirent *entry;
        if (f == NULL) return;
        while ((entry = readdir(f)) != NULL) {
            if (strcmp(entry->d_name, ".") != 0 && strcmp(entry->d_name, "..") != 0) {
                char path[1024];
                snprintf(path, sizeof(path), "%s/%s", dir, entry->d_name);
                if (entry->d_type == DT_DIR) {
                    if (strstr(BaseName(path), target) != NULL) {
                        res->path = (char **)realloc(res->path, (res->count + 1) * sizeof (char *));
                        res->path[res->count] = (char *)malloc((strlen(path) + 1) * sizeof (char));
                        strcpy(res->path[(res->count)++], path);
                    }
                    _UNIX_WalkDir(res, path, target);
                } else {
                    if (strstr(entry->d_name, target) != NULL) {
                        res->path = (char **)realloc(res->path, (res->count + 1) * sizeof (char *));
                        res->path[res->count] = (char *)malloc((strlen(path) + 1) * sizeof (char));
                        strcpy(res->path[(res->count)++], path);
                    }
                }
            }
        }
        closedir(f);
    }
# endif


// 遍历目录文件夹, 进行目标搜索.
void WalkDir(SearchResult *res, const char *dir, const char *target) {
    # ifdef _WIN32
        _WIN32_WalkDir(res, dir, target);
    # elif __linux__ || __APPLE__
        _UNIX_WalkDir(res, dir, target);
    # endif
}


// 计时器, 计算搜索消耗的时间, 返回值秒.
double Timer(
    void (*func)(SearchResult *, const char *, const char *),
    SearchResult *res,
    const char *dir,
    const char *target
) {
    time_t start, end;
    time(&start);
    func(res, dir, target);
    time(&end);
    return difftime(end, start);
}


// 标准搜索, 其中 "dir" 表示目录路径, "target" 表示搜索目标.
SearchResult *StandardSearch(const char *dir, const char *target) {
    SearchResult *res = (SearchResult *)malloc(sizeof (SearchResult));
    res->path = NULL;
    res->count = 0;
    res->cost = Timer(WalkDir, res, dir, target);
    return res;
}


// 释放结构体开辟的内存空间.
void FreeStructMemory(SearchResult *res) {
    for (int i = 0; i < res->count; i++) {
        free((res->path)[i]);
    }
    free(res->path);
    free(res);
}



/* 测试 main 函数, 如果需要使用 cgo 编译, 注释下面的 main 函数, 否则会与 go 文件的 main 函数入口冲突.

int main(int argc, char *argv[], char *env[]) {
    time_t start, end;
    time(&start);

    SearchResult *res = StandardSearch(argv[1], argv[2]);

    for (int i = 0; i < res->count; i++) {
        printf("[%d] %s\n", i + 1, (res->path)[i]);
    }

    time(&end);

    printf("<-------- search cost time: %.2fs || print cost time: %.2fs -------->\n", res->cost, difftime(end, start) - res->cost);

    FreeStructMemory(res);

    return 0;
}

*/