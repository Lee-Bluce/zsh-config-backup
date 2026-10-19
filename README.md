# zsh-config-backup

跨机器统一的 Zsh / Oh My Zsh 配置备份。把你 Mac 上这套满意的 zsh 环境，一键装到任意服务器（x86_64 / arm64 / armv7 都行）。

**仓库地址**：https://github.com/Lee-Bluce/zsh-config-backup

## 一条命令安装（任意服务器）

```bash
curl -fsSL https://raw.githubusercontent.com/Lee-Bluce/zsh-config-backup/main/bootstrap.sh | bash
```

脚本自动完成：

1. 识别发行版（Debian/Ubuntu、RHEL/CentOS/Rocky/Alma/Fedora、Arch、openSUSE、Alpine、macOS）并安装 `zsh` / `git` / `curl`
2. `git clone` 最新版 oh-my-zsh 到 `~/.oh-my-zsh`
3. 克隆插件 `zsh-autosuggestions`、`zsh-syntax-highlighting`
4. 备份原有 `.zshrc`，部署本仓库配置，创建 `~/.zshrc.local`
5. `chsh` 把默认 shell 改成 zsh（可用 `--skip-chsh` 跳过）

装完 `exec zsh` 或重新登录即可生效。**再跑一次同样的命令就是更新**（幂等）。

### 常用变体

```bash
# 为指定用户安装
curl -fsSL .../bootstrap.sh | bash -s -- --user deploy

# 服务器也用 p10k 观感（本地终端需装 MesloLGS NF 字体）
curl -fsSL .../bootstrap.sh | bash -s -- --with-p10k

# 国内网络加速（GitHub 拉不动时）
curl -fsSL .../bootstrap.sh | GITHUB_MIRROR=https://ghfast.top/ bash

# 只预览会做什么，不动系统
curl -fsSL .../bootstrap.sh | bash -s -- --dry-run

# 离线方式：把仓库拷到服务器直接装
scp -r zsh-config-backup server:~ && ssh server 'bash ~/zsh-config-backup/install.sh'
```

### 全部参数

| 参数 | 说明 |
|---|---|
| `--user U` | 目标用户（默认：`SUDO_USER`，其次 root / 当前用户） |
| `--home DIR` | 指定目标 HOME（测试或特殊环境） |
| `--simple` / `--with-p10k` | 主题模式（默认 `simple`） |
| `--base-url URL` | 从静态服务器（非 GitHub）下载配置包的地址 |
| `--github-mirror URL` | GitHub 加速前缀，如 `https://ghfast.top/` |
| `--assets-dir DIR` | 指定资源目录（默认脚本旁 `files/`） |
| `--skip-packages` | 不装系统依赖（zsh/git 已就绪） |
| `--skip-chsh` | 不改默认登录 shell |
| `--force` | 目标目录存在且非 git 仓库时强制覆盖 |
| `--dry-run` | 只打印计划，不做改动 |

## 目录结构

```
zsh-config-backup/
├── install.sh                  # 一键安装脚本（幂等，可反复跑）
├── uninstall.sh                # 卸载 / 回滚脚本
├── bootstrap.sh                # 在线引导脚本（GitHub 一条命令入口）
├── pack.sh                     # 打成 tar.gz（离线分发用，GitHub 模式不需要）
├── README.md
└── files/
    ├── zshrc                   # 可移植版 .zshrc（已剔除本机专属路径）
    ├── p10k.zsh                # powerlevel10k 配置（92KB，原样保留）
    └── zshrc.local.example     # 本机私有配置示例
```

## 做了什么可移植性处理

原 `~/.zshrc` 里有 4 处写死了本机路径，直接搬到服务器会报错，已处理：

| 原内容 | 处理方式 |
|---|---|
| `export PATH="/Users/xing/.antigravity-ide/..."` | 移到 `~/.zshrc.local`（本机专属） |
| `source /Users/xing/Downloads/临时/tmp/google-cloud-sdk/...` | 同上，改成 `$HOME` 相对路径并加存在性判断 |
| `export PATH=/Users/xing/.opencode/bin:$PATH` | 改成通用写法 `$HOME/.opencode/bin`，存在才加 |
| `export LANG/LC_ALL=en_US.UTF-8` | 加 locale 探测：有 `en_US.UTF-8` 用它，否则退到 `C.UTF-8`，都没有就不设 |

