'''
# System --> Windows & Python3.10.0
# File ----> tool.py
# Author --> Illusionna
# Create --> 2024/05/09 22:06:05
'''
# -*- Encoding: UTF-8 -*-


import os
import sys
import socket
import platform
from werkzeug.utils import secure_filename


class WebTool:
    """
    网络工具类.
    """

    @staticmethod
    def ScanPort() -> int:
        """静态函数: 扫描端口号.

        Returns:
            int: 返回未被占用的端口.
        """
        MIN_PORT = 8000
        MAX_PORT = 65535
        while True:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                try:
                    s.connect((socket.gethostbyname(socket.gethostname()), MIN_PORT))
                    MIN_PORT = -~MIN_PORT
                    if MIN_PORT <= MAX_PORT:
                        continue
                    else:
                        print('\033[31m* 8000~65535 内所有端口号均被占用, 进程终止!\033[0m')
                        sys.exit()
                except ConnectionRefusedError:
                    return MIN_PORT


class FileTool:
    """
    文件工具类.
    """

    @staticmethod
    def BytesTransform(byteSize:int) -> str:
        """静态公有函数: 把字节转化为大家通常认知的单位.

        Args:
            byteSize (int): 传入字节的尺寸大小.

        Returns:
            str: 转化后的字符串.
        """
        transformTable = {
            'B': [1, (1 << 10) - 1],
            'KB': [(1 << 10), (1 << 20) - 1],
            'MB': [(1 << 20), (1 << 30) - 1],
            'GB': [(1 << 30), (1 << 40) - 1],
            'TB': [(1 << 40), (1 << 99) - 1]
        }
        for (key, value) in transformTable.items():
            if (value[0] <= byteSize <= value[1]):
                return f'{(byteSize / transformTable[key][0]):.2f} {key}'

    @staticmethod
    def SlashBackslash(url:str, axis:bool=True) -> str:
        """
        斜杆、反斜杠替换.
        """
        if axis == True:
            return url.replace('\\', '/')
        else:
            return url.replace('/', '\\')

    @staticmethod
    def RecursiveGetFiles(directory:str) -> list:
        """
        循环递归获取所有文件.
        """
        if os.path.exists(directory):
            L = []
            for (root, __, filenames) in os.walk(directory):
                for file in filenames:
                    filePath = os.path.join(root, file)
                    L.append(filePath)
            return L
        else:
            print('\033[31m* 无效路径\033[0m: 1. 路径不存在; 2. 路径分割符存在问题')
            input('按 Enter 键退出...')
            sys.exit()

    @staticmethod
    def Compress(path:str, maxLength:int) -> str:
        """
        文件名压缩.
        e.g.
        >>> string = "static/js/particle.js"
        >>> return -> "sta....cle.js"
        """
        path = secure_filename(path)
        if len(path) > maxLength:
            return path[:5] + '...' + path[path.rfind('.')-5:]
        return path

    @staticmethod
    def GetFiles(dir:str, maxLength:int) -> list:
        """
        获取目录所有文件.
        e.g.
        >>> [
            ['dir', 'name', 'size'],
            ['路径', '文件名', '大小']
        ]
        """
        if os.path.exists(dir):
            L = [
                [
                    FileTool.SlashBackslash(os.path.join(root, name).replace(dir, '')),
                    FileTool.BytesTransform(os.path.getsize(os.path.join(root, name))),
                    FileTool.Compress(os.path.join(root, name).replace(dir, ''), maxLength)
                ] for root, _, names in os.walk(dir) for name in names
            ]
            # 上面的列表推导式等价于下面的显式循环.
            # ---------------------------------------------------------------------
            # L = []
            # for (root, __, names) in os.walk(dir):
            #     for name in names:
            #         L.append(
            #             [
            #                 FileTool.SlashBackslash(
            #                     os.path.join(root, name).replace(dir, 'files')
            #                 ),
            #                 FileTool.BytesTransform(
            #                     os.path.getsize(os.path.join(root, name))
            #                 ),
            #                 FileTool.Compress(
            #                     secure_filename(os.path.join(root, name).replace(dir, ''))
            #                 )
            #             ]
            #         )
            # ---------------------------------------------------------------------
            return L
        else:
            print('\033[31m* 无效路径\033[0m: 1. 路径不存在; 2. 路径分割符存在问题')
            return []
        
    @staticmethod
    def GetDesktopPath() -> str:
        """
        获取桌 Windows 面路径, 非 Windows 返回工作路径.
        """
        if platform.system() == 'Windows':
            import winreg   # winreg 是 Windows 系统下的库.
            try:
                tmp = winreg.OpenKey(
                    key = winreg.HKEY_CURRENT_USER,
                    sub_key = r'Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders'
                )
                desktop = winreg.QueryValueEx(tmp, 'Desktop')[0]
                return desktop
            except:
                return os.getcwd()
        else:
            return os.getcwd()