# AI Code Launcher

一个原生 macOS 启动器，用来减少这几个重复动作：

- 找项目目录
- 切到项目目录
- 选择或输入启动命令

当前实现基于原生 AppKit，不依赖 Tk。

## 功能

- 选择单个项目目录，或者一口气列出某个根目录下的所有子文件夹
- 收藏常用项目
- 移除不再需要的项目或整个子目录来源
- 在 Finder 中直接定位当前项目
- 用一个可输入的下拉框管理启动命令
- 预置常用命令：`codex`、`claude code`、`opencode`
- 记住你自己输入过的自定义命令
- 界面文案会根据系统语言在中文和英文之间自动切换

## 安装

仓库里已经包含两种可直接安装的产物：

- `AI Code Launcher Installer.pkg`
- `AI Code Launcher.dmg`

文件大小：

- `.pkg`: 252 KB
- `.dmg`: 268 KB

### 用 `.pkg`

双击 `AI Code Launcher Installer.pkg`，按安装向导完成安装。

### 用 `.dmg`

双击 `AI Code Launcher.dmg`，把 `AI Code Launcher.app` 拖到 `Applications`。

### 首次打开

如果 macOS 提示无法验证开发者，可以：

1. 在 Finder 里右键应用
2. 选择 `打开`
3. 再确认一次打开

## 使用方式

1. 点击 `选择文件夹...`
2. 选择只添加当前目录，或者列出这个目录下的所有子文件夹
3. 从项目列表里选中目标目录
4. 从启动命令下拉框里选择命令，或者直接输入自定义命令
5. 点击 `启动`

## 命令设置

启动命令区域现在是一个可输入的下拉框：

- 默认预置 `codex`
- 默认预置 `claude code`
- 默认预置 `opencode`
- 支持直接输入任意命令
- 自定义命令会自动记住

## 配置保存

应用配置会保存在：

```text
~/Library/Application Support/ai-code-launcher/config.json
```

其中包括：

- `rootFolders`
- `recentProjects`
- `pinnedProjects`
- `customCommands`
- `lastCommand`

如果选择“列出所有子文件夹”，父目录会保存到 `rootFolders`，之后应用打开时会继续列出它下面的子文件夹。

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

直接启动本地构建版本：

```bash
./start_launcher.command
```

## 项目结构

- `LauncherApp.m`: 当前使用中的原生 AppKit 主程序
- `build_app.sh`: 构建 `.app`
- `build_installer.sh`: 构建 `.pkg`
- `build_dmg.sh`: 构建 `.dmg`
- `generate_icon.py`: 生成应用图标
- `assets/`: 图标和打包相关资源

仓库里还保留了一些早期尝试文件，例如 `launcher.py` 和 `LauncherApp.swift`，当前构建流程并不使用它们。

## 说明

- `.dmg` 当前是稳定优先的标准拖拽安装镜像
- 当前没有做签名和公证，分发给别人时第一次打开可能会被 Gatekeeper 拦一下
- 应用图标由 [generate_icon.py](generate_icon.py) 生成并打包进 `.app`
