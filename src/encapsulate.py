from PyInstaller.__main__ import run
import platform

if __name__ == '__main__':
    if platform.system() == "Windows":
        opts = ['main.py',
                '-n Server',
                '-F',
                '--icon=./resources/static/logo/favicon.ico',
                '-y',
                '--clean',
                '--workpath=build',
                '--add-data=resources/templates;resources/templates',
                '--add-data=resources/static;resources/static',
                '--distpath=build',
                '--specpath=./'
                ]
        run(opts)
    elif platform.system() == "Linux":
        opts = ['main.py',
                '-n Server',
                '-F',
                '--clean',
                '--add-data=resources/templates:resources/templates',
                '--add-data=resources/static:resources/static'
                ]
        run(opts)
    else:
        print(platform.system())