# AI Code Launcher

[English README](README.md)

原生 macOS 启动器，用来快速进入项目目录并启动常用 AI 编程命令。

## 功能

- 选择单个项目目录，或者一口气导入某个根目录下的所有子文件夹
- 收藏常用项目，移除不再需要的目录
- 在 Finder 中直接定位当前项目
- 用一个可输入的下拉框管理启动命令
- 内置常用命令：`codex`、`claude code`、`opencode`
- 自动记住你输入过的自定义命令
- 默认跟随 macOS 系统语言
- 支持在应用内手动切换语言

## 安装

仓库里已经包含两种可直接安装的产物：

- `AI Code Launcher Installer.pkg`
- `AI Code Launcher.dmg`

### `.pkg`

双击 `AI Code Launcher Installer.pkg`，按安装向导完成安装。

### `.dmg`

双击 `AI Code Launcher.dmg`，把 `AI Code Launcher.app` 拖到 `Applications`。

### 首次打开

如果 macOS 因为没有公证而拦截应用：

1. 在 Finder 里右键应用
2. 选择 `打开`
3. 再确认一次打开

## 使用方式

1. 点击 `选择文件夹...`
2. 选择只添加当前目录，或者列出该目录下的所有子文件夹
3. 从项目列表中选中目标目录
4. 从命令下拉框中选择预置命令，或者直接输入自定义命令
5. 点击 `启动`

## 语言

应用默认跟随 macOS 系统语言。打开 `AI Code Launcher > 设置...` 后，你可以手动切换：

- `中文`
- `English`

也可以在同一个设置窗口里恢复为“跟随系统语言”。

语言偏好保存在：

```text
~/Library/Application Support/ai-code-launcher/config.json
```

## 构建

构建 `.app`：

```bash
zsh build_app.sh
```

构建安装包：

```bash
zsh build_installer.sh
```

构建 `.dmg`：

```bash
zsh build_dmg.sh
```

启动本地构建版本：

```bash
./start_launcher.command
```

## 项目结构

- `LauncherApp.m`：当前使用中的原生 AppKit 主程序
- `build_app.sh`：构建 `.app`
- `build_installer.sh`：构建 `.pkg`
- `build_dmg.sh`：构建 `.dmg`
- `generate_icon.py`：生成应用图标
- `assets/`：图标和打包相关资源

仓库里还保留了一些早期尝试文件，例如 `launcher.py` 和 `LauncherApp.swift`，当前构建流程并不使用它们。

## 说明

- 当前 `.dmg` 采用稳定优先的标准拖拽安装方式
- 应用目前还没有做签名和公证
- 应用图标由 [generate_icon.py](generate_icon.py) 生成
