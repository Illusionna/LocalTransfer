import os
import re
import sys
import json
import random
import socket
import pathlib
import zipfile
import argparse
import platform
import utils.resources as src
import utils.exceptions as ex



class Generate:
    """生成类，包括众多生成方法。

    .. Custom-Class-Type:: 普通类

    .. versionadded:: v4 编写 `Generate` 类。
        - @staticmethod `Generate.FileSizeNumberUnit`
        - @staticmethod `Generate.RenamedFilePath`
        - @staticmethod `Generate.DesktopDir`
        - @staticmethod `Generate.Host`
        - @staticmethod `Generate.Port`
        - @staticmethod `Generate.DirDirname`
        - @staticmethod `Generate.IsSubPath`
        - @staticmethod `Generate.HexadecimalString`
    """

    @staticmethod
    def FileSizeNumberUnit(string: str) -> list:
        """将文件大小的数字和单位分离出来。

        .. Custom-Function-Type:: 静态函数

        Usage:
        
            >>> Generate.FileSizeNumberUnit('   12.7 MB  ')
            
        :param str string: 文件大小字符串。
        
        Returns:
            list:
            >>> [12.7, 'MB']
        """
        numbers = re.findall(r'[-+]?\d*\.\d+|\d+', string)
        if numbers:
            number = float(numbers[0])
        else:
            number = -1
        char = re.sub(r'[-+]?\d*\.\d+|\d+', '', string).strip().upper()
        return [number, char]


    @staticmethod
    def RenamedFilePath(dir: str, filename: str) -> str:
        """同一目录文件夹里，处理重名文件。

        .. Custom-Function-Type:: 静态函数

        Usage:
        
            >>> Generate.RenamedFilePath('./', 'README.md')
            
        :param str dir: 文件夹目录。
        :param str filename: 文件名。
        
        Returns:
            str:
            >>> 'README-2.md'
        """
        n = 2
        pure_name, extension = os.path.splitext(filename)
        while filename in iter(os.listdir(dir)):
            filename = pure_name + f'-{str(n)}' + extension
            n = -~n
        return filename


    @staticmethod
    def DesktopDir() -> str:
        """尝试获取操作系统桌面目录，获取不到返回工作区目录。

        .. Custom-Function-Type:: 静态函数

        Usage:
        
            >>> Generate.DesktopDir()

        Returns:
            str:
            >>> 'A:\\Illusionna\\Desktop'
        """
        OS = platform.system()
        if OS == 'Windows':
            # winreg 是 Windows 系统下的库.
            import winreg
            try:
                try:
                    shell = r'Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders'
                    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, shell) as w:
                        return winreg.QueryValueEx(w, 'Desktop')[0]
                except:
                    raise ex.RegistryException(message='注册表异常')
            except ex.RegistryException as e:
                print(f'\033[33m[*]: {e}\033[0m')
                return os.getcwd()
        elif OS == 'Darwin':
            return os.getcwd()
        elif OS == 'Linux':
            return os.getcwd()
        else:
            return os.getcwd()
    
    @staticmethod
    def Host() -> str:
        """使用 UDP 协议获取本地计算机 IPv4 主机地址。

        .. Custom-Function-Type:: 静态函数

        Usage:
        
            >>> Generate.Host()

        Returns:
            str:
            >>> '192.168.1.103'
        """
        try:
            try:
                s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                # 连接 Cloudflare DNS 服务器 80 号端口, 即默认 http 协议。
                s.connect(('1.1.1.1', 80))
                ipv4 = s.getsockname()[0]
            except:
                raise ex.SocketException(message='UDP socket 协议异常')
            finally:
                s.close()
            return ipv4
        except ex.SocketException as e:
            print(f'\033[33m[*]: {e}\033[0m')
            return 'localhost'


    @staticmethod
    def Port() -> int:
        """获取服务器主机未被占用的端口号，在 8888~65535 之间。

        .. Custom-Function-Type:: 静态函数

        Usage:
        
            >>> Generate.Port()

        Returns:
            int:
            >>> 8888
        """
        try_step = 5
        MIN_PORT = 8888
        MAX_PORT = 65535
        HOST = Generate.Host()
        for idx in range(0, try_step, 1):
            current_port = MIN_PORT + idx
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                try:
                    s.connect((HOST, current_port))
                except ConnectionRefusedError:
                    return current_port
        retry_step = 12
        tried_ports = set()
        while True and (retry_step > 0):
            retry_step = ~-retry_step
            current_port = random.randint(MIN_PORT + try_step, MAX_PORT)
            if current_port not in tried_ports:
                tried_ports.add(current_port)
                with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                    try:
                        s.connect((HOST, current_port))
                    except ConnectionRefusedError:
                        return current_port
        return 80
    
    
    @staticmethod
    def DirDirname(root: str, dir: str) -> list:
        """获取所有相对目录和目录名称。

        .. Custom-Function-Type:: 静态函数

        Usage:
        
            >>> Generate.DirDirname('A:/Illusionna', 'A:/Illusionna/orzzz/net/index')
            
        :param str root: 根目录。
        :param str dir: 根目录下的子目录。

        Returns:
            list:
            >>> [('orzzz', 'orzzz'), ('orzzz/net', 'net'), ('orzzz/net/index', 'index')]
        """
        relative_dir = pathlib.Path(dir).relative_to(root)
        parts = list()
        while relative_dir != pathlib.Path('.'):
            parts.append(str(relative_dir))
            relative_dir = relative_dir.parent
        parts.reverse()
        return list(zip(iter(parts), iter(os.path.basename(path) for path in parts)))


    @staticmethod
    def IsSubPath(path: str, dir: str) -> bool:
        """判断是否为子路径。

        .. Custom-Function-Type:: 静态函数

        Usage:

            >>> Generate.IsSubPath('A:/Illusionna/Desktop/../secret/a.c', 'A:/Illusionna/Desktop')

        :param str path: 路径。
        :param str dir: 目录。

        Returns:
            bool:
            >>> False
        """
        try:
            path = os.path.abspath(path)
            dir = os.path.abspath(dir)
            if os.path.commonpath([path, dir]) == dir:
                return True
            else:
                return False
        except:
            return False


    @staticmethod
    def HexadecimalString(path: str) -> None:
        """生成十六进制字符串。

        .. Custom-Function-Type:: 静态函数

        Usage:

            >>> Generate.HexadecimalString('A:/Illusionna/Desktop/resources.zip')

        :param str path: 文件路径。
        """
        with open(path, mode='rb') as f:
            data = f.read()
        with open('./utils/resources.py', mode='w') as f:
            f.write(f"hexadecimal_data = '{data.hex()}'")



