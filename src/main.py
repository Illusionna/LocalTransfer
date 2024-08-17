'''
# System --> Windows & Python3.7.0
# File ----> main.py
# Author --> Illusionna
# Create --> 2024/08/17 14:19:38
'''
# -*- Encoding: UTF-8 -*-


import os
import sys
import time
import random
import pathlib
import functools
import subprocess
import webbrowser
from datetime import datetime
from urllib.parse import urlparse
sys.path.insert(0, './utils/site-packages')
# ---------------------------------------
from werkzeug.datastructures import FileStorage
from flask import Flask, render_template, send_file, request
from utils.parse import ParseCommand, ParseDirectory, ArgsParser
from utils.build import BuildDependency, BuildJson, BuildEnvironment
from utils.tool import JudgeSubPath, RenameSameFile, GetDesktopPath, BytesTransform


args = ArgsParser.GetTerminalParameters()
if args.SHARE_ROOT is None:
    args.SHARE_ROOT = GetDesktopPath() + os.sep + 'DEFAULT_CACHE'
    os.makedirs(args.SHARE_ROOT, exist_ok=True)
if args.UPLOAD_ROOT is None:
    args.UPLOAD_ROOT = args.SHARE_ROOT


def FrozenAppDir() -> str:
    r"""
    特殊函数: 冻结程序`所在路径`, 即程序所在的文件夹位置.
    >>> (PowerShell) cd
    >>> (PS) A:/Illusionna/Desktop/src
    >>> (PS) python ./FrozenAppDir.py
    >>> (PS) 'A:/Illusionna/Desktop/src'
    >>> (PS) cd ..
    >>> (PS) A:/Illusionna/Desktop
    >>> (PS) python ./src/FrozenAppDir.py
    >>> (PS) 'A:\Illusionna\Desktop\src'
    >>> ----------------------------------
    >>> (PS) conda activate venv
    >>> (venv) cd src
    >>> (venv) A:/Illusionna/Desktop/src
    >>> (venv) python ./FrozenAppDir.py
    >>> (venv) '.'
    >>> (venv) cd ..
    >>> (venv) A:/Illusionna/Desktop
    >>> (venv) cd ..
    >>> (venv) A:/Illusionna
    >>> (venv) python ./Desktop/src/FrozenAppDir.py
    >>> (venv) './Desktop/src'
    >>> (venv) python A:/Illusionna/Desktop/src/FrozenAppDir.py
    >>> (venv) 'A:/Illusionna/Desktop/src'
    >>> ----------------------------------
    >>> (venv) conda deactivate
    >>> (PS) cd
    >>> (PS) A:/Illusionna
    >>> (PS) A:/Illusionna/Desktop/src/FrozenAppDir.exe
    >>> (PS) 'A:/Illusionna/Desktop/src'
    >>> (PS) A:/Illusionna/Desktop/src/UnFrozenAppDir.exe
    >>> (PS) 'C:\Users\Illusionna\AppData\Local\Temp\_MEI177602'
    """
    if hasattr(sys, 'frozen'):
        return os.path.dirname(sys.executable)
    return os.path.dirname(__file__)


BuildDependency(FrozenAppDir())
JSON_DATE = BuildJson(FrozenAppDir())
TEMP = set(JSON_DATE['built']) | set(map(lambda x: next(iter(x)), JSON_DATE['extension']))
BuildEnvironment(JSON_DATE, FrozenAppDir())


