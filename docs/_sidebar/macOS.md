参考“**2.2. 在 Windows 7 上运行**”或““**2.3. 在 Linux 上运行**””教程，下载 macOS-LocalTransfer.zip 发行版压缩包，或者下载 GitHub 源码压缩包（解压后进入 "`src`" 目录）。

> [!Danger]
> 源码运行依赖的 Python 解释器版本至少高于 3.7.0，在终端使用 python + [tab键] 查看 Mac 上有哪些自带的解释器，再查看版本。
> ```zsh
> pyth [再按一下 Tab 键]
> python3  --version
> 3.12.0
> ```

在终端（如 zsh）执行指令即可启动服务：

> ```zsh
> python3  main.py
> ```

如果你下载的 macOS-LocalTransfer.zip 发行版，解压后你会看到一个叫 "`WebServer.sh`" 的脚本。

<div style="text-align: center;">
    <img src="assets/img/demo-mac.png" style="zoom:100%;" alt="Oops?">
</div>

你可以通过**软链接**形式，将该脚本指定到另一个目录（建议另一个目录能被环境变量搜索到），譬如：

> ```zsh
> ln  -s  /Users/xxxxx/Desktop/macOS-LocalTransfer/WebServer.sh  /usr/local/bin/webserver
> ```

然后你就可以随时随地方便地启动程序：

> ```zsh
> webserver  -share  /Users/xxxxx/Desktop
> ```

<div style="text-align: center;">
    <img src="assets/img/demo-macOS.png" style="zoom:100%;" alt="Oops?">
</div>

如果存在权限问题，可以为源脚本和链接文件都授权可读、可写、可执行：

> ```zsh
> chmod  777  /Users/xxxxx/Desktop/macOS-LocalTransfer/WebServer.sh
> chmod  777  /usr/local/bin/webserver
> ```