class Change:
    """变化类，包括各种各样转化、改变的方法。

    .. Custom-Class-Type:: 普通类

    .. versionadded:: v4 编写 `Change` 类。
        - @staticmethod `Change.BytesToCommon`
        - @staticmethod `Change.CommonToBytes`
        - @staticmethod `Change.SlashWay`
    """

    @staticmethod
    def BytesToCommon(byte_size: int) -> str:
        """将字节转化成通用的表达形式。

        .. Custom-Function-Type:: 静态函数

        Usage:
        
            >>> Change.BytesToCommon(1314520)
            
        :param int byte_size: 字节大小。
        
        Returns:
            str:
            >>> '1.25 MB'
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


    @staticmethod
    def CommonToBytes(L: list) -> int:
        """将通用表达式列表转化成字节数。

        .. Custom-Function-Type:: 静态函数

        Usage:
        
            >>> Change.CommonToBytes([12.7, 'GB'])

        :param list L: 通用表达式列表。

        Returns:
            int:
            >>> 12.7 * 1024 * 1024 * 1024
        """
        transform_table: dict = {
            'B': 1,
            'KB': 1 << 10,
            'MB': 1 << 20,
            'GB': 1 << 30,
            'TB': 1 << 40
        }
        return int(L[0] * transform_table[L[1]])


    @staticmethod
    def SlashWay(path: str, axis: bool = True) -> str:
        """将路径中的所有斜杆、反斜杠统一方向。

        .. Custom-Function-Type:: 静态函数

        Usage:

            >>> Change.SlashWay(r'A:\\Illusionna\\Desktop/orzzz/net')

        :param str path: 路径。
        :param bool = True axis: 左右方向。

        Returns:
            str:
            >>> 'A:/Illusionna/Desktop/orzzz/net'
        """
        if axis == True:
            return path.replace('\\', '/')
        else:
            return path.replace('/', '\\')



class Parse:
    """解析终端参数以及其他指令。

    .. Custom-Class-Type:: 普通类

    .. versionadded:: v4 编写 `Parse` 类。
        - @staticmethod `Parse.TerminalParams`
        - @staticmethod `Parse.TerminalTips`
        - @staticmethod `Parse.Command`
        - @staticmethod `Parse.Path`
    """
    
    @staticmethod
    def TerminalParams() -> argparse.Namespace:
        """获取终端实参。

        .. Custom-Function-Type:: 静态函数

        Usage:

            >>> args = Parse.TerminalParams()

        Returns:
            argparse.Namespace: 参数命名空间
        """
        parser = argparse.ArgumentParser(
            description = f'例如开启 "C:/Users/ZolioMarling" 文件夹共享服务且限制上传文件最大不超过 12 GB\n>>> {sys.argv[0]} -share C:/Users/ZolioMarling -max "12 GB" -upload "A:\\Illusionna\\orzzz net"\n自定义配置文件: "{os.path.normpath(os.path.dirname(sys.argv[0]) + os.sep + "resources" + os.sep + "commands.json")}" 增加更多的授权指令集',
            usage = f'{sys.argv[0]} [-share] [-upload] [...] [-lru]',
            formatter_class=argparse.RawTextHelpFormatter,
            add_help = True
        )
        parser.add_argument(
            '-host',
            dest = 'HOST',
            type = str,
            default = Generate.Host(),
            help = '主机 IP 地址'
        )
        parser.add_argument(
            '-port',
            dest = 'PORT',
            type = int,
            default = Generate.Port(),
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
            default = '42 GB',
            help = '限制上传文件的最大大小, 单位 B、KB、MB、GB、TB, 注意英文双引号'
        )
        parser.add_argument(
            '-nogui',
            dest = 'NO_GUI',
            action = 'store_true',
            help = '命令添加 -nogui 即可关闭图像界面'
        )
        parser.add_argument(
            '-v', '--v', '--version',
            action = 'version',
            version = 'Local Transfer 局域网传输助手\n%(prog)s 4.0\n版本: V4\n协议: GNU GPLv3\n作者: @Illusionna\n隶属: Jarvis Engineering Tool\n博客: https://www.orzzz.net\n工具: https://github.com/Illusionna/LocalTransfer'
        )
        return parser.parse_args()


    @staticmethod
    def TerminalTips(args: argparse.Namespace) -> None:
        """终端小贴士。

        .. Custom-Function-Type:: 静态函数

        Usage:

            >>> args = Parse.TerminalTips()

        :param argparse.Namespace args: 参数命名空间。
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
        print(f'| 1. 共享文件夹 【*】 : {args.SHARE_ROOT}')
        print(f'| 2. 上传文件夹 【*】 : {args.UPLOAD_ROOT}')
        print('| 3. 最多缓存数 【*】 :\t      {:<10}    |'.format(args.MAX_LRU_CACHE))
        print('| 4. 上传文件最大限制【*】    {:<10}    |'.format(Change.BytesToCommon(args.MAX_SIZE)))
        print('| 5. 网络套接字【*】 {:<22} |'.format(f'{args.HOST}:{args.PORT}'))
        print('+-------------------------------------------+')
        print(f'若更改配置, 在终端输入命令查看 help 文档')
        print(f'>>>\033[33m {sys.argv[0]} --h \033[0m\n')
        print(''.join(f'\033[38;5;{idx}m#' for idx in range(45, 95, 1)), end='\033[0m\n')
        print(f'浏览器地址栏输入：http://{args.HOST}:{args.PORT}')
        print(''.join(f'\033[38;5;{idx}m#' for idx in range(150, 200, 1)), end='\033[0m\n')


    @staticmethod
    def Command(cmd: str) -> set:
        """将管道命令进行解析，获取指令。

        .. Custom-Function-Type:: 静态函数

        Usage:

            >>> cmd = "copy a b | xelatex main.tex | echo '../abc' >> abc.md | zip -r zipflie.zip ../."
            >>> print(Parse.Command(cmd))
            >>> {'xelatex', 'copy', 'zip', 'echo'}

        :param str cmd: 管道指令。
        
        Returns:
            set: 指令集合
        """
        OS = platform.system()
        # Windows 操作系统大小写不敏感。
        if OS == 'Windows':
            try:
                return set(map(str.lower, [command.split()[0] for command in iter(cmd.split('|'))]))
            except:
                return set()
        # 其他操作系统大小写敏感。
        else:
            try:
                return set(map(str, [command.split()[0] for command in iter(cmd.split('|'))]))
            except:
                return set()


    @staticmethod
    def Path(cmd: str) -> set:
        """将管道命令进行解析，获取文件路径。

        .. Custom-Function-Type:: 静态函数

        Usage:

            >>> cmd = "copy a b | xelatex main.tex | echo '../abc' > abc.md | zip -r zipflie.zip ../."
            >>> print(Parse.Path(cmd))
            >>> {'zipflie.zip', 'main.tex', 'abc.md', '../.', 'b', "'../abc'", 'a'}

        :param str cmd: 管道指令。

        Returns:
            set: 被操作的文件路径集合
        """
        OS = platform.system()
        # Windows 操作系统大小写不敏感。
        if OS == 'Windows':
            try:
                commands = Parse.Command(cmd)
                return set(
                    [
                        item for item in cmd.replace('|', ' ').split()
                        if item.lower() not in commands and item not in ['>>', '>'] and not item.startswith('-')
                    ]
                )
            except:
                return set()
        # 其他操作系统大小写敏感。
        else:
            try:
                commands = Parse.Command(cmd)
                return set(
                    [
                        item for item in cmd.replace('|', ' ').split()
                        if item not in commands and item not in ['>>', '>'] and not item.startswith('-')
                    ]
                )
            except:
                return set()



