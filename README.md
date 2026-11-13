# Linux System & Service Inspector

轻量级、只读的 Linux 基础环境信息采集工具，用于安装包适配、客户现场支持和基础环境确认。

**采集范围**：发行版及 `ID_LIKE`、CPU/架构、内核、GCC、libc、包管理体系、init/systemd、Python、Java/JDK。

## 快速使用

```bash
bash scripts/linux-inspector.sh
bash scripts/linux-inspector.sh --output linux-inspector-report.txt
```

从 GitHub Release 下载固定版本并校验：

```bash
curl -fL --retry 3 -o linux-inspector.sh \
  https://github.com/blatwo/linux-inspector/releases/download/v0.1.0/linux-inspector.sh
curl -fL --retry 3 -o SHA256SUMS https://github.com/blatwo/linux-inspector/releases/download/v0.1.0/SHA256SUMS
sha256sum -c SHA256SUMS
bash linux-inspector.sh --output linux-inspector-report.txt
```

也可使用原始文件地址（`main` 会变化，不适用于可复现部署）：

```bash
curl -fL -o linux-inspector.sh \
  https://raw.githubusercontent.com/blatwo/linux-inspector/main/scripts/linux-inspector.sh
bash linux-inspector.sh
```

## 特点

- 只读：不安装软件、不修改系统配置、不启动/停止服务。
- 默认无需 root、无网络请求、无第三方运行依赖（依赖 Bash 与系统常用命令）。
- 缺少 GCC、Python、JDK 等工具时显示 `not found`。
- 包管理器识别优先参考 `/etc/os-release`，再观察包数据库；不会因为 Debian 系安装了 `rpm` 就判定为 RPM 系。
- 默认不采集 machine-id、IP 地址、密码或进程环境变量，但主机名/CPU 型号/系统标识等仍可能属于环境信息，外发前应检查。

## 目录结构

```text
linux-inspector/
├── README.md
├── LICENSE
├── CHANGELOG.md
├── .gitignore
├── .editorconfig
├── .shellcheckrc
├── scripts/
│   └── linux-inspector.sh
├── tests/
│   └── smoke-test.sh
├── docs/
│   ├── design.md
│   └── release.md
└── .github/
    └── workflows/
        └── ci.yml
```

## 扩展计划

未来按需增加 PostgreSQL、HGDB、Patroni 和 etcd 的独立只读检查模块；当前版本尚未实现这些服务检查。详见 [设计说明](docs/design.md)。

## 开发

```bash
bash -n scripts/linux-inspector.sh
bash tests/smoke-test.sh
shellcheck scripts/linux-inspector.sh   # 可选，需预先安装 shellcheck
```

## 兼容性

目标系统：RHEL/Rocky、Debian/Ubuntu、部分国产 Linux（LinxOS、麒麟、UOS 等），以及其他 Bash 可用环境。检测结果是环境线索，**并非操作系统或安装包兼容性认证**。目前在当前容器环境执行过冒烟测试，不代表已完成所有发行版测试。

## 安全提示

不要对不可信地址使用 `curl | bash`。推荐固定版本、下载检查并校验 SHA256 后执行。不要直接将采集报告公开提交到 Issue。

## License

MIT，详见 [LICENSE](LICENSE)。
