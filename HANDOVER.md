# 交接文档 — PLE Kaggle 比赛 my-harness

> 日期：2026-11-19
> 状态：脚手架已搭好，**未跑通过**。卡在模型代理和 Docker（见“卡住的地方”）。
> 比赛截止：**2027-01-05 23:59 UTC**（北京时间 2027-01-06 07:59）

## 比赛一句话

Google - Agent Harness on Physical-Engineering's Last Exam（PLE）：做一个开源 agent harness，配 8 个 Google 赞助模型，解 85 个真实工程任务（结构/土木/电气/机械）。不是传统 CSV 预测赛，无排行榜；提交物 = GitHub repo（含 harness + 29 个 dev 任务跑出的 `artifacts/`）+ 2000 字内 Kaggle Writeup。总奖金 $400K（第一 $250K / 第二 $100K / 第三 $50K）。Stage 1 取 Top 100，Stage 2 在 56 个隐藏任务上按 performance-cost Pareto 排名，需 ≥0.138 分才有资格获奖。

详情见 Kaggle：https://www.kaggle.com/competitions/physical-engineerings-last-exam/overview

## 这个仓库是什么

- 来源：`google-research/ple` 的 `sample_submissions/custom-openai` 原样拷出（官方最完整的参考 harness，2026-11-19 从 minimal 换过来，原因见下）。
- 模型：`google-cloud/gemini-3.8-flash`（最便宜的赞助模型，先跑通链路用；换模型只改 `submission.yaml` 里的 `model_api`）。
- 结构：`serve.py`（1800 行：模型循环 + bash/read_file/write_file/edit_file + 任务 MCP 工具 + 流式 + 上下文压缩 + 截止时间管理）+ `taskbridge.py`（WebSocket 协议层）+ `submission.yaml` + `requirements.txt`。
- 上游仓库（只读参考，已 clone 在本地，不在本仓库内）：`~/workspace/kaggle-ple`。

### 为什么从 minimal 换成 custom-openai

minimal 只有 bash/read_file/write_file 三个工具，没有 MCP 工具。而 29 个 dev 任务里 12 个 rubric 任务跑在 world 环境里（邮件、文档、表格、CAD 等应用），只能通过任务自带的 MCP 服务器操作——没有 MCP，这批任务基本拿不到分。custom-openai 自带 MCP 发现与调用（工具少时直接暴露，工具多时用 `mcp_find`/`mcp_call` 按需调用），外加上下文压缩（旧对话总结成笔记再丢弃，6 小时长任务必需）和流式 + 截止时间管理。换底座零移植风险（官方 sample，taskbridge 与 minimal 的完全相同），只改了 `submission.yaml`（模型换 Flash，`COMPACT_AT_TOKENS` 提到 400000；harness 遇到上下文超限会自己压缩，不怕设高）。minimal 版仍保留在 git 历史里（commit `71aac2a`）。

## 已完成（2026-11-19，沙箱内实测）

| 事项 | 结果 |
|---|---|
| 拷出 minimal，`git init`，首次提交 | OK（commit `71aac2a`） |
| `python3 -m py_compile serve.py taskbridge.py` | OK |
| 装 uv 0.13.9 | OK（沙箱内，`~/.local/bin/uv`） |
| `uv run python -m kit check ../my-harness`（在 `~/workspace/kaggle-ple` 内跑） | 部分通过：`[PASS] submission.yaml`；`[FAIL] model：MODEL_PROXY_URL, MODEL_PROXY_KEY 未设置`，到此为止 |
| 底座从 minimal 换成 custom-openai（见上），模型仍为 Flash，`COMPACT_AT_TOKENS` 400000 | `py_compile` OK；`kit check` 仍是 `[PASS] submission.yaml: my-harness: google-cloud/gemini-3.8-flash` + 同一个 model FAIL。**注意：MCP 调用和压缩逻辑只在官方 sample 层面验证过，本仓库的改动（仅 submission.yaml）在真实任务上还没跑过，第一次单任务试跑就是验证。** |

## 卡住的地方（都需要 Jason 在自己的机器上做，沙箱里做不了）

沙箱现状：无 Docker、无 gcloud、无 Harbor。以下三件必须在你的 Mac（或一台云主机）上完成：

### 1. 装 Docker + Harbor
- Docker Desktop：至少 6 CPU、16.25 GB 内存（dev 全集最大任务的需求）；磁盘留 10 GB 以上给基础镜像，rubric 任务的镜像约 17 GB。
- `uv tool install harbor==0.20.0 --with websockets`

### 2. 模型代理（GCP 计费，本地跑的 token 全记在你账上）
```bash
gcloud auth application-default login
export VERTEXAI_PROJECT=<你的 GCP 项目，需开 Vertex AI> MODEL_PROXY_KEY=$(openssl rand -hex 24)
kit/model_proxy/start.sh &   # 监听 0.0.0.0:4000
export MODEL_PROXY_URL=http://localhost:4000
```
说明：`kit/model_proxy/start.sh` 在上游仓库 `~/workspace/kaggle-ple/kit/model_proxy/` 内。

