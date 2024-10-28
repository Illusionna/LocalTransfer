import os
import sys
import time
import random
import platform
import functools
import webbrowser
import subprocess
from datetime import datetime
from urllib.parse import urlparse
from utils.tool import Launcher, Parse, Change, Generate


def FrozenAppDirectory() -> str:
    """冻结程序 `__name__ == '__main__'` 所在目录，即程序所在的文件夹位置。
    
    .. Custom-Function-Type:: 特殊函数
    
    Usage:
    
        >>> print(FrozenAppDirectory())
        
    .. versionadded:: v2
        用于 pyinstaller 封装程序，封装后的二进制程序能够找到自身所在的目录，并在所在目录构建资源依赖。必须在代码入口 `main.py` 使用该函数。

    Returns:
        str: 冻结路径
    """
    if hasattr(sys, 'frozen'):
        return os.path.normpath(os.path.dirname(sys.executable))
    return os.path.normpath(os.path.dirname(__file__))


frozen_dir = FrozenAppDirectory()

sys.path.insert(0, os.path.join(frozen_dir, 'utils', 'site-packages'))

from werkzeug.datastructures import FileStorage
from flask import Flask, request, render_template, jsonify, send_file


def cls() -> None:
    os.system('')
    try:
        os.system(
            {'Windows': 'cls', 'Linux': 'clear', 'Darwin': 'clear'}[platform.system()]
        )
    except:
        print('\033[H\033[J', end='')


args = Launcher.Launch(frozen_dir, os.path.join(frozen_dir, 'resources', 'static', 'atom.ico'))

app = Flask(
    import_name = 'Local Transfer',
    static_folder = os.path.join(frozen_dir, 'resources', 'static'),
    template_folder = os.path.join(frozen_dir, 'resources', 'templates')
)
app.config['MAX_CONTENT_LENGTH'] = args.MAX_SIZE


@functools.lru_cache(maxsize = args.MAX_LRU_CACHE)
def LRUGetDirInfo(dir: str) -> list:
    """获取目录所有文件的信息。

    Args:
        dir (str): 例如 `'A:/Illusionna/orzzz/net'` 目录。

    Returns:
        list:
        >>> [{'VarFilename': 'README', 'VarTime': '2024-08-16 16:17:42', 'VarFilesize': '1.11 KB', 'VarExtension': 'icon icon- icon-default'}]
    """
    return [
        {
            'VarFilename': element,
            'VarTime': datetime.fromtimestamp(os.path.getmtime(dir + os.sep + element)).strftime('%Y-%m-%d %H:%M:%S'),
            'VarFilesize': Change.BytesToCommon(os.path.getsize(dir + os.sep + element)) if os.path.getsize(dir + os.sep + element) else '-',
            'VarExtension': 'icon icon-directory' if os.path.isdir(dir + os.sep + element) else f'icon icon-{os.path.splitext(element)[1][1:]} icon-default'
        }
        for element in iter(os.listdir(dir))
    ]


def FuncSaveFile(file: FileStorage, url: str) -> None:
    """
    普通函数: 前端上传的文件保存到后端指定位置.
    """
    if args.UPLOAD_ROOT == args.SHARE_ROOT:
        file.save(
            os.path.join(
                args.UPLOAD_ROOT,
                url,
                Generate.RenamedFilePath(os.path.join(args.UPLOAD_ROOT, url), file.filename)
            )
        )
    else:
        file.save(
            os.path.join(
                args.UPLOAD_ROOT,
                Generate.RenamedFilePath(args.UPLOAD_ROOT, file.filename)
            )
        )
    # 清空 LRU 缓存.
    LRUGetDirInfo.cache_clear()


def FuncGetRequest(url: str) -> str:
    """
    普通函数: 前端 GET 请求, 后端做出响应.
    """
    # 连接共享路径与路由请求路径.
    path = os.path.join(args.SHARE_ROOT, url)
    # 若路径不存在, 返回 404 路由异常.
    if not os.path.exists(path):
        return render_template(
            random.choice(
                [
                    'ghost404.html', 'couple404.html',
                    'screen500.html', 'unicorn500.html'
                ]
            )
        ), 404
    # 若路径是文件, 则响应前端, 发送文件.
    if os.path.isfile(path):
        return send_file(path)
    # 否则是目录, 则显示文件夹内容.
    files = LRUGetDirInfo(path)
    directory = Generate.DirDirname(args.SHARE_ROOT, path)
    args.MAX_LRU_CACHE = args.MAX_LRU_CACHE - 1
    if args.MAX_LRU_CACHE == 0:
        # 先清空 LRU 缓存, 再重置最大缓存数为预设值.
        LRUGetDirInfo.cache_clear()
        args.MAX_LRU_CACHE = LRUGetDirInfo.cache_info()[2]
    return render_template(
        template_name_or_list = 'index.html',
        directory = directory,
        files = files
    )


