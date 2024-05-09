'''
# System --> Windows & Python3.10.0
# File ----> main.py
# Author --> Illusionna
# Create --> 2024/05/09 21:48:52
'''
# -*- Encoding: UTF-8 -*-


"""
Python 3.10.0 +
>>> pip install flask

secure_filename 对中文不支持, "./utils/tool.py" 第 14 行, 找到原文, 用这个 utf-8 编码的代替官方库里的 ASCII 编码.

def secure_filename(filename: str) -> str:
    filename = unicodedata.normalize("NFKD", filename)
    filename = filename.encode("utf-8", "ignore").decode("utf-8")
    for sep in os.sep, os.path.altsep:
        if sep:
            filename = filename.replace(sep, " ")
    # --------------------------------------------------------------------
    # filename = str(_filename_ascii_strip_re.sub("", "_".join(filename.split()))).strip(
    #     "._"
    # )
    # if (
    #     os.name == "nt"
    #     and filename
    #     and filename.split(".")[0].upper() in _windows_device_files
    # ):
    #     filename = f"_{filename}"
    # -------------------------------------------------------------------- 
    _filename_ascii_add_strip_re = re.compile(r'[^A-Za-z0-9_\u4E00-\u9FBF.-]')
    filename = str(_filename_ascii_add_strip_re.sub('', '_'.join(filename.split()))).strip('._')
    return filename
"""

import os
import ssl
import socket
import hashlib
import platform
import webbrowser
import urllib.parse
from utils.config import Config, Parms
from utils.tool import WebTool, FileTool
from flask import Flask, render_template, request, flash, redirect, url_for, Response, send_from_directory, jsonify

def cls() -> None:
    os.system('')
    try:
        os.system(
            {'Windows': 'cls', 'Linux': 'clear'}[platform.system()]
        )
    except:
        print('\033[H\033[J', end='')
cls()


