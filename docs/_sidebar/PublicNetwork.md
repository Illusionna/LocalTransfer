## 3.4.1. 内网穿透

局域网内文件互传是 Local Transfer 的初衷，但有时候我们可能需要**公网互传文件**，好比我在北京，你在深圳，那么就需要将 "`Local`" Transfer 变成 "`Global`" Transfer，先介绍内网穿透技术。

内网穿透，通俗来说，就是让本地的网络接入互联网，需要借助一些内网穿透工具，例如 "`cpolar`" 软件，你可以在它的官网下载：https://www.cpolar.com

根据 "`cpolar`" 官网教程，先注册一个账号，再购买免费的通道，最后授权验证。

> [!TIP]
> 启动 Local Transfer 的 WebServer 服务，再用 `cpolar` 穿透套接字。
> ```PowerShell
> cpolar  http  [socket]
> ```

<div style="text-align: center;">
    <img src="assets/img/demo-cpolar.png" style="zoom:100%;" alt="Oops?">
    <img src="assets/img/demo-cpolar-result.png" style="zoom:100%;" alt="Oops?">
</div>

"`cpolar`" 启动后会提供你 HTTP 和 HTTPS 两条通道，这样你就可以使用公网访问到 "`Global`" Transfer 啦~ ｡◕‿◕｡

> [!WARNING|label:Important]
> 例如，使用终端 GET 请求从内网穿透的公网上下载文件。
> ```Bash
> curl  https://53b6379b.r22.cpolar.top/main.pdf  -o  main.pdf
> ```

## 3.4.2. 云服务器

内网穿透只是应急措施，因为你总不能一直把自己的电脑开着，而且如果自己电脑有重要文件，那么将内网穿透到公网是存在被恶意攻击的风险。因此，使用公网服务器就会绕开这些问题，例如将 Local Transfer 部署到腾讯云的轻量级服务器（免费试用一个月）。

<div style="text-align: center;">
    <img src="assets/img/demo-Tencent.png" style="zoom:100%;" alt="Oops?">
</div>

将你的目光聚焦于四个红色框，第一个 "`211.159.167.205`" 是公网 IPv4，第二个是“运行中”，第三个是“Linux-Ubuntu 电脑的配置”，第四个是防火墙。在云服务器的**防火墙**添加一条记录，开放 "`8888`" 端口。

<div style="text-align: center;">
    <img src="assets/img/demo-firewall.png" style="zoom:100%;" alt="Oops?">
</div>

然后登录你的云服务器，可以通过腾讯云浏览器前端网页接入终端，也可以通过 "`ssh`" 接入终端。例如，我已经在腾讯云服务器上创建了一个叫 "`ubuntu`" 的用户，且该用户密码为 "`1234567890`"，那么只需要执行指令：

```PowerShell
ssh  ubuntu@211.159.167.205
```

<div style="text-align: center;">
    <img src="assets/img/demo-ssh.png" style="zoom:100%;" alt="Oops?">
</div>

参考“**2.3. 在 Linux 上运行**”教程，使用 "`git`" 下载源代码（或者在自己电脑上开启 Local Transfer，再使用 "`cpolar`" 内网穿透，然后在云服务器终端 GET 请求下载源码压缩包），进入 "`src`" 文件夹，再启动后台运行 Local Transfer 程序。

```Bash
git  clone  https://github.com/Illusionna/LocalTransfer.git
cd  src
```

```Bash
nohup  python3  main.py  -port  8888
```

<div style="text-align: center;">
    <img src="assets/img/demo-nohup.png" style="zoom:100%;" alt="Oops?">
</div>

此时，我们的 Local Transfer 程序已经在云服务器后台内网环境下运行起来了，并且前面也开启了 "`8888`" 端口的防火墙，所以可以通过公网访问，在设备浏览器地址栏输入公网 IPv4 和端口号 "`http://211.159.167.205:8888`"，页面即可正常显示。

<div style="text-align: center;">
    <img src="assets/img/demo-public.png" style="zoom:100%;" alt="Oops?">
</div>