class Build:
    """构建 `static` 静态资源、`templates` 模板资源文件，构建指令集环境依赖。

    .. Custom-Class-Type:: 普通类

    .. versionadded:: v4 编写 `Build` 类。
        - @staticmethod `Build.Resources`
        - @staticmethod `Build.Instructions`
        - @staticmethod `Build.Environments`
    """

    @staticmethod
    def Resources(frozen_dir: str) -> None:
        """构建资源文件。

        .. Custom-Function-Type:: 静态函数

        Usage:
        
            >>> Build.Resources('.')
            
        :param str frozen_dir: 程序冻结路径。
        """

        def __UnzipHexadecimal__(path: str, hex_data: str) -> None:
            """读取压缩后的十六进制字符串，并解压生产资源文件。

            Args:
                path (str): 十六进制字符串文件路径。
                hex_data (str): 十六进制字符串。
            """
            os.chdir(path)
            resources_zip_path = os.path.join(path, 'resources.zip')
            with open(resources_zip_path, mode='wb') as f:
                f.write(bytes.fromhex(hex_data))
            with zipfile.ZipFile(resources_zip_path, mode='r') as zf:
                zf.extractall()
            try:
                if not os.path.exists(resources_zip_path):
                    raise ex.RemoveFailException(message=f'"{resources_zip_path}" 文件无法删除')
                os.remove(resources_zip_path)
            except ex.RemoveFailException as e:
                print(f'\033[33m[*]: {e}\033[0m')

        if not os.path.exists(os.path.join(frozen_dir, 'resources')):
            __UnzipHexadecimal__(frozen_dir, src.hexadecimal_data)


    @staticmethod
    def Instructions(frozen_dir: str) -> dict:
        """构建指令集。

        .. Custom-Function-Type:: 静态函数

        Usage:

            >>> Build.Instructions('.')

        :param str frozen_dir: 程序冻结路径。

        Returns:
            dict:
            >>> {
                'built': ['rm', 'echo', 'mv', 'ping', 'mkdir', 'cp'],
                'extension': [{'zip': '/bin'}, {'unzip': '/Usr/bin'}]
            }
        """

        def __Unify__(data: dict) -> dict:
            """统一指令集大小写，默认全小写。

            Args:
                data (dict): 指令集字典。

            Returns:
                dict: 全小写的指令集字典。
            """
            for i in range(len(data['built'])):
                data['built'][i] = data['built'][i].lower()
            for item in data['extension']:
                for key in list(item.keys()):
                    item[key.lower()] = item.pop(key)
            return data

        default_instructions: dict = {
            'built': [
                'curl', 'wget', 'grep', 'git', 'rm', 'mkdir', 'type', 'cat', 'tree', 'dir', 'ls',
                'ping', 'ipconfig', 'ifconfig', 'copy', 'cp', 'echo', 'ren', 'move', 'mv'
            ],
            'extension': [
                {'HelloWorld': './resources/bin'}, {'zip': './resources/bin'},
                {'unzip': './resources/bin'}, {'GluttonousSnake': './resources/bin'}
            ]
        }
        cmds_dir = os.path.join(frozen_dir, 'resources', 'commands.json')
        # 如果 commands.json 存在。
        if os.path.exists(cmds_dir):
            # 先读取指令集数据。
            with open(cmds_dir, mode='r', encoding='utf-8') as f:
                data: dict = json.load(f)
            # 如果指令集字典损坏，重写默认指令集。
            if not {'built', 'extension'}.issubset(data.keys()):
                with open(cmds_dir, mode='w', encoding='utf-8') as f:
                    json.dump(default_instructions, f, indent=4)
                return __Unify__(default_instructions)
            # 否则返回读取到的指令集。
            return __Unify__(data)
        # 不存在则创建默认指令集并写到磁盘上。
        else:
            with open(cmds_dir, mode='w', encoding='utf-8') as f:
                json.dump(default_instructions, f, indent=4)
            return __Unify__(default_instructions)


    @staticmethod
    def Environments(frozen_dir: str, instructions: dict) -> None:
        """配置指令集环境依赖。

        .. Custom-Function-Type:: 静态函数

        Usage:

            >>> instructions: dict = {
                'built': ['rm', 'echo', 'mv', 'ping', 'mkdir', 'cp'],
                'extension': [{'zip': '/bin'}, {'unzip': '/Usr/bin'}]
            }
            >>> Build.Instructions('.', instructions)

        :param str frozen_dir: 程序冻结路径。
        :param dict instructions: 指令集字典。
        """
        ENVIRON_DIRS = list(
            os.path.normpath(path) if os.path.isabs(path) else os.path.normpath(os.path.join(frozen_dir, path)) for path in map(lambda x: next(iter(x.values())), instructions['extension'])
        )
        os.environ['PATH'] = ';'.join([os.environ['PATH']] + ENVIRON_DIRS)



