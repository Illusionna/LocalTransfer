<h1 align="center">
	<a href="https://illusionna.github.io/LocalTransfer.github.io" target="_blank">
	<img src="./images/logo.png" width="25%"/></a>
    <br>
    <a style="color: #008000;"><b>Local Transfer</b></a>
</h1>

<h4 align="center">一个<a style="color: red;">傻瓜式</a>操作的微型<a style="color: red;">文件传输</a>服务器 | <a href="https://www.orzzz.net" target="_blank">Illusionna</a></h4>

<p align="center">
    <a href="https://www.python.org" rel="nofollow" target="_blank">
        <img src="./images/python-3.7.0_=3.12.0-red.svg" alt="Python version" data-canonical-src="https://img.shields.io/badge/python-3.7.0<=3.12.0-red.svg" style="max-width:100%;">
    </a>
    <a href="https://www.gnu.org/licenses/gpl-3.0.en.html" rel="nofollow" target="_blank">
        <img src="./images/license-GPLv3-green.svg" alt="LISENCE" data-canonical-src="https://img.shields.io/badge/license-GPLv3-green.svg" style="max-width:100%;">
    </a>
</p>

<blockquote align="center">
    Local Transfer 提供开箱即用的 <strong>WebSever.exe</strong> 非代码工具
    <br>
    Local Transfer 致力于<strong>局域网</strong>文件传输但<strong>不限于此</strong>
    <br>
    Local Transfer 最大的特点：<strong>便捷</strong>、<strong>跨设备</strong>
</blockquote>

<p align="center">
    <a href="#简介">简介</a>
    |
    <a href="https://github.com/Illusionna/LocalTransfer" target="_blank">快速开始</a>
</p>

------

## 0. 目录

1. Star History
2. 示例截图
3. 介绍
4. 环境配置
5. 如何使用？
	- WebSever.exe
	- Code
6. 内网穿透
7. 源码结构树
8. 版本
9. 开源致谢
10. 同步

------


## 1. Star History