插件与主题列表、`unalias -m h`、Homebrew 环境变量等其余内容**按 Mac 原样保留**。

## 提示符长什么样

默认（`simple`）模式**用纯 zsh 复刻了 Mac 上 powerlevel10k classic 的布局**，两行、无图标、不需要 Nerd Font：

```
╭─ ~/Documents/Ai/tmpwork  git:(main)                              ✔ at 13:55:42
╰─❯ 
```

- 第一行：`╭─` 边框 + **完整路径**（`~` 缩写，与 Mac 一致）+ git 分支（在仓库内才显示）
- 右侧：上条命令状态（成功绿 `✔` / 失败红 `✘`）+ **系统时间**（`at HH:MM:SS`，贴右边缘自动对齐）
- 第二行：`╰─❯` 命令输入行
- 颜色沿用 Mac 配置：路径 `31`、边框 `242`、时间 `66`、提示符 `76`、状态 `70/160`
- 中文路径按**显示宽度**计算（一个汉字算 2 列），窄终端会自动先舍弃 git 分支、再舍弃右侧信息，绝不换行错位

## 主题模式（关键设计）

| 模式 | 用在哪 | 表现 |
|---|---|---|
| `simple`（默认） | 服务器 | 纯 zsh 复刻上面的两行布局，**不需要 Nerd Font**，不会出现方块乱码 |
| `p10k` | Mac / 有 Nerd Font 的终端 | 加载 `files/p10k.zsh`，与 Mac 100% 一致（含 Apple 图标、powerline 分隔符） |

模式记在 `~/.config/omz-setup/mode`，由 `install.sh` 写入，`~/.zshrc` 读取决定。
临时切换：`echo simple > ~/.config/omz-setup/mode`（或 `echo p10k > ...`）后重开终端。
没有这个文件时（例如直接把 `files/zshrc` 拷到 Mac 上）会自动探测：装了 p10k 就用 p10k，否则用 `simple`。


## 怎么更新这份备份

改完 `files/` 里的内容后：

```bash
cd ~/Documents/Ai/tmpwork/omz-setup
git add -A
git commit -m "调整 xxx"
git push
```

推送后，所有服务器**下次执行那条安装命令**就会拿到最新配置（oh-my-zsh 与插件也会一起 `git pull` 更新）。

## 加自己的东西

**别改 `~/.zshrc`**（会被覆盖），写进 `~/.zshrc.local`（安装时自动创建，永不被覆盖）：

```bash
# ~/.zshrc.local
alias ll='ls -alh --color=auto'
alias gs='git status -sb'
export EDITOR=vim
```

各机器不同的部分（如 Google Cloud SDK 路径）分别写各机器的 `~/.zshrc.local`，参考 `files/zshrc.local.example`。

⚠️ **不要**把 token、密码写进本仓库任何文件——仓库是公开的。

## 卸载 / 回滚

```bash
bash uninstall.sh                    # 恢复被覆盖的 .zshrc，保留 ~/.oh-my-zsh
bash uninstall.sh --purge            # 连 ~/.oh-my-zsh 一起删掉
bash uninstall.sh --restore-shell    # 默认 shell 改回 bash
```

## 常见问题

**服务器上提示符出现方块/乱码？**
说明装成了 `p10k` 模式但终端没有 Nerd Font（p10k 模式会显示 Apple/企鹅图标和 powerline 分隔符）。改回默认模式即可：`echo simple > ~/.config/omz-setup/mode` 后重开终端；或在本地终端装 MesloLGS NF 字体。

**`raw.githubusercontent.com` 打不开？**
用镜像：`curl -fsSL ... | GITHUB_MIRROR=https://ghfast.top/ bash`。引导脚本本身也可以用加速地址拉取。

**精简容器里没有 `sudo`、装不了包？**
用 `--skip-packages`，自己保证 `zsh` 和 `git` 存在（Alpine：`apk add zsh git curl`；完全没有 git 时脚本会退回 tarball 下载）。

**中文显示/输入异常？**
`~/.zshrc` 只在系统本身有 `en_US.UTF-8` 时才设它，否则退到 `C.UTF-8`。需要 `zh_CN.UTF-8` 就在 `~/.zshrc.local` 里覆盖。

**macOS 上执行需要 `sudo` 吗？**
不需要，普通用户跑即可，脚本只在「装包 / 改默认 shell」这类步骤自动提权。