class Config:
    """
    参数配置容器类.
    """
    # ----------------------------------------------------------------------
    HOST = args.HOST                                        # 主机.
    PORT = args.PORT                                        # 端口号.
    SHARE_ROOT = os.path.normpath(args.SHARE_ROOT)          # 共享文件夹目录.
    UPLOAD_ROOT = os.path.normpath(args.UPLOAD_ROOT)        # 上传文件夹目录.
    MAX_CACHE = args.MAX_LRU_CACHE                          # LRU 最大缓存数, 用于加速程序.
    MAX_CONTENT_LENGTH = eval(args.MAX_SIZE)                # 限制上传最大文件 12 GB.
    # 允许执行的指令集, 请使用小写字母.
    PERMIT_COMMAND = TEMP | {cmd + '.exe' for cmd in TEMP}
    # ----------------------------------------------------------------------
    SHOW_IMAGE = None
    UPLOAD_FILENAME = None
    UPLOAD_FILEDIR = None


@functools.lru_cache(maxsize = Config.MAX_CACHE)
def GetDirInfo(dir: str) -> list:
    """
    缓存函数: 列表推导式获取目录的文件信息.
    >>> GetDirInfo('A:/Illusionna/orzzz/net')
    >>> [
            {
                'VarFilename': '.vscode', 'VarTime': '2024-08-16 16:22:27',
                'VarFilesize': '-', 'VarExtension': 'icon icon-directory'
            },
            {
                'VarFilename': 'README', 'VarTime': '2024-08-16 16:17:42',
                'VarFilesize': '1.11 KB', 'VarExtension': 'icon icon- icon-default'
            },
            {
                'VarFilename': 'main.py', 'VarTime': '2024-08-16 18:01:46',
                'VarFilesize': '6.92 KB', 'VarExtension': 'icon icon-py icon-default'
            }
        ]
    """
    return [
        {
            'VarFilename': element,
            'VarTime': datetime.fromtimestamp(os.path.getmtime(dir + os.sep + element)).strftime('%Y-%m-%d %H:%M:%S'),
            'VarFilesize': BytesTransform(os.path.getsize(dir + os.sep + element)) if os.path.getsize(dir + os.sep + element) else '-',
            'VarExtension': 'icon icon-directory' if os.path.isdir(dir + os.sep + element) else f'icon icon-{os.path.splitext(element)[1][1:]} icon-default'
        }
        for element in iter(os.listdir(dir))
    ]


@functools.lru_cache(maxsize = Config.MAX_CACHE)
def SplitDirectory(root: str, dir: str) -> list:
    """
    缓存函数: 分割出路径与目录名.
    >>> root = 'A:/Illusionna'
    >>> dir = 'A:/Illusionna/orzzz/net/index'
    >>> SplitDirectory(root, dir)
    >>> [('orzzz', 'orzzz'), ('orzzz/net', 'net'), ('orzzz/net/index', 'index')]
    """
    relative_dir = pathlib.Path(dir).relative_to(root)
    parts = list()
    while relative_dir != pathlib.Path('.'):
        parts.append(str(relative_dir))
        relative_dir = relative_dir.parent
    parts.reverse()
    return list(zip(iter(parts), iter(os.path.basename(path) for path in parts)))


app = Flask(
    import_name = 'Local Transfer',
    static_folder = FrozenAppDir() + os.sep + 'resources' + os.sep + 'static',
    template_folder = FrozenAppDir() + os.sep + 'resources' + os.sep + 'templates'
)
app.config['MAX_CONTENT_LENGTH'] = Config.MAX_CONTENT_LENGTH


@app.route('/', defaults = {'url': ''}, methods=['POST', 'GET'])
@app.route('/<path:url>', methods=['POST', 'GET'])
def FuncIndex(url: str) -> str:
    """
    装饰器函数: 渲染 index.html 首索引页面.
    """
    Config.SHOW_IMAGE = False
    if request.method == 'POST':
        # 如果是 POST 上传请求, 则保存文件至 UPLOAD_ROOT 目录.
        try:
            FuncSaveFile(request.files['file'], url)
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


