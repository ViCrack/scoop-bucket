# scoop bucket

## 安装 scoop

查看 [scoop](https://github.com/ScoopInstaller/Scoop)

## 安装该软件仓库中的软件

确保你已经有 Scoop 环境，执行以下命令订阅本软件仓库：

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
.......
```

## 软件自动更新

```powershell
scoop update *
scoop update vi/xray
scoop update vi/windterm
.......
```



### 现有软件

| 软件          | 描述                                                                               |
|:----------- |:-------------------------------------------------------------------------------- |
| fastgithub  | github加速神器，解决github打不开、用户头像无法加载、releases无法上传下载、git-clone、git-pull、git-push失败等问题. |
| finalshell  | 国产软件,SSH工具,服务器管理,远程桌面加速软件,支持Windows,macOS,Linux                                  |
| postman-cn  | Postman中文版                                                                       |
| rad         | 一款专为安全扫描而生的浏览器爬虫                                                                 |
| treesize    | TreeSize纯净版是一款功能强大的磁盘空间管理软件，为用户提供了功能强大的磁盘空间管理功能                                  |
| verycapture | 支持长截图，矩形截图，延时截图，任意区域截图，gif录制，录屏，ocr翻译等功能                                         |
| windterm    | SSH/Sftp/Shell/Telnet/Serial client                                              |
| xray        | 被动扫描器，一款完善的安全评估工具，支持常见 web 安全问题扫描和自定义 poc                                        |
