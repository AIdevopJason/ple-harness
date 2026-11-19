#!/usr/bin/env bash
# PLE my-harness — Mac 安装脚本（8GB 内存版）
#
# 用法：在 Mac 终端里跑：  bash scripts/setup-mac.sh
# 做什么：装 uv + Harbor，clone 上游 ple 仓库和 my-harness，生成 local.env 模板。
# 不做什么：不装 Docker（见下），不碰你的密钥。
#
# 前置（你手动做一次）：
#   1. 装 Docker Desktop：https://www.docker.com/products/docker-desktop/
#      装好后打开它，Settings > Resources > Memory 拉到最大（8GB 机器约 6GB），
#      磁盘至少留 20GB 空闲。等右下角变绿（engine running）再往下走。
#   2. HF 数据集申请：https://huggingface.co/datasets/google/physical-engineerings-last-exam
#      点 Request access，通过后在 https://huggingface.co/settings/tokens 建一个 read token。
#   3. Gemini API key（免费，本地验证用，不用 GCP）：
#      https://aistudio.google.com/apikey 建一个 key。
#   4. 把下面两个值填进 local.env（脚本会帮你建模板，你只填值；不要提交进 git）。
set -euo pipefail

echo "== 1. 检查机器 =="
echo "内存： $(sysctl -n hw.memsize 2>/dev/null | awk '{print $1/1024/1024/1024" GB"}' 2>/dev/null || echo 未知)"
echo "CPU： $(sysctl -n hw.ncpu) 核"
echo "磁盘可用： $(df -h ~ | awk 'NR==2 {print $4}')"
echo "注意：8GB Mac 跑不全 29 个任务（整套要 16.25GB 内存 + 17GB rubric 镜像），"
echo "但小的 checks 任务（纯文件输出）大概率能跑；rubric 任务先空着，部分提交是允许的。"
echo

echo "== 2. 装 uv =="
if command -v uv >/dev/null 2>&1; then
  echo "uv 已装： $(uv --version)"
else
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
  echo "uv 已装： $(uv --version)"
fi

echo "== 3. 装 Harbor 0.20.0 =="
if uv tool list 2>/dev/null | grep -q "harbor"; then
  echo "harbor 已装"
else
  uv tool install harbor==0.20.0 --with websockets
fi

echo "== 4. 检查 Docker =="
if docker info >/dev/null 2>&1; then
  echo "Docker 已就绪： $(docker --version)"
else
  echo "Docker 还没就绪：请先装 Docker Desktop 并打开，等 engine running 后再跑一次本脚本。"
fi

echo "== 5. Clone 仓库 =="
cd ~/workspace 2>/dev/null || mkdir -p ~/workspace && cd ~/workspace
[ -d kaggle-ple ] || git clone --depth 1 https://github.com/google-research/ple kaggle-ple
[ -d my-harness ] || git clone https://github.com/AIdevopJason/ple-harness my-harness
echo "仓库就绪： ~/workspace/kaggle-ple  ~/workspace/my-harness"

echo "== 6. local.env 模板 =="
if [ ! -f kaggle-ple/local.env ]; then
  cat > kaggle-ple/local.env <<'EOF'
# 填好下面两行，不要提交进 git（.gitignore 已排除 *.env）
HF_TOKEN=<你的 Hugging Face read token>
GEMINI_API_KEY=<你的 Google AI Studio key>
# 提交用的 google-cloud 模型要走 model proxy（需 GCP，见 HANDOVER.md）；本地验证先用 Gemini key。
EOF
  echo "已建 kaggle-ple/local.env，填好 HF_TOKEN 和 GEMINI_API_KEY 后继续。"
else
  echo "kaggle-ple/local.env 已存在，跳过。"
fi

echo
echo "== 下一步（在 ~/workspace/kaggle-ple 里跑） =="
cat <<'EOF'
# 1. 本地验证：临时把模型换成 gemini/gemini-3.8-flash（只改本地，不提交）
cd ~/workspace/my-harness && git checkout -b local-validate
#   把 submission.yaml 里的 model_api 改成 gemini/gemini-3.8-flash
# 2. kit check（会卡在 Docker 阶段就说明 Docker 还没好）
cd ~/workspace/kaggle-ple
uv run python -m kit check ../my-harness
# 3. 跑 1 个小任务验证（checks 类，不用 17GB 镜像）
uv run python eval/run.py ../my-harness --env-file local.env --tasks roof-deck-design
# 4. 看 results.json 里的 n_input/n_output_tokens，算一轮成本；再决定跑哪些任务
EOF
