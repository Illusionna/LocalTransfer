'''
# System --> Windows & Python3.7.0
# File ----> encapsulate.py
# Author --> Illusionna
# Create --> 2024/08/16 16:14:41
'''
# -*- Encoding: UTF-8 -*-


import platform
from PyInstaller.__main__ import run


if __name__ == '__main__':
    if platform.system() == "Windows":
        opts = [
            'main.py',
            '-nWebServer',
            '-F',
            '--icon=./atom.ico',
            '-y',
            '--clean',
            '--workpath=build',
            '--add-data=resources/templates;resources/templates',
            '--add-data=resources/static;resources/static',
            '--distpath=dist',
            '--specpath=./'
        ]
        run(opts)
    elif platform.system() == "Linux":
        opts = [
            'main.py',
            '-nWebServer',
            '-F',
            '--clean',
            '--add-data=resources/templates:resources/templates',
            '--add-data=resources/static:resources/static'
        ]
        run(opts)
    else:
        print(platform.system())