### 3. Hugging Face 数据集权限
- 在 https://huggingface.co/datasets/google/physical-engineerings-last-exam 页面申请访问（gated 数据集）。
- 拿一个 read token，设 `HF_TOKEN`（或跑一次 `uv run hf auth login`）。

## 8GB Mac 方案（2026-11-19 更新：Mac 只有 8GB，不开云主机）

**结论：29 个任务跑不全，但能跑一部分，而且部分提交是允许的。**

- 跑不全的原因：整套 dev 集按最大任务配额要 6 CPU + 16.25GB 内存一个 slot，rubric 任务的镜像约 17GB；8GB Mac 分给 Docker 的只有约 6GB。
- 能跑的：小的 `checks` 任务（12 个，纯文件输出，如 solution.py / submission.zip，不用 17GB 世界镜像）。最小任务规格是 2 CPU / 4GB，`kit check` 的 smoke 测试也是这个规格；实际内存占用通常远小于上限，值得一试。
- 跑不了的：14 个 `rubric` 任务（要世界镜像 + 大内存）。
- 部分提交合法：官方 `docs/artifacts.md` 明确 `eval/run.py --tasks <id>` 跑子集就可以；dev 分是 29 个任务的均分，缺的任务记 0；只有**全部**任务都没有可用 artifacts 时提交才会被拒收。Stage 1 只看 Writeup，Stage 2 是 Google 在他们机器上跑 56 个隐藏任务，不受你的 Mac 限制。所以策略是：Mac 上把能跑的 checks 任务跑完，rubric 的先空着，先交一个能进 Stage 1 的版本。
- 本地验证不用 GCP：临时把 `submission.yaml` 的 `model_api` 改成 `gemini/gemini-3.8-flash`，配 `GEMINI_API_KEY`（Google AI Studio 免费申请），走 `local-validate` 分支，**不要提交到 main**。但注意：最终提交的 `artifacts/` 必须用提交的那个 `google-cloud` 模型实际跑出来，所以验证跑通后，checks 任务还要用 `google-cloud/gemini-3.8-flash` 重跑一次。那一步需要 model proxy（GCP），或者折中办法：本地起 LiteLLM proxy，用 Gemini API key 做后端、名字仍报 `google-cloud/gemini-3.8-flash`（官方文档说任何能提供这些模型名的 OpenAI 兼容 proxy 都行；免费 key 有速率限制，跑得慢，429 会自动重试）。
- 一键安装脚本：`scripts/setup-mac.sh`（装 uv + Harbor，clone 两个仓库，生成 `local.env` 模板；Docker Desktop 需手动装并把内存拉到最大，磁盘至少留 20GB）。

## GitHub Actions 跑（2026-11-19 更新：Jason 不想用 Mac 跑）

沙箱没 Docker、资源不够；改走免费 GitHub Actions runner（公开库免费，标准机 4 vCPU / 16GB 内存 / 约 14GB 磁盘），正好够跑小的 checks 任务。工作流：`.github/workflows/ple-dev.yml`，手动触发（Actions > PLE dev run > Run workflow），默认跑 `roof-deck-design` 一个任务。

- 模型：本地验证路线，工作流自动把 `submission.yaml` 的 `model_api` 改成 `gemini/gemini-3.8-flash`，用 `GEMINI_API_KEY`，不用 GCP。提交用的 artifacts 仍须用 `google-cloud` 模型重跑（见 8GB Mac 方案一节）。
- 需要两个 repo secrets（Settings > Secrets and variables > Actions）：`HF_TOKEN`（HF read token，账号须先在数据集页申请访问）、`GEMINI_API_KEY`（Google AI Studio 免费 key）。值只存在 GitHub，不进代码、不进日志。
- 只跑 checks / checks-judge 任务：rubric 任务要 17GB 世界镜像，runner 磁盘不够。
- 跑完结果在 workflow 的 Artifacts 里下载（`ple-run-<号>`，保留 30 天），确认没问题再 commit 进仓库的 `artifacts/`。

```bash
# 0. 进上游仓库目录（kit 和 eval 都在里面），harness 在隔壁独立仓库
cd ~/workspace/kaggle-ple   # 或你 clone 的 ple 位置

# 1. 环境变量放 local.env（不要进 git，.gitignore 已排除 *.env）
cat > local.env <<'EOF'
MODEL_PROXY_URL=http://localhost:4000
MODEL_PROXY_KEY=<start.sh 那次生成的 key>
HF_TOKEN=<redacted>
EOF

# 2. kit check 跑到 ready to submit
uv run python -m kit check ../my-harness

# 3. 先只跑 1 个任务验证 + 实测 token 消耗（results.json 里有 n_input/n_output_tokens）
uv run python eval/run.py ../my-harness --env-file local.env --tasks data-center-site-model

# 4. 跑满 29 个 dev 任务（串行最长 174 小时；--trials 可并行，量力而行）
uv run python eval/run.py ../my-harness --env-file local.env

# 5. 检查 artifacts 并提交前验证
uv run python -m kit artifacts ../my-harness
uv run python -m kit check ../my-harness   # 确认显示 ready to submit

# 6. 推到 GitHub，再去 Kaggle 写 Writeup（见下）
git -C ../my-harness add -A && git -C ../my-harness commit -m "harness and dev artifacts"
```

