## 2.1.1. 双击 .exe 启动程序

确保你的电脑和其他设备（如手机、另一台电脑、平板、手表等）在同一个 WIFI 或热点下。

无论你是 Windows 10，还是 Windows 11 的操作系统，你都可以在任意目录下**双击** LocalTransfer 的可执行程序。程序会在 .exe 所在文件目录下自动创建 "`resources`" 文件夹，用于构建依赖资源包，并且尝试在桌面自动创建 "`DEFAULT_CACHE`" 的默认文件夹。点击启动即可打开传输服务。

为了方便，你可以将 Local Transfer 的 .exe 程序塞到你放软件的磁盘文件夹中，然后为程序创建一个**桌面快捷方式**。

<div style="text-align: center;">
    <img src="assets/img/GUI.png" style="zoom:100%;" alt="Oops?">
</div>

## 2.1.2. 使用终端启动程序

使用命令提示符或 Windows PowerShell 执行指令：

> [!NOTE]
> 查看帮助文档。
> ```PowerShell
> C:/Users/xxxxx/Downloads/Windows-LocalTransfer.exe  --help
> ```

如果你嫌弃绝对路径太长，可将 Local Transfer 程序加入到**环境变量**，这样就可以执行：

> [!WARNING|label:Important]
> 共享 C 盘，上传文件保存到 D 盘的 Folder 文件夹，且不启动 GUI 图形化界面。
> ```PowerShell
> Windows-LocalTransfer.exe  -share  C:\  -upload  D:\Folder  -nogui
> ```

你甚至可以修改可执行程序的名称，将 Windows-LocalTransfer.exe 重命名为 webserver.exe，然后执行：

> [!WARNING|label:Important]
> 共享 C 盘，上传文件保存到当前工作区所在目录，且上传文件不允许超过 120MB 大小。
> ```PowerShell
> webserver.exe  -share  C:\  -upload  .  -max  120MB
> ```

譬如，使用默认配置：

<div style="text-align: center;">
    <img src="assets/img/demo-eg.png" style="zoom:100%;" alt="Oops?">
</div>

## 2.1.3. 设备上传多张照片到电脑

同一个局域网下，在设备**浏览器地址栏**搜索 `http://HOST:PORT`，譬如上图的 `http://192.168.1.102:8888`，方便起见，也可以搜索套接字 `192.168.1.102:8888`。有些浏览器自带创建二维码功能，如果设备是手机，那么扫二维码会更加方便。

<div style="text-align: center;">
    <img src="assets/img/demo-browser.png" style="zoom:100%;" alt="Oops?">
</div>

选择多份文件后，点击上传即可。

<div style="text-align: center;">
    <img src="assets/img/demo-select.png" style="zoom:100%;" alt="Oops?">
    <img src="assets/img/demo-uploaded.png" style="zoom:100%;" alt="Oops?">
</div>

## 2.1.4. 设备下载文件到本地

譬如，我使用 iPad 的 safari 浏览器，对准文件，按住不放，然后选择下载即可。

<div style="text-align: center;">
    <img src="assets/img/demo-download.png" style="zoom:100%;" alt="Oops?">
</div>

## 2.1.5. 搜索与切换目录

譬如，我将一个 "`docs`" 目录作为子文件夹放到 "`DEFAULT_CACHE`" 文件夹中，先 `CTRL + C` 关闭进程，然后重启程序服务。

> [!Danger]
> 倘若你不想重启 Local Transfer 程序，可在高亮搜索框输入一个空格，再按下回车键，以清空 `LRU` 缓存，实现文件刷新。

鼠标悬停显示文件信息，点击 "`~`" 符号返回共享根目录。

<div style="text-align: center;">
    <img src="assets/img/demo-dir.png" style="zoom:100%;" alt="Oops?">
    <img src="assets/img/demo-switch.png" style="zoom:100%;" alt="Oops?">
</div>

## 2.1.6. 限制人使用前端上传文件

在启动 Local Transfer 服务后，我可以将文件直接放到共享文件夹或上传文件夹，但除此之外，我不想让其他任何人通过前端（浏览器）上传文件。那么可以限制他们上传文件的最大大小为 1 字节，然后我只需要装作不知道 ♬(ノ゜∇゜)ノ♩，嘿嘿嘿。

> ```PowerShell
> webserver.exe  -max  "1 B"
> ```