class Launcher:
    """构建 `static` 静态资源、`templates` 模板资源文件，启动终端获取 `Local Transfer` 服务器的实参，默认激活 GUI 二次修改实参，配置指令集环境依赖。

    .. Custom-Class-Type:: 普通类

    .. versionadded:: v4 编写 `Launcher` 类。
        - @staticmethod `Launcher.Launch`
    """

    @staticmethod
    def Launch(frozen_dir: str, icon_path: str) -> argparse.Namespace:
        """启动发射器。

        .. Custom-Function-Type:: 静态函数
        
        Usage:
        
            >>> args = Launcher.Launch('.', './resources/atom.ico')
            
        :param str frozen_dir: 程序冻结路径。
        :param str icon_path: GUI 所需的图标路径。

        Returns:
            argparse.Namespace: 参数命名空间
        """

        def __NormalizePath__(args: argparse.Namespace) -> argparse.Namespace:
            """规范化路径。

            Args:
                args (argparse.Namespace): 参数命名空间。

            Returns:
                argparse.Namespace: 路径规范化后的参数命名空间。
            """
            args.SHARE_ROOT = os.path.normpath(args.SHARE_ROOT)
            args.UPLOAD_ROOT = os.path.normpath(args.UPLOAD_ROOT)
            return args

        Build.Resources(frozen_dir)

        instructions = Build.Instructions(frozen_dir)
        Build.Environments(frozen_dir, instructions)

        instructions = set(instructions['built']) | set(map(lambda x: next(iter(x)), instructions['extension']))
        PERMIT_COMMAND = instructions | {cmd + '.exe' for cmd in instructions} | {cmd + '.out' for cmd in instructions}

        args = Parse.TerminalParams()

        if args.SHARE_ROOT is None:
            args.SHARE_ROOT = os.path.join(Generate.DesktopDir(), 'DEFAULT_CACHE')
        if args.UPLOAD_ROOT is None:
            args.UPLOAD_ROOT = args.SHARE_ROOT

        args = __NormalizePath__(args)

        if args.NO_GUI == (platform.system() != 'Windows'):
            from utils.GUI import WebServerConfigGUI

            gui_args = WebServerConfigGUI(args.__dict__, icon_path)

            os.makedirs(gui_args['SHARE_ROOT'], exist_ok=True)
            os.makedirs(gui_args['UPLOAD_ROOT'], exist_ok=True)
            
            gui_args.update({'PERMIT_COMMAND': PERMIT_COMMAND})

            gui_args['PORT'] = int(gui_args['PORT'])
            gui_args['MAX_LRU_CACHE'] = int(gui_args['MAX_LRU_CACHE'])
            gui_args['MAX_SIZE'] = Change.CommonToBytes(Generate.FileSizeNumberUnit(gui_args['MAX_SIZE']))

            return __NormalizePath__(argparse.Namespace(**gui_args))
        else:
            args_dict = args.__dict__

            os.makedirs(args_dict['SHARE_ROOT'], exist_ok=True)
            os.makedirs(args_dict['UPLOAD_ROOT'], exist_ok=True)

            args_dict.update({'PERMIT_COMMAND': PERMIT_COMMAND})
            args_dict['MAX_SIZE'] = Change.CommonToBytes(Generate.FileSizeNumberUnit(args_dict['MAX_SIZE']))

            return __NormalizePath__(argparse.Namespace(**args_dict))