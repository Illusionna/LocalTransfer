'''
# System --> Windows & Python3.10.0
# File ----> config.py
# Author --> Illusionna
# Create --> 2024/05/09 22:06:49
'''
# -*- Encoding: UTF-8 -*-


import os
import sys
os.system('')
import random
import string
import platform
import argparse

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

def BytesTransform(byteSize:int) -> str:
    """把字节转化为大家通常认知的单位.

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

def SlashBackslash(url:str, axis:bool=True) -> str:
    """
    斜杆、反斜杠替换.
    """
    if axis == True:
        return url.replace('\\', '/')
    else:
        return url.replace('/', '\\')


class Config:
    """
    配置类.
    """
    def __init__(self, *args, **kwargs) -> None:
        self.__dict__.update(kwargs)


class Parms:
    """
    获取终端配置参数类.
    """

    @staticmethod
    def Get() -> argparse.Namespace:
        """
        从终端获取参数.
        """
        try:
            os.system('cls')
        except:
            print('\033[H\033[J', end='')
        parser = argparse.ArgumentParser(
            description = f'\033[033m配置示例\033[0m >>>\033[032m {sys.argv[0]} -u ./cache -s "C:\\Users\\XXX\\Sharing" -pwd 123456 \033[0m',
            usage = f'{sys.argv[0]} [-h (查看帮助)] [-s (共享目录)] [-u (上传目录)] [...]',
            add_help = True
        )
        parser.add_argument(
            '-u',
            dest = 'uploadDir',
            type = str,
            default = GetDesktopPath() + os.sep + 'cache',
            help = '上传文件去向文件夹, 示例:\033[032m -u "C:/Users/Uploads" \033[0m'
        )
        parser.add_argument(
            '-s',
            dest = 'shareDir',
            type = str,
            default = GetDesktopPath() + os.sep + 'cache',
            help = '共享文件夹, 示例:\033[032m -s C:\\Users\\XXX\\Share \033[0m'
        )
        parser.add_argument(
            '-pwd',
            dest = 'pwd',
            type = str,
            default = ''.join(random.choice(string.digits) for _ in range(4)),
            help = '删除文件需要的密钥, 示例:\033[032m -pwd abc123456 \033[0m'
        )
        parser.add_argument(
            '-maxsize',
            dest = 'maxsize',
            type = str,
            default = '360 * (1 << 20)',
            help = '限制上传最大文件 (单位字节), 示例:\033[032m -maxsize "3 * (1 << 20)" \033[0m'
        )
        parser.add_argument(
            '-namesize',
            dest = 'namesize',
            type = int,
            default = 60,
            help = '达到一定长度压缩文件名, 示例:\033[032m -namesize 24 \033[0m'
        )
        parser.add_argument(
            '-debug',
            dest = 'debug',
            type = bool,
            default = False,
            help = '程序调试, 示例:\033[032m -debug True \033[0m'
        )
        parser.add_argument(
            '-key',
            dest = 'key',
            type = str,
            default = 'e=2.718281828?',
            help = '信息加密数字签名密钥, 示例:\033[032m -key "pi=3.14" \033[0m'
        )
        parser.add_argument(
            '-protocol',
            dest = 'protocol',
            type = str,
            default = 'http',
            help = 'http 和 https 协议, 示例:\033[032m >>> openssl req -x509 -newkey rsa:2048 -keyout privkey.pem -out cert.pem -days 365 >>> -protocol https \033[0m'
        )
        return parser.parse_args()

    @staticmethod
    def Tips(args:argparse.Namespace) -> None:
        """
        终端内核启动贴士.
        """
        print('')
        print('\t     \033[033m【局\033[0m\033[031m域\033[0m\033[032m网\033[0m\033[033m传\033[0m\033[034m输\033[0m\033[035m助\033[0m\033[036m手\033[0m\033[033m】\033[0m')
        print('+-------------------------------------------+')
        print('| 【注意事项】                              |')
        print('| a. 确保在同一网段下, 如同一热点或 WIFI 等 |')
        print('| b. 涉及到路径问题, 建议用英文双引号       |')
        print('| c. 共享文件夹不易过大, 加载需要一定时间   |')
        print('| d. 配置信息中带 【*】 号的是重要字段      |')
        print('+-------------------------------------------+')
        print('+-------------------------------------------+')
        print('| 【初始化默认配置】                        |')
        print(f'| 1. 上传文件夹 【*】 : {SlashBackslash(args.uploadDir)}')
        print(f'| 2. 共享文件夹 【*】 : {SlashBackslash(args.shareDir)}')
        print(f"| 3. 授权密钥口令 【*】 :\t{args.pwd}")
        print('| 4. 允许上传文件最大限制:      {:<10}  |'.format(BytesTransform(eval(args.maxsize))))
        print('| 5. 文件名省略的最大长度:      {:<10}  |'.format(args.namesize))
        print('| 6. 调试:            {:<10}            |'.format('True' if args.debug else 'False'))
        print(f'| 7. 信息加密数字签名密钥:   {args.key}')
        print('| 8. TCP/IP 网络协议:\t\t{:<10}  |'.format(args.protocol))
        print('+-------------------------------------------+')
        print(f'若更改配置, 在终端输入命令查看文档')
        print(f'>>>\033[33m {sys.argv[0]} -h \033[0m')
        print('')