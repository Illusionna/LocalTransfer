'''
# System --> Windows & Python3.7.0
# File ----> build.py
# Author --> Illusionna
# Create --> 2024/08/17 14:19:28
'''
# -*- Encoding: UTF-8 -*-


import os
import json
import utils.HEXADECIMAL_DATA
from utils.tool import HexadecimalUnzip


def BuildDependency(frozen_dir: str) -> None:
    """
    普通函数: 扫描 WebServer.exe 所在文件夹, 并据此构建静态资源依赖.
    """
    if not os.path.exists(frozen_dir + os.sep + 'resources'):
        HexadecimalUnzip(frozen_dir, utils.HEXADECIMAL_DATA.hexadecimal_data)


def BuildJson(frozen_dir: str) -> dict:
    """
    普通函数: 构建 "./resources/commands.json" 允许指令集.
    """
    JSON_DATA = {
        'built': [
            'curl', 'cmd', 'rm', 'rmdir', 'del', 'mkdir', 'type', 'cat', 'tree', 'dir', 'ls',
            'ping', 'ipconfig', 'copy', 'cp', 'echo', 'rename', 'ren', 'move', 'mv'
        ],
        'extension': [
            {'HelloWorld': './resources/bin'}, {'zip': './resources/bin'},
            {'unzip': './resources/bin'}, {'GluttonousSnake': './resources/bin'}
        ]
    }
    json_dir = frozen_dir + os.sep + 'resources' + os.sep + 'commands.json'
    if os.path.exists(json_dir):
        with open(json_dir, mode='r', encoding='utf-8') as f:
            data = json.load(f)
        if not {'built', 'extension'}.issubset(data.keys()):
            with open(json_dir, mode='w', encoding='utf-8') as f:
                json.dump(JSON_DATA, f, indent=4)
            return Unification(JSON_DATA)
        return Unification(data)
    else:
        with open(json_dir, mode='w', encoding='utf-8') as f:
            json.dump(JSON_DATA, f, indent=4)
        return Unification(JSON_DATA)


def BuildEnvironment(data: dict, frozen_dir: str) -> None:
    """
    普通函数: 构建指令集临时环境变量.
    """
    ENVIRON_DIRS = list(
        os.path.normpath(path) if os.path.isabs(path) else os.path.normpath(frozen_dir + os.sep + path)
        for path in map(lambda x: next(iter(x.values())), data['extension'])
    )
    os.environ['PATH'] = ';'.join([os.environ['PATH']] + ENVIRON_DIRS)


def Unification(data: dict) -> dict:
    """
    普通函数: 统一指令集大小写.
    """
    for i in range(len(data['built'])):
        data['built'][i] = data['built'][i].lower()
    for item in data['extension']:
        for key in list(item.keys()):
            item[key.lower()] = item.pop(key)
    return data