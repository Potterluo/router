# vllm-router 镜像构建方案(Fork 增强版)

本 fork 在保留上游代码不变的前提下,新增了**双架构镜像构建** + **上游同步**两个 GitHub Actions workflow,
以及一组本地构建脚本。所有新增文件(`.github/workflows/*`、`scripts/sync-*`、`docs/*`)与上游文件无重名,
每次 sync 都不会产生冲突。

## 方案总览

| 组件 | 文件 | 作用 |
|---|---|---|
| 镜像构建 | `.github/workflows/build-image.yml` | 用原生 runner 分别构建 `linux/amd64` 与 `linux/arm64`,推到 GHCR 并合并成多架构 manifest |
| 上游同步 | `.github/workflows/sync-upstream.yml` | 每天 02:30 UTC(以及手动触发)把 `vllm-project/router:main` 合并进 fork,sync 成功且变更新时自动触发镜像构建 |
| 本地同步 | `scripts/sync-upstream-local.{ps1,sh}` | 本地把 upstream 合并进当前分支(可选 push) |
| 本地构建 | `scripts/sync-and-build.{ps1,sh}` | 本地 buildx 多架构构建(可选 push),构建前自动 sync |

镜像仓库:`ghcr.io/potterluo/router`(GitHub Container Registry,随 fork 仓库,公开可拉取)

## 镜像 Tag 规则

| Tag | 说明 |
|---|---|
| `latest` | 多架构 manifest,始终指向最新已同步的 upstream main |
| `sha-<7位commit>` | 多架构 manifest,对应具体提交 |
| `<自定义tag>` | 手动触发构建时通过 `image_tag` 输入指定(如 `v0.1.15`) |
| `sha-<7位commit>-amd64` / `-arm64` | 单架构镜像,保留用于调试,可放心 pull |

拉取使用(在任意 amd64/arm64 机器上):

```bash
docker pull ghcr.io/potterluo/router:latest
docker run --rm -p 8080:8080 ghcr.io/potterluo/router:latest \
  --host 0.0.0.0 --port 8080
```

## 用法

### 1. 手动构建(随时)

GitHub 仓库 → **Actions** → 选 **build-image** → **Run workflow**:

- `image_tag`: 额外打一个 tag(可选)
- `build_arm64`: 是否构建 arm64(默认 true)
- `use_qemu`: 若 GitHub 原生 ARM runner 不可用(例如仓库变为私有),改为 true 会在 amd64 runner 上用 QEMU 模拟构建,更慢但通用

### 2. 自动同步 + 自动构建

- 每天 02:30 UTC,`sync-upstream` 自动把上游 main 合并进 fork;一旦有变更,合并后推送会触发 `build-image` 自动构建新镜像。
- 也可以手动点 **sync-upstream → Run workflow**,效果相同。
- 不想同步后自动构建时,把输入里的 `auto_build` 关掉即可。

### 3. 本地构建(备选)

需要 git + Docker Desktop(buildx 已内置)。多架构在 x86 主机上需先注册 QEMU:

```bash
docker run --privileged --rm tonistiigi/binfmt --install all
```

PowerShell(Windows):

```powershell
# 只构建不推送(单架构,最快)
.\scripts\sync-and-build.ps1 -Tag local -Platforms linux/amd64

# 本地多架构构建并推到 GHCR
.\scripts\sync-and-build.ps1 -Tag latest -Push
```

bash(Linux / macOS / WSL):

```bash
./scripts/sync-and-build.sh -t latest --push
./scripts/sync-and-build.sh -t local -p linux/amd64
```

只同步不同步构建:`.\scripts\sync-upstream-local.ps1 -Push`(对应 bash 版 `./scripts/sync-upstream-local.sh --push`)。
前提是本地 clone 已添加 upstream:`git remote add upstream https://github.com/vllm-project/router.git`。

### 4. 一次性手动命令

```bash
# amd64 本地快速体验(不推送)
docker build -f Dockerfile.router -t vllm-router:local .

# 多架构推送(需要 QEMU,且已 docker login ghcr.io)
docker buildx build --platform linux/amd64,linux/arm64 \
  -f Dockerfile.router \
  -t ghcr.io/potterluo/router:latest \
  --push .
```

## 常见问题

- **arm64 构建失败/runner 不可用?** ARM runner(`ubuntu-24.04-arm`)目前是 public preview;
  公开仓库直接可用,私有仓库可能受限。此时手动构建时勾选 `use_qemu=true`,或在 fork 上提交流程修改把 runner 换成 `ubuntu-latest`。
- **想改成推到自己私有 registry?** 在 `build-image.yml` 里把 `env.IMAGE` 换成你的镜像名,
  并在 `Log in to GHCR` 步骤前加一步用你 Docker Hub / 私有 registry 的 secret 做 `docker/login-action`。
- **镜像会越来越多?** GHCR 支持为包设置**保留策略**(Settings → Packages → 对应包 → Retention),按需保留最近 N 个版本即可。
- **sync 冲突了怎么办?** fork 上若有自己的提交与 upstream 冲突,sync workflow 会失败并打印详情;
  在本地 resolve 后推回即可。日常只构建镜像、不改上游文件就不会冲突。