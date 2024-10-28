import sys
import tkinter as tk
from tkinter import filedialog


def ScreenCenter(root: tk.Tk, width: int, height: int) -> None:
    """普通函数: 调整 GUI 窗口到屏幕中心."""
    screen_width = root.winfo_screenwidth()
    screen_height = root.winfo_screenheight()
    x = (screen_width - width) // 2
    y = (screen_height - height) // 2
    root.geometry(f'{width}x{height}+{x}+{y}')


def BrowseDirectory(entry: tk.Entry) -> None:
    """普通函数: 浏览本地文件夹路径."""
    entry.delete(0, tk.END)
    entry.insert(0, filedialog.askdirectory())


def WebServerConfigGUI(args: dict, icon_path: str) -> dict:
    """普通函数: 服务器配置 GUI 界面."""

    def __CloseWindow__() -> None:
        """嵌套函数: 关闭 GUI 窗口则终止进程."""
        root.destroy()
        sys.exit()

    def __ResetParameters__() -> None:
        """嵌套函数: 重置默认配置."""
        entry1.delete(0, tk.END)
        entry1.insert(0, args['SHARE_ROOT'])
        entry2.delete(0, tk.END)
        entry2.insert(0, args['UPLOAD_ROOT'])
        entry3.delete(0, tk.END)
        entry3.insert(0, args['HOST'])
        entry4.delete(0, tk.END)
        entry4.insert(0, args['PORT'])
        entry5.delete(0, tk.END)
        entry5.insert(0, args['MAX_SIZE'])
        entry6.delete(0, tk.END)
        entry6.insert(0, args['MAX_LRU_CACHE'])

    def __ActivateWebServer__() -> None:
        """嵌套函数: 激活 Local Transfer 程序."""
        args['SHARE_ROOT'] = entry1.get()
        args['UPLOAD_ROOT'] = entry2.get()
        args['HOST'] = entry3.get()
        args['PORT'] = entry4.get()
        args['MAX_SIZE'] = entry5.get()
        args['MAX_LRU_CACHE'] = entry6.get()
        root.destroy()

    root = tk.Tk()
    root.title(' Local Transfer Configurations')
    root.iconbitmap(icon_path)
    root.protocol('WM_DELETE_WINDOW', __CloseWindow__)

    label1 = tk.Label(root, text='共享文件夹目录', font=('Times New Roman', '15'))
    label1.place(x=20, y=50)
    entry1 = tk.Entry(root, width=57, font=('Times New Roman', '15'))
    entry1.insert(0, args['SHARE_ROOT'])
    entry1.place(x=175, y=50)
    button1 = tk.Button(root, text='选择文件夹', command=lambda: BrowseDirectory(entry1), font=('Times New Roman', '15'))
    button1.place(x=760, y=40)

    label2 = tk.Label(root, text='文件上传目录', font=('Times New Roman', '15'))
    label2.place(x=20, y=125)
    entry2 = tk.Entry(root, width=57, font=('Times New Roman', '15'))
    entry2.insert(0, args['UPLOAD_ROOT'])
    entry2.place(x=175, y=125)
    button2 = tk.Button(root, text='选择文件夹', command=lambda: BrowseDirectory(entry2), font=('Times New Roman', '15'))
    button2.place(x=760, y=115)

    label3 = tk.Label(root, text='主机号', font=('Times New Roman', '15'))
    label3.place(x=50, y=200)
    entry3 = tk.Entry(root, width=20, font=('Times New Roman', '15'))
    entry3.insert(0, args['HOST'])
    entry3.place(x=175, y=200)

    label4 = tk.Label(root, text='端口号', font=('Times New Roman', '15'))
    label4.place(x=470, y=200)
    entry4 = tk.Entry(root, width=10, font=('Times New Roman', '15'))
    entry4.insert(0, args['PORT'])
    entry4.place(x=600, y=200)

    label5 = tk.Label(root, text='限制文件大小', font=('Times New Roman', '15'))
    label5.place(x=20, y=275)
    entry5 = tk.Entry(root, width=20, font=('Times New Roman', '15'))
    entry5.insert(0, args['MAX_SIZE'])
    entry5.place(x=175, y=275)

    label6 = tk.Label(root, text='最大缓存个数', font=('Times New Roman', '15'))
    label6.place(x=450, y=275)
    entry6 = tk.Entry(root, width=10, font=('Times New Roman', '15'))
    entry6.insert(0, args['MAX_LRU_CACHE'])
    entry6.place(x=600, y=275)

    reset = tk.Button(root, text='重置', command=__ResetParameters__, font=('Times New Roman', '15', 'bold'), fg='#FF0000')
    reset.place(x=250, y=350)
    activate = tk.Button(root, text='启动', command=__ActivateWebServer__, font=('Times New Roman', '15', 'bold'), fg='#008000')
    activate.place(x=550, y=350)

    ScreenCenter(root, 900, 450)
    root.resizable(False, False)
    root.mainloop()
    return args


if __name__ == '__main__':
    DEFAULT_CONFIG = {
        'SHARE_ROOT': '/usr/bin',
        'UPLOAD_ROOT': r'C:\Windows\Fonts',
        'HOST': 'localhost',
        'PORT': '8888',
        'MAX_SIZE': '100MB',
        'MAX_LRU_CACHE': '120'
    }
    ans = WebServerConfigGUI(DEFAULT_CONFIG, './atom.ico')
    print(ans)