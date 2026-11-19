# 交接文档 — PLE Kaggle 比赛 my-harness

> 日期：2026-11-19
> 状态：脚手架已搭好，**未跑通过**。卡在模型代理和 Docker（见“卡住的地方”）。
> 比赛截止：**2027-01-05 23:59 UTC**（北京时间 2027-01-06 07:59）

## 比赛一句话

Google - Agent Harness on Physical-Engineering's Last Exam（PLE）：做一个开源 agent harness，配 8 个 Google 赞助模型，解 85 个真实工程任务（结构/土木/电气/机械）。不是传统 CSV 预测赛，无排行榜；提交物 = GitHub repo（含 harness + 29 个 dev 任务跑出的 `artifacts/`）+ 2000 字内 Kaggle Writeup。总奖金 $400K（第一 $250K / 第二 $100K / 第三 $50K）。Stage 1 取 Top 100，Stage 2 在 56 个隐藏任务上按 performance-cost Pareto 排名，需 ≥0.138 分才有资格获奖。

详情见 Kaggle：https://www.kaggle.com/competitions/physical-engineerings-last-exam/overview

## 这个仓库是什么

- 来源：`google-research/ple` 的 `sample_submissions/minimal` 原样拷出（官方推荐的从零写 harness 的起点）。
- 模型：`google-cloud/gemini-3.8-flash`（最便宜的赞助模型，先跑通链路用；换模型只改 `submission.yaml` 里的 `model_api`）。
- 结构：`serve.py`（不到 250 行：一个模型 + bash/read_file/write_file 三个工具 + 循环）+ `taskbridge.py`（WebSocket 协议层）+ `submission.yaml` + `requirements.txt`。
- 上游仓库（只读参考，已 clone 在本地，不在本仓库内）：`~/workspace/kaggle-ple`。

## 已完成（2026-11-19，沙箱内实测）

| 事项 | 结果 |
|---|---|
| 拷出 minimal，`git init`，首次提交 | OK（commit `71aac2a`） |
| `python3 -m py_compile serve.py taskbridge.py` | OK |
| 装 uv 0.13.9 | OK（沙箱内，`~/.local/bin/uv`） |
| `uv run python -m kit check ../my-harness`（在 `~/workspace/kaggle-ple` 内跑） | 部分通过：`[PASS] submission.yaml`；`[FAIL] model：MODEL_PROXY_URL, MODEL_PROXY_KEY 未设置`，到此为止 |

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

## 跑通全链路的命令顺序（在能上网、有 Docker 的机器上）

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
- Token：单任务输入几百万 token（多为缓存命中）+ 输出几十万到一两百万 token；一轮 29 任务输入几千万、输出几百万到上千万；跨模型对比要跑两轮。裁判（17 个 rubric/checks-judge 任务）是小头。
- 钱（量级参考，按 Opus 级公开价 $5/$25 每百万 token）：Opus 跑一轮约 $1,500–8,000；Flash 便宜约 10 倍。**先拿 Flash 跑 1–3 个任务测出真实单价再决定。**

## 规则红线（违反会取消资格）

- artifacts 必须由 `eval/run.py` 用提交的那个模型实际跑出，不许手写、不许换模型跑。
- harness 不许读评分脚本、不许硬编码答案、不许按任务名分支、不许读自己的 `artifacts/`。
- 评估期间禁用外部 API、外部模型服务器、网络搜索；只许调声明的模型。
- 团队上限 5 人，合并截止 2027-01-05 23:59 UTC。

## 敏感信息

- 本仓库内**没有任何密钥**：`.gitignore` 已排除 `*.env`、`.venv/`、`runs/`。`MODEL_PROXY_KEY`、`HF_TOKEN`、`GEMINI_API_KEY` 一律放 `local.env`（仓库外），绝不提交。
- 8 个可用模型：`google-cloud/gemini-4-argon`、`gemini-3.8-flash`、`gemini-3.1-pro-preview`、`gemma-4-26b`、`claude-opus-5-5`、`gpt-oss-120b`、`glm-5.2`、`llama-4-maverick`。

## 下一步清单

- [ ] Mac 上装 Docker Desktop + uv + Harbor
- [ ] GCP 项目开 Vertex AI，起 model proxy
- [ ] HF 数据集申请 + token
- [ ] `kit check` 跑到 ready to submit
- [ ] 单任务试跑，记下 results.json 的 token 数，算一轮成本
- [ ] 全量 29 任务跑完，生成 artifacts/
- [ ] （可选）换第二个模型跑 dev 集，做跨模型对比图
- [ ] 写 Writeup（2000 字 + 3 图），Kaggle 提交
- [ ] 2027-01-05 前最终确认提交

## 关键链接

- 比赛：https://www.kaggle.com/competitions/physical-engineerings-last-exam/overview
- 规则：https://www.kaggle.com/competitions/physical-engineerings-last-exam/rules
- 上游仓库：https://github.com/google-research/ple
- 数据集：https://huggingface.co/datasets/google/physical-engineerings-last-exam
- 论文：https://arxiv.org/abs/2610.30537
