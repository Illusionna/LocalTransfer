'''
# System --> Windows & Python3.7.0
# File ----> parse.py
# Author --> Illusionna
# Create --> 2024/08/16 16:12:59
'''
# -*- Encoding: UTF-8 -*-


import os
import sys
import socket
import argparse
from utils.tool import ScanPort, SlashBackslash, BytesTransform


def ParseCommand(cmd: str) -> set:
    """
    普通函数: 解析命令行指令集.
    >>> cmd = "copy a b | xelatex main.tex | echo '../abc' >> abc.md | zip -r zipflie.zip ../."
    >>> ParseCommand(cmd)
    >>> {'xelatex', 'copy', 'zip', 'echo'}
    """
    try:
        return set(map(str.lower, [command.split()[0] for command in iter(cmd.split('|'))]))
    except:
        return set()


def ParseDirectory(cmd: str) -> set:
    """
    普通函数: 解析路径集.
    >>> cmd = "copy a b | xelatex main.tex | echo '../abc' > abc.md | zip -r zipflie.zip ../."
    >>> ParseDirectory(cmd)
    >>> {'zipflie.zip', 'main.tex', 'abc.md', '../.', 'b', "'../abc'", 'a'}
    """
    try:
        commands = ParseCommand(cmd)
        return set(
            [
                item for item in cmd.replace('|', ' ').split()
                if item.lower() not in commands and item not in ['>>', '>'] and not item.startswith('-')
            ]
        )
    except:
        return set()



class ArgsParser:
    """
    程序参数解析器类.
    """
    @staticmethod
    def GetTerminalParameters() -> argparse.Namespace:
        """
        静态函数: 获取终端额外参数.
        """
        try:
            os.system('cls')
        except:
            print('\033[H\033[J', end='')
        os.system('')
        parser = argparse.ArgumentParser(
            description = f'例如开启 "C:/Users/ZolioMarling" 文件夹共享服务且限制上传文件最大不超过 360 MB\n>>> {sys.argv[0]} -share C:/Users/ZolioMarling -max "360 * (1 << 20)" -upload "A:/Illusionna/orzzz net"\n自定义配置文件: "{os.path.normpath(os.path.dirname(sys.argv[0]) + os.sep + "resources" + os.sep + "commands.json")}" 增加更多的授权指令集',
            usage = f'{sys.argv[0]} [-share] [-upload] [...] [-lru]',
            formatter_class=argparse.RawTextHelpFormatter,
            add_help = True
        )
        parser.add_argument(
            '-host',
            dest = 'HOST',
            type = str,
            default = socket.gethostbyname(socket.gethostname()),
            help = '主机 IP 地址'
        )
        parser.add_argument(
            '-port',
            dest = 'PORT',
            type = int,
            default = ScanPort(),
            help = '服务器端口号'
        )
        parser.add_argument(
            '-share',
            dest = 'SHARE_ROOT',
            type = str,
            default = None,
            help = '共享文件夹目录'
        )
        parser.add_argument(
            '-upload',
            dest = 'UPLOAD_ROOT',
            type = str,
            default = None,
            help = '上传文件夹目录'
        )
        parser.add_argument(
            '-lru',
            dest = 'MAX_LRU_CACHE',
            type = int,
            default = 120,
            help = 'LRU 缓存数, 默认 120 个, 增加缓存数程序速度大幅度提升, 内存消耗增加'
        )
        parser.add_argument(
            '-max',
            dest = 'MAX_SIZE',
            type = str,
            default = '12 * (1 << 30)',
            help = '限制上传文件的最大大小, 单位字节, 注意英文双引号'
        )
        parser.add_argument(
            '-v', '--v', '--version',
            action = 'version',
            version = 'Local Transfer 局域网传输助手\n%(prog)s 3.0\n版本: V3\n协议: GNU GPLv3\n作者: @Illusionna\n隶属: Jarvis Engineering Tool\n博客: https://www.orzzz.net\n工具: https://github.com/Illusionna/LocalTransfer'
        )
        return parser.parse_args()

    @staticmethod
    def Tips(args: argparse.Namespace) -> None:
        """
        静态函数: 终端内核启动贴士.
        """
        print('')
        print('\t     \033[033m【局\033[0m\033[031m域\033[0m\033[032m网\033[0m\033[033m传\033[0m\033[034m输\033[0m\033[035m助\033[0m\033[036m手\033[0m\033[033m】\033[0m')
        print('+-------------------------------------------+')
        print('| 【注意事项】                              |')
        print('| a. 确保在同一网段下, 如同一热点或 WIFI 等 |')
        print('| b. 涉及到路径问题, 建议用英文双引号       |')
        print('| c. 共享文件夹不易过大, 加载需要一定时间   |')
        print('+-------------------------------------------+')
        print('+-------------------------------------------+')
        print('| 【初始化默认配置】                        |')
        print(f'| 1. 共享文件夹 【*】 : {SlashBackslash(args.SHARE_ROOT)}')
        print(f'| 2. 上传文件夹 【*】 : {SlashBackslash(args.UPLOAD_ROOT)}')
        print('| 3. 最多缓存数 【*】 :\t      {:<10}    |'.format(args.MAX_LRU_CACHE))
        print('| 4. 上传文件最大限制【*】    {:<10}    |'.format(BytesTransform(eval(args.MAX_SIZE))))
        print('| 5. 网络套接字【*】 {:<22} |'.format(f'{args.HOST}:{args.PORT}'))
        print('+-------------------------------------------+')
        print(f'若更改配置, 在终端输入命令查看 help 文档')
        print(f'>>>\033[33m {sys.argv[0]} --h \033[0m')
        print('')