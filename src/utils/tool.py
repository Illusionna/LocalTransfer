'''
# System --> Windows & Python3.7.0
# File ----> tool.py
# Author --> Illusionna
# Create --> 2024/08/16 16:05:57
'''
# -*- Encoding: UTF-8 -*-


import os
import sys
import random
import socket
import inspect
import zipfile
import platform



def Add(**kwargs) -> None:
    """
    普通函数: 调试打印, 仅此处局部 import 库.
    >>> Add(kwargs='2.718281828')
    """
    os.system('')
    line = inspect.getframeinfo(sys._getframe(1))
    file = os.path.relpath(line.filename, os.getcwd())
    print('<S>---------------------------------------------------------------')
    print(f'\033[3{random.randint(1, 6)}m[+debug] "{file}", line {line.lineno}')
    for key, value in kwargs.items():
        print('')
        print(key, '=')
        print(value, end='\n')
    print('\033[0m', end='')
    print('---------------------------------------------------------------<E>')


def SlashBackslash(path: str, axis: bool = True) -> str:
    r"""
    普通函数: 斜杆、反斜杠替换.
    >>> SlashBackslash(r'A:\Illusionna\Desktop/orzzz/net')
    >>> 'A:/Illusionna/Desktop/orzzz/net'
    """
    if axis == True:
        return path.replace('\\', '/')
    else:
        return path.replace('/', '\\')


def GetDesktopPath() -> str:
    r"""
    普通函数: 获取桌 Windows 面路径, 非 Windows 返回工作路径.
    >>> GetDesktopPath()
    >>> 'A:\Illusionna\Desktop'
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


def BytesTransform(byte_size: int) -> str:
    """普通函数: 把字节转化为大家通常认知的单位.
        >>> BytesTransform(1314520)

        >>> '1.25 MB'

    Args:
        byte_size (int): 传入字节的尺寸大小.

    Returns:
        str: 转化后的字符串.
    """
    transform_table: dict = {
        'B': [1, (1 << 10) - 1],
        'KB': [(1 << 10), (1 << 20) - 1],
        'MB': [(1 << 20), (1 << 30) - 1],
        'GB': [(1 << 30), (1 << 40) - 1],
        'TB': [(1 << 40), (1 << 99) - 1]
    }
    for (key, value) in transform_table.items():
        if (value[0] <= byte_size <= value[1]):
            return f'{(byte_size / transform_table[key][0]):.2f} {key}'


def JudgeSubPath(path: str, dir: str) -> bool:
    r"""
    普通函数: 判断是否为子路径.
    >>> SHARE_ROOT = 'A:/Illusionna/Desktop/orzzz'
    >>> path = '../..\secret'
    >>> fullpath = os.path.normpath(SHARE_ROOT + os.sep + path)
    >>> 'A:\Illusionna\secret'
    >>> JudgeSubPath(fullpath, SHARE_ROOT)
    >>> False
    >>> -----------------------------------------------------------
    >>> path = './net/index.html'
    >>> fullpath = os.path.normpath(SHARE_ROOT + os.sep + path)
    >>> 'A:\Illusionna\Desktop\orzzz\net\index.html'
    >>> JudgeSubPath(fullpath, SHARE_ROOT)
    >>> True
    """
    try:
        return os.path.samefile(os.path.commonpath([path, dir]), dir)
    except:
        return False


def RenameSameFile(dir: str, filename: str) -> str:
    """
    普通函数: 同一目录下, 重命名同名文件.
    >>> ls
    >>> README.md  index.html
    >>> RenameSameFile('./', 'README.md')
    >>> 'README(2).md'
    """
    n = 2
    pure_name, extension = os.path.splitext(filename)
    while filename in iter(os.listdir(dir)):
        filename = pure_name + f'({str(n)})' + extension
        n = -~n
    return filename


def ScanPort() -> int:
    """
    普通函数: 从 8000 开始扫描到首次未被占用的端口号.
    >>> ScanPort()
    >>> 8000
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


def HexadecimalGenerate(path: str) -> None:
    """
    普通函数: 生成十六进制资源数据文件.
    >>> cat ./main.c
    >>> # include <stdio.h>
    >>> int main(int argc, char* argv[], char** env) {
    >>>     printf("Hello World!");
    >>>     return 0;
    >>> }
    >>> HexadecimalGenerate('./main.c')
    >>> hexadecimal = '2320696e636c756465203c737464696f2e683e0d0a0d0a696e74206d61696e28696e7420617267632c20636861722a20617267765b5d2c20636861722a2a20656e7629207b0d0a202020207072696e7466282248656c6c6f20576f726c642122293b0d0a2020202072657475726e20303b0d0a7d'
    """
    with open(path, mode='rb') as f:
        data = f.read()
    with open('./HEXADECIMAL_DATA.py', mode='w') as f:
        f.write(f"hexadecimal_data = '{data.hex()}'")


def HexadecimalUnzip(fronzen_path: str, hexadecimal_data: str) -> None:
    """
    普通函数: 根据 HEXADECIMAL_DATA.py 生成资源 resources.zip 压缩包, 然后解压完成删除 .zip 文件.
    >>> HexadecimalUnzip(FronzenAppDir(), HEXADECIMAL_DATA.hexadecimal_data)
    >>> ./resources.zip
    """
    if not os.path.exists(fronzen_path + os.sep + 'resources'):
        os.chdir(fronzen_path)
        resources_path = fronzen_path + os.sep + "resources.zip"
        with open(resources_path, mode='wb') as f:
            f.write(bytes.fromhex(hexadecimal_data))
        with zipfile.ZipFile(resources_path, mode='r') as zf:
            zf.extractall()
        try:
            os.remove(resources_path)
        except:
            pass