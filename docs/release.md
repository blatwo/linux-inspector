# 发布 SOP

1. 修改脚本中的 `VERSION` 与 `CHANGELOG.md`。
2. 执行 `bash -n scripts/linux-inspector.sh && bash tests/smoke-test.sh`。
3. 使用 `git tag v0.1.0 && git push origin v0.1.0` 创建标签。
4. 在 GitHub Releases 创建对应 Tag 的 Release，上传 `scripts/linux-inspector.sh`，附件名称为 `linux-inspector.sh`。
5. 在脚本所在目录执行 `sha256sum linux-inspector.sh > SHA256SUMS`，将 `SHA256SUMS` 一并上传并验证。
6. 下载并在目标发行版上验证，再对外公布固定版本下载命令。

不要使用主分支的移动地址作为正式客户发布文件。