[![Star History Chart](https://api.star-history.com/svg?repos=Illusionna/LocalTransfer&type=Date)](https://star-history.com/#Illusionna/LocalTransfer&Date)

## 2. 示例截图

`iPad 设备`和启动服务器的`电脑`连接在同一个 WiFi 热点下，在 iPad 浏览器输入服务网址（类似 https://172.168.10.9:8080）或扫描二维码（Edge 浏览器右击选择创建页面二维码）即可进入共享文件夹目录。

![Upload Demonstration](./images/demo.png)

## 3. 介绍

“哥们，快把最新的游戏安装包发我一份，好哥哥，顺便把这周作业也发我。”

“兄弟，QQ 显示安装包过大，传送失败，乐，作业说有敏感词汇，也发不出去。”

“哥们你用 U 盘。”

“去哪借？”

“你......🙂”

你是否经常跨设备互传文件？你是否遇到过文件太大传输失败？

`Local Transfer` 是一个开源免费的微型文件传输服务器工具，支持对服务器的一定操作，它具备便携、中心化以及跨平台特点，适合局域网内**`快速`**共享文件。

## 4. 环境配置

> 若不想配置代码运行环境依赖，可以直接使用封装好的 [`WebSever.exe`](https://github.com/Illusionna/LocalTransfer/releases) 文件，双击程序或者终端执行。

<details>
<summary><b>4.1. WebSever.exe</b></summary>

<p align="center">
    <a href="https://www.microsoft.com" rel="nofollow" target="_blank">
        <img src="./images/Windows-x64-brightgreen.svg" alt="Windows version" data-canonical-src="https://img.shields.io/badge/Windows-x64-brightgreen.svg" style="max-width:100%;">
    </a>
</p>
二进制可执行程序需要在 Windows 环境下运行，建议 10 以及 11 版本，若在 Linux 操作系统下，可以使用 wine 工具，但建议使用 Code 源码运行。

</details>

<details>
<summary><b>4.2. Code</b></summary>

<p align="center">
    <a href="https://unix.org" rel="nofollow" target="_blank">
        <img src="./images/OS.svg" alt="OS version" data-canonical-src="https://img.shields.io/badge/Windows,%20Linux,%20MacOS-x64,%20M-brightgreen.svg" style="max-width:100%;">
    </a>
    <a href="https://www.python.org" rel="nofollow" target="_blank">
        <img src="./images/python-3.7.0_=3.12.0-red.svg" alt="Python version" data-canonical-src="https://img.shields.io/badge/python-3.7.0<=3.12.0-red.svg" style="max-width:100%;">
    </a>
    <a href="https://flask.palletsprojects.com" rel="nofollow" target="_blank">
        <img src="./images/flask-skyblue.svg" alt="flask version" data-canonical-src="https://img.shields.io/badge/flask-2.2.5,%203.0.2,%20latest-skyblue.svg" style="max-width:100%;">
    </a>
</p>
源码执行需要 Python 环境以及 flask 库。

</details>

## 5. 如何使用？

一、确保不要被杀毒软件误杀哟 ~

二、确保网络防火墙允许 Local Transfer 接入同一个 WiFi 或热点下的局域网 : )

![Oops?](./images/error.gif)

### 5.1. `WebSever.exe`

- `双击`：下载好 `WebSever.exe` 后，放在你的软件文件夹里，`直接双击`运行程序，当然，你也可以在桌面上创建一个快捷方式。

- `终端`：对于高级选项功能操作，可在 Windows cmd `命令提示符`使用指令查看 help 文档。

    ```
    >>> WebSever.exe  --h
    ```

    - 查看工具版本以及其他信息
    
        ```
        >>> WebSever.exe  --v
        ```
        
    - 修改共享文件夹路径（若文件夹不存在，自动创建，`默认桌面`）
    
        ```
        >>> WebSever.exe  -share  A:/orzzz/net
        ```
    
    - 修改上传文件夹路径（若文件夹不存在，自动创建，`默认桌面`）
    
        ```
        >>> WebSever.exe  -upload  A:/Illusion/cache
        ```

    - 既修改 IPv4 又修改端口号
    
        ```
        >>> WebSever  -host  127.0.0.1  -port  12345
        ```


### 5.2. `Code`

```
>>> pip  install  flask
```

```
>>> python  main.py
```

## 6. 内网穿透

出门在外没带电脑，突然要紧急发送桌面的“project”项目文件夹给别人？

发现“paper.pdf”有很明显的错别字，需要远程接入电脑重新排版？

Local Transfer 是局域网文件传输工具，但同时支持互联网公网访问，仅需简单的内网穿透，即可远程连接。例如下载 [cpolar.exe](https://www.cpolar.com) 内网穿透工具，用 cpolar 映射到 WebSever 套接字，打开两个终端分别执行：

```
>>> WebSever.exe
```

```
>>> cpolar  http  192.xxx.xxx.xxx  8080
```

## 7. 源码结构树

<details>
<summary><b>展开</b></summary>

    |
    |--model(由于涉及到的表并不是很多,所以没必要将model分开,都放在一起)
    |       |--models.py(定义模型)
    |       |--query.py(扩展query)
    |       |--base.py(基础类定义的地方，这些基础类都是抽象对象，并不能被实例化)
    |       |--serialization.py(序列化类定义)
    |       |--error.py(异常类定义)
    |       |--tool.py(工具,比如分库分表后，需要查找库和表的工具函数)
    |       |--其他
    |
    |--tool(全局工具包)
    |      |--一些全局工具函数，可以放在此包里，比如发生邮件，发送短信的功能函数，等等
    |
    |
    |
    |--auth(个人中心,这就涉及到用户登录，等等一些功能,都放在这个包里)
    |
    |
    |
    |--templates(模板及静态文件存放的地方)
    |
    |
    |
    |
    |--API(对外接口)
    |     |--API设计标准:借助Flask-RESTful设计RESTfulAPI,
    |
    |
    |
    |
    |
    |--统计分析(图形化)
    |        |--统计用户的信息(来源信息,自己渠道用户活跃数等等)
    |        |--统计业务情况(细分到各个供应商，各个渠道商，各个国家地区等等,比如订单量，走势,销售额等等)
    |        |--统计搜索情况(搜索次数最多等等信息)
    |        |--统计分析的界面是通过后台来展示的
    |
    |
    |
    |--后台管理
             |--基本的查看修改功能　　　

</details>

## 8. 版本

```
>>> WebServer  --v
```

> [Releases · Illusionna/LocalTransfer (github.com)](https://github.com/Illusionna/LocalTransfer/releases)

## 9. 开源致谢

> https://flask.palletsprojects.com
>
> https://github.com/tapio/live-server
>
> https://flask-autoindex.readthedocs.io

## X. 同步

> https://www.orzzz.net
>
> https://github.com/Illusionna/LocalTransfer
>
> https://Illusionna.github.io/LocalTransfer.github.io