def FuncSaveFile(file: FileStorage, url: str) -> None:
    """
    普通函数: 前端上传的文件保存到后端指定位置.
    """
    if Config.UPLOAD_ROOT == Config.SHARE_ROOT:
        file.save(
            os.path.join(
                Config.UPLOAD_ROOT,
                url,
                RenameSameFile(Config.UPLOAD_ROOT + os.sep + url, file.filename)
            )
        )
    else:
        file.save(
            os.path.join(
                Config.UPLOAD_ROOT,
                RenameSameFile(Config.UPLOAD_ROOT, file.filename)
            )
        )
    Config.UPLOAD_FILENAME = file.filename
    Config.UPLOAD_FILEDIR = os.path.join(url, file.filename)
    Config.SHOW_IMAGE = True
    # 清空 LRU 缓存.
    GetDirInfo.cache_clear()
    SplitDirectory.cache_clear()


def FuncGetRequest(url: str) -> str:
    """
    普通函数: 前端 GET 请求, 后端做出响应.
    """
    # 连接共享路径与路由请求路径.
    path = os.path.join(Config.SHARE_ROOT, url)
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
    files = GetDirInfo(path)
    directory = SplitDirectory(Config.SHARE_ROOT, path)
    Config.MAX_CACHE = Config.MAX_CACHE - 1
    if Config.MAX_CACHE == 0:
        # 先清空 LRU 缓存, 再重置最大缓存数为预设值.
        GetDirInfo.cache_clear()
        SplitDirectory.cache_clear()
        Config.MAX_CACHE = GetDirInfo.cache_info()[2]
    return render_template(
        template_name_or_list = 'index.html',
        directory = directory,
        files = files,
        uploadfilename = Config.UPLOAD_FILENAME,
        uploadfiledir = Config.UPLOAD_FILEDIR,
        show = Config.SHOW_IMAGE
    )


@app.route('/execute', methods=['POST'])
def FuncExecute() -> tuple:
    """
    装饰器函数: 捕获前端输入框内容, 并启动 Windows CMD 执行.
    """
    # os.system(f'cd {dir} & {command}')
    cmd = request.form.get('myInput')
    if not cmd:
        # 空命令, 则刷新前端页面.
        GetDirInfo.cache_clear()
        SplitDirectory.cache_clear()
        return 'Forbidden', 401
    # 如果调用程序存在于指令集且文件(夹)路径不越出 SHARE_ROOT 目录, 则允许调用服务器终端.
    if ParseCommand(cmd).issubset(Config.PERMIT_COMMAND) & all(
        JudgeSubPath(
            path = os.path.normpath(
                os.path.normpath(
                    Config.SHARE_ROOT + os.sep + urlparse(request.form.get('currentUrl')).path
                ) + os.sep + relative_path
            ),
            dir = Config.SHARE_ROOT
        )
        for relative_path in iter(ParseDirectory(cmd))
    ):
        subprocess.run(
            args = f'start powershell.exe -Command "{cmd}"',
            shell = True,
            cwd = os.path.normpath(
                Config.SHARE_ROOT + os.sep + urlparse(request.form.get('currentUrl')).path
            )
        )
        # 等终端子进程执行 1 秒, 此后不过子进程是否执行完成或僵尸, 都响应前端 200 OK.
        time.sleep(1)
        # 清空 LRU 缓存.
        GetDirInfo.cache_clear()
        SplitDirectory.cache_clear()
        return 'OK', 200
    else:
        # 清空 LRU 缓存.
        GetDirInfo.cache_clear()
        SplitDirectory.cache_clear()
        return 'Forbidden', 401


@app.errorhandler(500)
def Func500(error: Exception) -> tuple:
    """
    装饰器函数: 捕捉 500 内部服务器错误异常.
    """
    return render_template(random.choice(['screen500.html', 'unicorn500.html'])), 500


if __name__ == '__main__':
    ArgsParser.Tips(args)
    try:
        webbrowser.open(f'http://{Config.HOST}:{Config.PORT}')
    except:
        pass
    app.run(
        host = Config.HOST,
        port = Config.PORT,
        debug = False
    )