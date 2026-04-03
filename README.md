# AI Code Launcher

这是一个原生 macOS 小启动器，用来减少这几个重复动作：

- 找项目目录
- 切到项目目录
- 选择或输入启动命令

当前实现使用原生 AppKit，不再依赖 Tk。

应用图标会在构建时由 [generate_icon.py](/Users/byp/Documents/my-projects/demo1/generate_icon.py) 自动生成，并打包进 `.app`。

## 现在的工作方式

- 第一次点击“选择文件夹...”，选你的项目目录
- 选完后可以选择“只添加当前文件夹”或“列出所有子文件夹”
- 之后这个目录会进入“最近使用”
- 常用目录可以点“收藏当前项目”
- 不需要的目录可以点“移除当前项目”
- 选中目录后，从下拉框选择命令，或者直接输入自定义命令再启动

## 运行

构建 `.app`：

```bash
zsh build_app.sh
```

构建并打开：

```bash
./start_launcher.command
```

构建安装包：

```bash
./build_installer.sh
```

构建 `.dmg`：

```bash
./build_dmg.sh
```

生成的应用在：

```text
/Users/byp/Documents/my-projects/demo1/AI Code Launcher.app
```

生成的安装包在：

```text
/Users/byp/Documents/my-projects/demo1/AI Code Launcher Installer.pkg
```

生成的磁盘镜像在：

```text
/Users/byp/Documents/my-projects/demo1/AI Code Launcher.dmg
```

`.dmg` 会包含：

- `AI Code Launcher.app`
- `Applications` 快捷方式
- 标准拖拽安装内容

## 命令设置

界面现在改成一个可输入的启动命令下拉框：

- 默认预置 `codex`
- 默认预置 `claude code`
- 默认预置 `opencode`
- 也可以手动输入任意启动命令
- 自定义命令会自动记住

设置会保存到：

```text
~/Library/Application Support/ai-code-launcher/config.json
```

如果你选择“列出所有子文件夹”，父目录会保存到 `rootFolders`，之后应用打开时会继续把它下面的子文件夹列出来。

当你点击“移除当前项目”时：

- 如果这是单独添加的目录，只会移除这个目录
- 如果这是某个父目录导入出来的子文件夹，会连同那个父目录的子文件夹列表一起移除
