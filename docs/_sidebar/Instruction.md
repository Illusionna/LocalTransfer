## 3.1.1. 指令集的简单使用

高亮搜索框不仅支持搜索同一目录下的文件，而且还支持**高度自由化**的指令集。

> [!WARNING]
> 删除当前目录下的所有文件以及文件夹，谨慎使用！
> ```Bash
> rm  -r  *
> ```

<div style="text-align: center;">
    <img src="assets/img/demo-del-all.png" style="zoom:100%;" alt="Oops?">
</div>

> [!TIP]
> 写入一些文本。
> ```Bash
> echo  "随便写点东西吧~"  >>  demo.txt
> ```

<div style="text-align: center;">
    <img src="assets/img/demo-echo.png" style="zoom:100%;" alt="Oops?">
</div>

> [!TIP]
> 创建嵌套文件夹。
> ```Bash
> mkdir  ./first/second/third
> ```

<div style="text-align: center;">
    <img src="assets/img/demo-mkdir.png" style="zoom:100%;" alt="Oops?">
</div>

> [!WARNING|label:Important]
> 检测主机间网络连接状态，并将结果写入到上一级目录。
> ```Bash
> ping  orzzz.net  >>  ../result.txt
> ```

<div style="text-align: center;">
    <img src="assets/img/demo-ping1.png" style="zoom:100%;" alt="Oops?">
    <img src="assets/img/demo-ping2.png" style="zoom:100%;" alt="Oops?">
    <img src="assets/img/demo-ping3.png" style="zoom:100%;" alt="Oops?">
</div>

> [!NOTE]
> 压缩当前目录下所有文件。
> ```Bash
> zip  -r  *
> ```

> [!NOTE]
> 解压 "`macOS-LocalTransfer.zip`" 压缩包。
> ```Bash
> unzip  macOS-LocalTransfer.zip
> ```

## 3.1.2. 指令集路径越界

有时候，某些坏人总想做些坏事，例如我只将 "`C:/Users/Illusionna/Desktop`" 目录共享出去，上传目录和它相同，但坏人想在 "`C:/Users/Illusionna`" 文件夹中进行一些操作，细丝一想，这是一件很危险的事情。

> [!WARNING]
> 往共享文件夹的上一级目录写入文件。
> ```Bash
> echo  "假设这句话是一句很危险的话"  >>  ../demo2.txt
> ```

<div style="text-align: center;">
    <img src="assets/img/demo-danger.png" style="zoom:100%;" alt="Oops?">
</div>

## 3.1.3. 自定义指令集

在终端执行 help 帮助文档，你会发现有一个叫 "`commands.json`" 的自定义配置文件，找到该文件位置，然后使用记事本或者 VSCode 打开，注意保存格式，推荐使用 "`utf-8`" 编码。

> ```Bash
> webserver  --help
> ```

<div style="text-align: center;">
    <img src="assets/img/demo-custom.png" style="zoom:100%;" alt="Oops?">
</div>

这个 .json 文件有两类值，第一类是 "`built`" 默认值，例如，我想**禁用** "`rm`" 指令，那么我只需要**删除** "`commands.json`" 中的 "`rm`" 即可。另一类是 "`extension`" 扩展值，例如我的电脑有一个叫 "`pdflatex.exe`" 的指令，那么只需要增加一条键值对：

<div style="text-align: center;">
    <img src="assets/img/demo-pdflatex.png" style="zoom:100%;" alt="Oops?">
</div>

然后即可编译 main.tex 文件了。

> ```latex
> \documentclass{article}
>
> \begin{document}
>     Hello World!
> \end{document}
> ```

<div style="text-align: center;">
    <img src="assets/img/demo-tex.png" style="zoom:100%;" alt="Oops?">
    <img src="assets/img/demo-pdf.png" style="zoom:100%;" alt="Oops?">
</div>

再例如，使用 "`git`" 指令初始化当前目录为仓库。

> [!WARNING|label:Important]
> ```Bash
> git  init
> ```

<div style="text-align: center;">
    <img src="assets/img/demo-git.png" style="zoom:100%;" alt="Oops?">
</div>

自定义指令集提供强大且安全的功能操作，它相当于一个精简版的 ssh 远程连接，打开你的脑洞，将它的效果发挥到最大吧！

## 3.1.4. 清空 `LRU` 缓存

如果你仅仅开启 Local Transfer 服务，用于自己电脑、手机、平板之间互传文件，你可以把默认的 `120` 个缓存数调小点，这对你的电脑几乎不产生影响。然而，如果除了你自己使用服务外，你的舍友，你的班级，甚至你的学校都需要使用你电脑启动的 Local Transfer 服务，那性能开销就会很大。

因此 Local Transfer 采用 LRU 缓存机制，通俗来说，你的电脑内存要是很大，你可以将 `LRU` 参数调大一些，这有利于减少磁盘 I/O，加快前端页面内容显示。但是这也会有一个弊端，那就是前端不能及时同步应有的文件显示。譬如以下两点：

> [!Danger]
> 未通过浏览器前端上传文件夹，而是在后端直接把文件增加（或删除）于共享目录。

> [!Danger]
> 高亮搜索框执行指令后，本应生效，但发生时滞，导致前端浏览器似乎没有变化的迹象（实际上已经发生变化）。

> 参考 B 站教学视频 19 分 50 秒到 20 分 20 秒：https://www.bilibili.com/video/BV1MaDuY6EDJ

> [!TIP]
> 可以重启 Local Transfer 程序，也可以在高亮搜索框输入一个空格，再按下回车键，手动清空 `LRU` 缓存。

## 3.1.5. 减少或避免孤儿进程

在 "`commands.json`" 指令集文件中有一个 HelloWorld 的指令，指向 "`./bin/HelloWorld.exe`" 这个文件。

<div style="text-align: center;">
    <img src="assets/img/demo-HelloWorld.png" style="zoom:100%;" alt="Oops?">
</div>

如果你在 Windows 10 + 的电脑上启动 Local Transfer 服务，你可以通过高亮搜索框执行 "`HelloWorld`" 指令。它会启动子进程，在终端打印 C 语言的 Hello World，你会注意到，子进程最后需要按下回车键才能终止。

<div style="text-align: center;">
    <img src="assets/img/demo-orphan.png" style="zoom:100%;" alt="Oops?">
</div>

当前端使用者通过浏览器执行 "`HelloWorld`" 指令后，后端会开启子进程，但前端使用者无法直接在后端服务器的键盘上按下回车，因此后端会一直启动这个 "`./bin/HelloWorld.exe`" 程序，哪怕 Local Transfer 服务关闭结束了，这个 Hello World 子进程依然在等待标准输入回车键。

为此，如果将 Local Transfer 作为项目部署，而非仅个人使用，我强烈建议禁用 "`built`" 和 "`extension`" 中的所有指令集，以防萌新瞎搞，激活冗余的子进程，导致最后产生孤儿进程，占用服务器电脑的资源。

倘若你是个人私用，其实也是有解决之道的，你可以使用管道“`|`”命令符，将前者的输出作为后者的输入，就像水流经过管道一样，在你熟悉指令集后，你也许会遇到很多类似的情形，"`HelloWorld`" 只作为一个示例代表。

> [!NOTE]
> ```PowerShell
> echo  enter  |  HelloWorld
> ```

<div style="text-align: center;">
    <img src="assets/img/demo-pipe.png" style="zoom:100%;" alt="Oops?">
</div>