class APP(Config):
    """
    Local Transfer 类.
    """

    app = Flask(import_name='Local Transfer')

    def __init__(self, *args, **kwargs) -> None:
        super().__init__(*args, **kwargs)
        APP.app.config['MAX_CONTENT_LENGTH'] = config.MAX_CONTENT_LENGTH
        APP.app.config['SECRET_KEY'] = config.SECRET_KEY

    def ActivateHTTP(self) -> None:
        """
        激活 Local Transfer, 使用 http 协议.
        """
        try:
            webbrowser.open(f'http://{config.host}:{config.port}')
        except:
            pass
        APP.localURL = f'http://{config.host}:{config.port}'
        APP.app.run(
            host = config.host,
            port = config.port,
            debug = config.debug
        )

    def ActivateHTTPS(self) -> None:
        """
        激活 Local Transfer, 使用 https 协议.
        使用 OpenSSL.exe 申请自建的证书.
        >>> openssl req -x509 -newkey rsa:2048 -keyout privkey.pem -out cert.pem -days 365
        把生成的证书剪切到程序所在的工作目录下.
        """
        context = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
        context.load_cert_chain('cert.pem', 'privkey.pem')
        try:
            webbrowser.open(f'https://{config.host}:{config.port}')
        except:
            pass
        APP.localURL = f'https://{config.host}:{config.port}'
        APP.app.run(
            host = config.host,
            port = config.port,
            debug = config.debug,
            ssl_context = context
        )

    @app.route('/', methods=['GET', 'POST'])
    def Index() -> str:
        """
        返回前端首索引页面.
        """
        os.makedirs(config.uploadDir, exist_ok=True)
        tables: list = FileTool.GetFiles(dir=config.shareDir, maxLength=config.fileNameMaxLength)
        if request.method == 'POST':
            # 首索引页面是 POST 上传文件请求.
            if 'file' not in request.files:
                flash('No file part')
                return redirect(request.url)
            f = request.files['file']
            if f.filename == '':
                # 上传的是空文件, 则 error= True 返回 alert 弹窗.
                return render_template(
                    template_name_or_list = 'index.html',
                    localURL = APP.localURL,
                    localSocket = f'{config.host}:{config.port}',
                    uploadDirectory = FileTool.SlashBackslash(
                        os.path.abspath(config.uploadDir)
                    ),
                    shareDirectory = FileTool.SlashBackslash(
                        os.path.abspath(config.shareDir)
                    ),
                    error = True,
                    tables = tables,
                    pwd = config.pwd
                )
            if f and True:
                # 成功上传文件, 则把前端文件保存到服务器本地磁盘.
                name = f.filename
                f.save(os.path.join(config.uploadDir, name))
                fileSize = FileTool.BytesTransform(os.path.getsize(os.path.join(config.uploadDir, name)))
                filePath = url_for('Upload', filename=name)
                if os.path.abspath(config.uploadDir) == os.path.abspath(config.shareDir):
                    tables.insert(0, [name, fileSize, FileTool.Compress(name, config.fileNameMaxLength)])
                return render_template(
                    template_name_or_list = 'index.html',
                    localURL = APP.localURL,
                    localSocket = f'{config.host}:{config.port}',
                    uploadDirectory = FileTool.SlashBackslash(
                        os.path.abspath(config.uploadDir)
                    ),
                    shareDirectory = FileTool.SlashBackslash(
                        os.path.abspath(config.shareDir)
                    ),
                    show = True,
                    fileName = name,
                    fileSize = fileSize,
                    filePath = filePath,
                    tables = tables,
                    pwd = config.pwd
                )
        # 首索引页面不是 POST 上传文件请求, 也就是 GET 请求.
        return render_template(
            template_name_or_list = 'index.html',
            localURL = APP.localURL,
            localSocket = f'{config.host}:{config.port}',
            uploadDirectory = FileTool.SlashBackslash(
                os.path.abspath(config.uploadDir)
            ),
            shareDirectory = FileTool.SlashBackslash(
                os.path.abspath(config.shareDir)
            ),
            tables = tables,
            pwd = config.pwd
        )

    @app.route('/upload/<filename>')
    def Upload(filename:str) -> Response:
        """
        上传的文件.
        """
        return send_from_directory(config.uploadDir, filename)
    
    @app.route('/files/<path:filename>')
    def Share(filename:str) -> Response:
        """
        共享文件.
        """
        return send_from_directory(config.shareDir, filename)

    @app.route('/flush')
    def Flush() -> str:
        """
        网页刷新.
        """
        return redirect('/')

    @app.errorhandler(413)
    def RequestEntityTooLarge(error) -> str:
        """
        上传文件超出配置的限制值, 文件过大.
        """
        return render_template(
            template_name_or_list = '413.html',
            maxSize = FileTool.BytesTransform(config.MAX_CONTENT_LENGTH)
        )
    
    @app.errorhandler(404)
    def RequestEntityTooLarge(error) -> str:
        """
        未找到.
        """
        return '没有此文件.'

    @app.route('/delete', methods=['POST'])
    def Delete() -> Response:
        """
        授权口令通过则删除文件.
        """
        fileName = request.form['file_name']
        dir = fileName[fileName.find('files'):].replace('files', config.shareDir)
        if os.path.exists(urllib.parse.unquote(dir)):
            os.remove(urllib.parse.unquote(dir))
        return jsonify({'message': '删除成功！'})


if __name__ == '__main__':
    args = Parms.Get()
    Parms.Tips(args)
    config = Config(
        MAX_CONTENT_LENGTH = eval(args.maxsize),    # 最大允许上传 1GB 文件.
        uploadDir = args.uploadDir,
        shareDir = args.shareDir,                   # 共享文件目录.
        pwd = hashlib.sha256(args.pwd.encode('utf-8')).hexdigest(),   # 授权口令.
        host = socket.gethostbyname(socket.gethostname()),
        port = WebTool.ScanPort(),
        debug = args.debug,                         # debug 模式.
        fileNameMaxLength = args.namesize,          # 文件名省略的最大长度.
        SECRET_KEY = args.key                       # 信息加密数字签名密钥.
    )
    obj = APP(config)
    if args.protocol.lower() == 'http'.lower():
        obj.ActivateHTTP()
    elif args.protocol.lower() == 'https'.lower():
        obj.ActivateHTTPS()
    else:
        print('\033[31m* 无效协议\033[0m: 既不是 http 也不是 https')