@app.route('/', defaults = {'url': ''}, methods=['POST', 'GET'])
@app.route('/<path:url>', methods=['POST', 'GET'])
def FuncIndex(url: str) -> str:
    """
    装饰器函数: 渲染 index.html 首索引页面.
    """
    if request.method == 'POST':
        # 如果是 POST 上传请求, 则保存文件至 UPLOAD_ROOT 目录.
        try:
            list(map(lambda i: FuncSaveFile(i, url), iter(request.files.getlist('file'))))
        except:
            return render_template(
                random.choice(
                    [
                        'ghost404.html', 'couple404.html',
                        'screen500.html', 'unicorn500.html'
                    ]
                )
            ), 500
    # 否则返回 GET 请求.
    return FuncGetRequest(url)


@app.route('/POST-API', methods=['POST'])
def AppAPI() -> str:
    """Local Transfer API."""
    try:
        if len(request.files) == 0:
            return '[!] 文件夹为空, 检查文件夹是否存在!\n\n', 400
        for key in request.files.keys():
            if Generate.IsSubPath(
                path = os.path.join(args.SHARE_ROOT, request.remote_addr, key),
                dir = args.SHARE_ROOT
            ):
                os.makedirs(
                    name = os.path.join(args.SHARE_ROOT, request.remote_addr, key),
                    exist_ok = True
                )
                FuncSaveFile(request.files[key], os.path.join(request.remote_addr, key))
                return f"\033[32m[+] 200 OK {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime())}\033[0m\n{Change.SlashWay(f'http://{args.HOST}:{args.PORT}' + os.sep + os.path.normpath(os.path.join(request.remote_addr, key, request.files[key].filename)))}\n\n"
            else:
                return f'\033[31m[*] 保存到服务器的路径已经越界, 逆天, 想破我防?\033[0m\n  http(s)://{args.HOST}:{args.PORT}/{Change.SlashWay(os.path.join(request.remote_addr, key))}\n\n'
    except:
        return '[!] 上传失败!\n\n', 400


@app.route('/SearchOrExecute', methods=['POST'])
def search():
    cmd = request.json.get('query')
    if not cmd:
        # 空命令, 则刷新前端页面.
        LRUGetDirInfo.cache_clear()
        return jsonify({'refresh': False})
    # 如果调用程序存在于指令集且文件(夹)路径不越出 SHARE_ROOT 目录, 则允许调用服务器终端.
    if Parse.Command(cmd).issubset(args.PERMIT_COMMAND) & all(
        Generate.IsSubPath(
            path = os.path.normpath(
                os.path.normpath(
                    args.SHARE_ROOT + os.sep + urlparse(request.json.get('currentUrl')).path
                ) + os.sep + relative_path
            ),
            dir = args.SHARE_ROOT
        )
        for relative_path in iter(Parse.Path(cmd))
    ):
        subprocess.run(
            args = cmd,
            shell = True,
            cwd = os.path.normpath(
                args.SHARE_ROOT + os.sep + urlparse(request.json.get('currentUrl')).path
            )
        )
        # 等终端子进程执行 1 秒, 此后不过子进程是否执行完成或僵尸, 都响应前端 200 OK.
        time.sleep(1)
        # 清空 LRU 缓存.
        LRUGetDirInfo.cache_clear()
        return jsonify({'refresh': True})
    else:
        # 清空 LRU 缓存.
        LRUGetDirInfo.cache_clear()
        return jsonify({'refresh': False})


@app.errorhandler(500)
def Func500(error: Exception) -> tuple:
    """
    装饰器函数: 捕捉 500 内部服务器错误异常.
    """
    return render_template(random.choice(['screen500.html', 'unicorn500.html'])), 500



if __name__ == '__main__':
    cls()
    Parse.TerminalTips(args)
    try:
        webbrowser.open(f'http://{args.HOST}:{args.PORT}')
    except:
        '如果无法打开默认浏览器，则直接启动 Web Server 服务程序'
    app.run(
        host = args.HOST,
        port = args.PORT,
        debug = False
    )
