[Illusionna Website](https://www.orzzz.net ':include :type=iframe width=100% height=400px')

你也许已经访问过我的静态博客 [orzzz.net](https://www.orzzz.net)，虽然我的主页并没有采用 Local Transfer 部署，但如果你想用 Local Transfer 搭建一个自己的静态博客，这也是极其方便且绰绰有余的。你可以在 B 站教学视频的 31 分 10 秒到 32 分 10 秒找到示例。

> https://www.bilibili.com/video/BV1MaDuY6EDJ

接下来，我将重头开始，用 Local Transfer 搭建一个静态主页。

### 第一步：从 HTML 语言的 Hello World 开始

在桌面创建一个名叫 "`HomePage`" 的文件夹，然后用记事本写下面这么一句话，命名为 "`index.txt`"。

```txt
Hello World! 这是我的主页 ：）
```

<div style="text-align: center;">
    <img src="assets/img/HelloWorld.png" style="zoom:100%;" alt="Oops?">
</div>

将 "`index.txt`" 后缀重命名，修改为 "`index.html`" 后用浏览器打开。

<div style="text-align: center;">
    <img src="assets/img/HTML-HelloWorld.png" style="zoom:100%;" alt="Oops?">
</div>

### 第二步：在局域网内共享你的 Hello World

使用 Local Transfer 的 WebServer 服务，共享文件夹为 "`HomePage`"。

<div style="text-align: center;">
    <img src="assets/img/Server.png" style="zoom:100%;" alt="Oops?">
</div>

此时，局域网内的设备，可通过浏览器地址栏搜索 "`http://192.168.1.102:8890/index.html`" 访问到 Hello World。

<div style="text-align: center;">
    <img src="assets/img/iPhone.png" style="zoom:100%;" alt="Oops?">
</div>

### 第三步：把 Local Transfer 服务部署到互联网

你可以参考“**3.4. 公网（互联网）上怎么使用？**”的两种方案，这里以云服务器为例。

<div style="text-align: center;">
    <img src="assets/img/Huawei.png" style="zoom:100%;" alt="Oops?">
</div>

在华为云服务器的防火墙添加规则，开启我想用的端口，例如 "`8888`" 号。

<div style="text-align: center;">
    <img src="assets/img/Firewall.png" style="zoom:100%;" alt="Oops?">
    <img src="assets/img/8888.png" style="zoom:100%;" alt="Oops?">
</div>

在云服务器下载 Local Transfer 代码，顺便检查一下 Python 是否高于 3.7.0 版本。

> [!TIP]
> ```Bash
> git clone https://github.com/Illusionna/LocalTransfer.git
> python3 --version
> ```

我在自己的电脑上使用了内网穿透，然后直接在云服务器 "`curl`" 源码压缩包，没有使用 "`git`" 指令。可参考“**3.4.1. 内网穿透**” 教程。

<div style="text-align: center;">
    <img src="assets/img/curl.png" style="zoom:100%;" alt="Oops?">
</div>

解压 "`src.zip`" 压缩包后，后台启动 Local Transfer 服务。

> [!TIP]
> ```Bash
> unzip  src.zip
> cd  src
> nohup  python3  main.py
> ```

<div style="text-align: center;">
    <img src="assets/img/nohup.png" style="zoom:100%;" alt="Oops?">
</div>

### 第四步：上传 Hello World 文件

在浏览器地址栏输入云服务器的公网 IPv4 和端口号，然后上传 "`index.html`" 文件。

<div style="text-align: center;">
    <img src="assets/img/IPv4.png" style="zoom:100%;" alt="Oops?">
    <img src="assets/img/upload.png" style="zoom:100%;" alt="Oops?">
</div>

### 第五步：你的 Hello World 已经部署到互联网

现在，你可以采用公网 IP 访问法，将 "`[IPv4]:8888/index.html`" 发送给小伙伴，他们就可以通过浏览器地址栏搜索到你的个人主页。

<div style="text-align: center;">
    <img src="assets/img/web.jpeg" style="zoom:100%;" alt="Oops?">
    <img src="assets/img/see.jpeg" style="zoom:100%;" alt="Oops?">
</div>

### 第六步：使用模板美化你的主页

如果你掌握了 HTML + CSS + JavaScript，你可以自己写出想要的风格，但如果你是小白，可以使用现成的静态博客模板，例如，推荐 HTML5UP-hyperspace 模板。

> Typecho、Hexo、HTML5UP....

<div style="text-align: center;">
    <img src="assets/img/template.png" style="zoom:100%;" alt="Oops?">
</div>

### 第七步：上传整个 HTML5UP-hyperspace 文件夹

你可以把 "`HomePage`" 文件夹压缩成 .zip 文件，然后将自己电脑内网穿透，再使用 "`curl`" 工具在华为云服务器下载 "`HomePage.zip`" 压缩包并解压到 "`/home/src/DEFAULT_CACHE`" 文件夹。当然，更方便的是参考“**3.3.3. 上传一个文件夹**”，使用 Python 代码上传文件夹。

先删除原先丑陋的 Hello World 文件。

```Bash
rm  index.html
```

<div style="text-align: center;">
    <img src="assets/img/rm.png" style="zoom:100%;" alt="Oops?">
</div>

然后执行如下 Python 代码：

```python
import os

f = lambda src, dst, url: os.system(f'curl  -X  POST  -F  "{dst}=@{src}"  {url}')

folder = 'C:/Users/linma/Desktop/HomePage/html5up-hyperspace/'

for dir, names, files in os.walk(folder):
    for filename in files:
        f(
            src = os.path.join(dir, filename),
            dst = ('../' + dir[len(folder):]).replace('\\', '/'),
            url = 'http://124.[xxxxxx].21:8888/POST-API'    # 替换成你的云服务器公网 IPv4 地址.
        )
```

<div style="text-align: center;">
    <img src="assets/img/public.png" style="zoom:100%;" alt="Oops?">
</div>

现在再让小伙伴用浏览器地址栏搜索 "`[IPv4]:8888/index.html`" 就会变成美化的页面啦~

<div style="text-align: center;">
    <img src="assets/img/aesthetic.png" style="zoom:50%;" alt="Oops?">
</div>

### 第八步：DNS 域名解析

你的小伙伴总觉得使用 "`[IPv4]:8888/index.html`" 打开你的个人博客很麻烦，能不能将 IPv4 换成一个好记忆的域名？例如："`LocalTransfer.top:8888/index.html`"

使用腾讯云购买 "`LocalTransfer.top`" 域名，然后解析到华为云服务器主机公网 IPv4 地址。

<div style="text-align: center;">
    <img src="assets/img/DNS.png" style="zoom:100%;" alt="Oops?">
</div>

浏览器地址栏输入以下四种 URL 都可以访问到美化的 Hello World 页面。

> `LocalTransfer.top:8888/index.html`
>
> `www.LocalTransfer.top:8888/index.html`
>
> `http://LocalTransfer.top:8888/index.html`
>
> `http://www.LocalTransfer.top:8888/index.html`

<div style="text-align: center;">
    <img src="assets/img/DNS-Parse.png" style="zoom:100%;" alt="Oops?">
</div>

如果输入 "`LocalTransfer.top:8888`"，你会看到部署的 Local Transfer 服务。

<div style="text-align: center;">
    <img src="assets/img/LocalTransfer.png" style="zoom:100%;" alt="Oops?">
</div>

但是直接输入 "`LocalTransfer.top`"，是无法返回任何页面内容的，因为你只在防火墙开启了 "`8888`" 号端口。

<div style="text-align: center;">
    <img src="assets/img/unexpected.png" style="zoom:100%;" alt="Oops?">
</div>

> [!WARNING]
> 国内 DNS 域名和云服务器都需要备案，国外基本不需要，因此，你也许会遇到这样的界面。【但是你依然可以使用 IP 访问法："`124.[xxxxxx].21:8888/index.html`"】

<div style="text-align: center;">
    <img src="assets/img/record.png" style="zoom:100%;" alt="Oops?">
</div>

### 第九步：nginx 反向代理

每次在浏览器输入 `LocalTransfer.top:8888/index.html` 还是比较麻烦，我们可以使用 "`nginx`" 工具实现输入 "`LocalTransfer.top/index.html`" 就能重定向到 `LocalTransfer.top:8888/index.html` 页面，从而隐藏端口号。

先 ssh 登录华为云服务器，再安装 "`nginx`" 软件。

```Bash
sudo apt install nginx
```

<div style="text-align: center;">
    <img src="assets/img/nginx.png" style="zoom:100%;" alt="Oops?">
</div>

进入 "`nginx`" 软件文件夹，使用 vim 修改 "`nginx.conf`" 配置文件。

```Bash
cd  /etc/nginx
vim  nginx.conf
```

把两个 "`include`" 用 "`#`" 号注释掉，然后增加一条指令，按住 "`Esc`" + "`:wq`" 保存并退出。

<div style="text-align: center;">
    <img src="assets/img/old.png" style="zoom:100%;" alt="Oops?">
</div>

```txt
server {
    listen 80;
    server_name localtransfer.top;
    location / {
        proxy_pass http://$server_addr:8888;
    }
}
```

<div style="text-align: center;">
    <img src="assets/img/new.png" style="zoom:100%;" alt="Oops?">
</div>

接着依次执行指令，关闭 "`nginx`"，再开启 "`nginx`"。

```Bash
sudo  nginx  -s  stop
sudo  nginx  start
```

你也可以重启 "`nginx`" 以更新配置。

```Bash
sudo  nginx  -s  reload
sudo  service  nginx  restart
```

这样，你就可以在浏览器地址栏输入 **"`LocalTransfer.top/index.html`"** 访问到你的主页啦（由于没有备案，所以访问不到）。

<div style="text-align: center;">
    <img src="assets/img/OK.png" style="zoom:100%;" alt="Oops?">
</div>