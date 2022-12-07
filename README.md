# scoop bucket

## 安装 scoop

---

如果不明白 scoop 是什么，点击查看这里 [scoop](https://github.com/ScoopInstaller/Scoop)

可以简单理解为 scoop 是一个绿色软件的自动安装管理工具

## 安装该软件仓库中的软件

---

确保你已经有 Scoop 环境后，执行以下命令订阅本软件仓库：

```powershell
scoop bucket add vi https://github.com/ViCrack/scoop-bucket
```

执行以下命令安装本仓库中的软件：

```powershell
scoop install vi/<软件名>
```

例如

```powershell
scoop install vi/fastgithub
scoop install vi/xray
scoop install vi/windterm
scoop install vi/screentogif
scoop install vi/PowerRun
scoop install vi/MonitorOff
scoop install vi/wub
.......
```

大多数情况下，是可以省略 `vi/`，只需要执行类似 `scoop install nuclei` 的命令

## 软件自动更新

---

这个仓库已经添加 github ci 自动化，每隔几个小时会自动更新所有软件到最新版本

使用者可以自行在系统中加个定时任务，这样就能自动更新 scoop 软件了，当然也可以手工更新

```powershell
scoop update *
```

单个软件的更新可以使用下列命令，大多数情况下软件名不重复的话，可以省略 `vi/`，只需要执行类似 `scoop update xray` 的命令

```powershell
scoop update vi/xray
scoop update vi/windterm
scoop update vi/screentogif
.......
```

## 现有适配软件

---

> **关注持续更新, 有问题提 issue**

---

| 软件                               | 描述                                                                                                                                                                                                                                                                                                                                                                                                     |
| :--------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| scoop install fastgithub           | github 加速神器，解决 github 打不开、用户头像无法加载、releases 无法上传下载、git-clone、git-pull、git-push 失败等问题.                                                                                                                                                                                                                                                                                  |
| scoop install finalshell           | FinalShell,SSH 工具,服务器管理,远程桌面加速软件,支持 Windows,macOS,Linux                                                                                                                                                                                                                                                                                                                                 |
| scoop install postman-cn           | Postman 中文版                                                                                                                                                                                                                                                                                                                                                                                           |
| scoop install rad                  | 一款专为安全扫描而生的浏览器爬虫                                                                                                                                                                                                                                                                                                                                                                         |
| scoop install treesize             | TreeSize 纯净版是一款功能强大的磁盘空间管理软件，为用户提供了功能强大的磁盘空间管理功能                                                                                                                                                                                                                                                                                                                  |
| scoop install verycapture          | 支持长截图，矩形截图，延时截图，任意区域截图，gif 录制，录屏，ocr 翻译等功能                                                                                                                                                                                                                                                                                                                             |
| scoop install windterm             | A professional cross-platform SSH/Sftp/Shell/Telnet/Serial terminal. client                                                                                                                                                                                                                                                                                                                              |
| scoop install xray                 | 被动扫描器，一款完善的安全评估工具，支持常见 web 安全问题扫描和自定义 poc                                                                                                                                                                                                                                                                                                                                |
| scoop install wub                  | 彻底关闭或者启用 Windowns 更新的工具(Windows Update Blocker) 中文版                                                                                                                                                                                                                                                                                                                                      |
| another-redis-desktop-manager      | AnotherRedisDesktopManager, 更快、更好、更稳定的 Redis 桌面(GUI)管理客户端，兼容 Windows、Mac、Linux，性能出众，轻松加载海量键值.                                                                                                                                                                                                                                                                        |
| scoop install dev-sidecar          | 开发者边车，github 打不开，github 加速，git clone 加速，git release 下载加速，stackoverflow 加速 .                                                                                                                                                                                                                                                                                                       |
| scoop install EmEditor             | EmEditor 是一款快速，轻巧，可扩展，使用方便的 Windows 代码编辑器。支持宏，Unicode，代码段插件，还能处理大数据以及 CSV 文件，无需 Excel，堪称最强 CSV 编辑器。软件自带简体中文，支持 32 位和 64 位版。                                                                                                                                                                                                    |
| scoop install Proguard             | Java optimizer and obfuscator, Java 混淆工具                                                                                                                                                                                                                                                                                                                                                             |
| scoop install PowerRun             | PowerRun (Run with highest privileges) 使用 TrustedInstaller/System 的权限运行程序                                                                                                                                                                                                                                                                                                                       |
| scoop install MonitorOff           | MonitorOff (Screen Turns Off) 用于关闭显示器屏幕                                                                                                                                                                                                                                                                                                                                                         |
| scoop install Fab                  | Firewall App Blocker (Fab) 易于使用的 Windows 防火墙工具                                                                                                                                                                                                                                                                                                                                                 |
| scoop install RegConverter         | RegConverter 可以将.reg 文件转换为.bat，.vbs 或.au3。这对于需要管理员权限才能合并到注册表中的文件或无人参与的自动化安装时特别有用。                                                                                                                                                                                                                                                                      |
| scoop install cpuz-cn              | CPU-Z 中文版                                                                                                                                                                                                                                                                                                                                                                                             |
| scoop install apifox               | Apifox 是 API 文档、API 调试、API Mock、API 自动化测试一体化协作平台，定位 Postman + Swagger + Mock + JMeter。支持版本自动更新                                                                                                                                                                                                                                                                           |
| scoop install naabu                | naabu 是用 go 编写的快速端口扫描器                                                                                                                                                                                                                                                                                                                                                                       |
| scoop install afrog                | afrog 是一款性能卓越、快速稳定、PoC 可定制化的漏洞扫描工具 - A tool for finding vulnerabilities                                                                                                                                                                                                                                                                                                          |
| scoop install caesium              | Caesium is an image compression software that helps you store, send and share digital pictures, supporting JPG, PNG and WebP formats.                                                                                                                                                                                                                                                                    |
| scoop install igdm                 | Desktop application for Instagram DMs                                                                                                                                                                                                                                                                                                                                                                    |
| scoop install kscan                | Kscan 是一款纯 go 开发的全方位扫描器，具备端口扫描、协议检测、指纹识别，暴力破解等功能。支持协议 1200+，协议指纹 10000+，应用指纹 2000+，暴力破解协议 10 余种。                                                                                                                                                                                                                                          |
| scoop install bowpad               | A simple and fast text editor with a ribbon UI                                                                                                                                                                                                                                                                                                                                                           |
| scoop install vscan                | 开源、轻量、快速、跨平台 的网站漏洞扫描工具，帮助您快速检测网站安全隐患。功能 端口扫描(port scan) 指纹识别(fingerprint) 漏洞检测(nday check) 智能爆破 (admin brute) 敏感文件扫描(file fuzz)                                                                                                                                                                                                              |
| scoop install bluelife-host-editor | BlueLife Hosts editor is a Portable freeware to simplify \"hosts\" file editing Process, you can Speed up most visited webpages or block unwanted domain names                                                                                                                                                                                                                                           |
| scoop install w3cschool            | w3cschool 离线版 编程手册                                                                                                                                                                                                                                                                                                                                                                                |
| scoop install ddns-go              | 简单好用的 DDNS。自动更新域名解析到公网 IP(支持阿里云、腾讯云 dnspod、Cloudflare、华为云、百度云、porkbun)                                                                                                                                                                                                                                                                                               |
| scoop install gda                  | the fastest and most powerful android decompiler(native tool working without Java VM) for the APK, DEX, ODEX, OAT, JAR, AAR, and CLASS file. which supports malicious behavior detection, privacy leaking detection, vulnerability detection, path solving, packer identification, variable tracking, deobfuscation, python&java scripts, device memory extraction, data decryption, and encryption, etc |
| scoop install curl-impersonate     | A special build of curl for Windows that can impersonate Chrome                                                                                                                                                                                                                                                                                                                                          |
| scoop install edx                  | 一款高性能的可扩展编辑器                                                                                                                                                                                                                                                                                                                                                                                 |
| scoop install cudatext-cn          | cudatext 文本编辑，中文版，优化修正设置目录器                                                                                                                                                                                                                                                                                                                                                            |
| scoop install transfer             | 集合多个 API 的大文件传输工具器                                                                                                                                                                                                                                                                                                                                                                          |
| scoop install filezilla            | 支持自动更新到最新版本                                                                                                                                                                                                                                                                                                                                                                                   |
| scoop install windynamicdesktop    | Port of macOS Mojave Dynamic Desktop feature to Windows 10                                                                                                                                                                                                                                                                                                                                               |
| scoop install crawlergo            | A powerful browser crawler for web vulnerability scanners                                                                                                                                                                                                                                                                                                                                                |
| scoop install nuclei               | Fast and customizable vulnerability scanner based on simple YAML based DSL                                                                                                                                                                                                                                                                                                                               |
| scoop install observerward         | Cross platform community web fingerprint identification tool                                                                                                                                                                                                                                                                                                                                             |
| scoop install httpx                | httpx is a fast and multi-purpose HTTP toolkit that allows running multiple probes using the retryablehttp library. It is designed to maintain result reliability with an increased number of threads                                                                                                                                                                                                    |
| scoop install notify               | Notify is a Go-based assistance package that enables you to stream the output of several tools (or read from a file) and publish it to a variety of supported platforms                                                                                                                                                                                                                                  |
| scoop install subfinder            | Subfinder is a subdomain discovery tool that discovers valid subdomains for websites. Designed as a passive framework to be useful for bug bounties and safe for penetration testing                                                                                                                                                                                                                     |
| scoop install ksubdomain           | 无状态子域名爆破工具                                                                                                                                                                                                                                                                                                                                                                                     |
| scoop install interactsh           | An OOB interaction gathering server and client library                                                                                                                                                                                                                                                                                                                                                   |
| scoop install katana               | A next-generation crawling and spidering framework                                                                                                                                                                                                                                                                                                                                                       |
| scoop install super-xray           | XRAY GUI Starter (Web Vulnerability Scanner)                                                                                                                                                                                                                                                                                                                                                             |
| scoop install behinder             | “冰蝎”动态二进制加密网站管理客户端                                                                                                                                                                                                                                                                                                                                                                       |
| scoop install ffuf                 | Fast web fuzzer written in Go                                                                                                                                                                                                                                                                                                                                                                            |
| scoop install siyuan               | SiYuan is a local-first personal knowledge management system, support fine-grained block-level reference and Markdown instant-render editing 思源笔记                                                                                                                                                                                                                                                    |