## 提交流程（Kaggle 侧）

1. Kaggle 比赛页先完成身份验证（不验证不能提交），接受 Rules。
2. 本仓库推到 GitHub（提交时仓库须公开；若比赛期间设私人，须装 ple-submission GitHub App）。
3. Kaggle → Writeups → New Writeup：Project Links 附 GitHub 链接，顶部放 40 字 commit SHA（`git rev-parse HEAD`），2000 字以内，附 3 张图（架构图、失败分析图、效率图），覆盖 5 项评分标准，Submit。可取消、编辑、重提交直到截止。
4. 评分要求 Writeup 覆盖：Insight & Failure Analysis 25、Engineering Reasoning 25、Cross-Model Generalizability 15（至少 2 个模型跑 29 个 dev 任务）、Efficiency & Scaling 20（dev 分数对计算预算的图）、Clarity & Visuals 15。

## 成本与时间估算（2026-11-19 的评估，实测后以 results.json 为准）

- 你的时间：2–4 周业余，或全职 1–2 周做到可提交。
- 机器时间：单任务上限 6 小时；29 任务串行最长 174 小时，实际多在 1–2 小时/任务。
- Token：论文实测，单任务累计处理量约 27M token（含每轮重发历史上下文）；Opus 跑一轮 29 任务约 7.8 亿 token、约 30 小时。**先拿 Flash 跑 1 个任务实测 results.json 的 n_input/n_output_tokens 再决定。**
- 钱（论文实测，2026-11-19 已修正，旧的 $1,500–8,000/轮粗估作废）：Opus 跑一轮约 $498，按中位数成本约 $192；跑三轮全量约 $1,500。Flash 跑一轮约 $74（29 任务 × 约 $2.55/任务，论文里 Flash 在最优 harness 上 28.2%）。最终排名是 performance-cost Pareto，便宜模型跑出够用的分反而占优。

## 规则红线（违反会取消资格）

- artifacts 必须由 `eval/run.py` 用提交的那个模型实际跑出，不许手写、不许换模型跑。
- harness 不许读评分脚本、不许硬编码答案、不许按任务名分支、不许读自己的 `artifacts/`。
- 评估期间禁用外部 API、外部模型服务器、网络搜索；只许调声明的模型。
- 团队上限 5 人，合并截止 2027-01-05 23:59 UTC。

## 敏感信息

- 本仓库内**没有任何密钥**：`.gitignore` 已排除 `*.env`、`.venv/`、`runs/`。`MODEL_PROXY_KEY`、`HF_TOKEN`、`GEMINI_API_KEY` 一律放 `local.env`（仓库外），绝不提交。
- 8 个可用模型：`google-cloud/gemini-4-argon`、`gemini-3.8-flash`、`gemini-3.1-pro-preview`、`gemma-4-26b`、`claude-opus-5-5`、`gpt-oss-120b`、`glm-5.2`、`llama-4-maverick`。

## 下一步清单（8GB Mac 路线）

- [ ] Mac 上跑 `scripts/setup-mac.sh`（先手动装 Docker Desktop，内存拉到最大，磁盘留 20GB 以上）
- [ ] HF 数据集申请 + token，填进 `kaggle-ple/local.env`
- [ ] Google AI Studio 申请 Gemini API key，填进 `local.env`（本地验证用）
- [ ] `local-validate` 分支：`model_api` 临时改 `gemini/gemini-3.8-flash`，`kit check` 跑到 model 阶段通过
- [ ] 单任务试跑 `roof-deck-design`，记下 results.json 的 token 数，算一轮成本
- [ ] 把能跑的 checks 任务逐个跑完（12 个 checks + 3 个 checks-judge），生成 artifacts/
- [ ] 最终提交前：用 `google-cloud/gemini-3.8-flash`（model proxy，GCP 或 LiteLLM+Gemini key 后端）重跑一遍已跑的任务，生成提交用的 artifacts/
- [ ] `kit artifacts` + `kit check` 确认 ready to submit，推 GitHub
- [ ] 写 Writeup（2000 字 + 3 图），Kaggle 提交
- [ ] 2027-01-05 前最终确认提交

## 关键链接

- 比赛：https://www.kaggle.com/competitions/physical-engineerings-last-exam/overview
- 规则：https://www.kaggle.com/competitions/physical-engineerings-last-exam/rules
- 上游仓库：https://github.com/google-research/ple
- 数据集：https://huggingface.co/datasets/google/physical-engineerings-last-exam
- 论文：https://arxiv.org/abs/2610.30537
