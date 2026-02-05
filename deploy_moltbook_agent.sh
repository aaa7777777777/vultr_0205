#!/bin/bash
set -e

echo "=========================================="
echo "Moltbook Agent 部署脚本"
echo "Agent 名称: Curiosilly1"
echo "=========================================="

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 1. 检查并安装 Node.js
echo -e "${YELLOW}[1/8] 检查 Node.js 环境...${NC}"
if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v)
    echo -e "${GREEN}✓ Node.js 已安装: $NODE_VERSION${NC}"
else
    echo -e "${YELLOW}正在安装 Node.js...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
    echo -e "${GREEN}✓ Node.js 安装完成${NC}"
fi

# 2. 检查并安装 curl
echo -e "${YELLOW}[2/8] 检查 curl...${NC}"
if ! command -v curl &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y curl
fi
echo -e "${GREEN}✓ curl 已就绪${NC}"

# 3. 安装 PM2
echo -e "${YELLOW}[3/8] 安装 PM2 进程管理器...${NC}"
if ! command -v pm2 &> /dev/null; then
    sudo npm install -g pm2
    echo -e "${GREEN}✓ PM2 安装完成${NC}"
else
    echo -e "${GREEN}✓ PM2 已安装${NC}"
fi

# 4. 创建项目目录
echo -e "${YELLOW}[4/8] 创建项目目录...${NC}"
mkdir -p ~/moltbook-agent
cd ~/moltbook-agent

# 5. 下载 Moltbook Skill 文件
echo -e "${YELLOW}[5/8] 下载 Moltbook Skill 文件...${NC}"
mkdir -p ~/.moltbot/skills/moltbook
curl -s https://www.moltbook.com/skill.md > ~/.moltbot/skills/moltbook/SKILL.md
curl -s https://www.moltbook.com/heartbeat.md > ~/.moltbot/skills/moltbook/HEARTBEAT.md
curl -s https://www.moltbook.com/messaging.md > ~/.moltbot/skills/moltbook/MESSAGING.md
curl -s https://www.moltbook.com/skill.json > ~/.moltbot/skills/moltbook/package.json
echo -e "${GREEN}✓ Skill 文件下载完成${NC}"

# 6. 注册 Moltbook Agent
echo -e "${YELLOW}[6/8] 注册 Moltbook Agent...${NC}"
REGISTER_RESPONSE=$(curl -s -X POST https://www.moltbook.com/api/v1/agents/register \
  -H "Content-Type: application/json" \
  -d '{"name": "Curiosilly", "description": "Meincybo"}')

echo "$REGISTER_RESPONSE" | jq '.'

# 提取 API Key
API_KEY=$(echo "$REGISTER_RESPONSE" | jq -r '.agent.api_key')
CLAIM_URL=$(echo "$REGISTER_RESPONSE" | jq -r '.agent.claim_url')
VERIFICATION_CODE=$(echo "$REGISTER_RESPONSE" | jq -r '.agent.verification_code')

if [ "$API_KEY" != "null" ] && [ -n "$API_KEY" ]; then
    echo -e "${GREEN}✓ 注册成功！${NC}"
    
    # 7. 保存 API Key
    echo -e "${YELLOW}[7/8] 保存 API Key...${NC}"
    mkdir -p ~/.config/moltbook
    cat > ~/.config/moltbook/credentials.json <<EOF
{
  "api_key": "$API_KEY",
  "agent_name": "Curiosilly1",
  "registered_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    chmod 600 ~/.config/moltbook/credentials.json
    echo -e "${GREEN}✓ API Key 已保存到 ~/.config/moltbook/credentials.json${NC}"
    
    # 保存到环境变量
    echo "export MOLTBOOK_API_KEY=\"$API_KEY\"" >> ~/.bashrc
    export MOLTBOOK_API_KEY="$API_KEY"
    
    echo ""
    echo -e "${YELLOW}=========================================="
    echo "重要信息 - 请保存！"
    echo "==========================================${NC}"
    echo -e "${GREEN}API Key: $API_KEY${NC}"
    echo -e "${GREEN}Claim URL: $CLAIM_URL${NC}"
    echo -e "${GREEN}Verification Code: $VERIFICATION_CODE${NC}"
    echo ""
    echo -e "${YELLOW}下一步操作：${NC}"
    echo "1. 访问 Claim URL"
    echo "2. 在 X (Twitter) 上发布验证推文"
    echo "3. 包含验证码: $VERIFICATION_CODE"
    echo "=========================================="
    echo ""
    
else
    echo -e "${RED}✗ 注册失败，请检查网络连接或 API 响应${NC}"
    exit 1
fi

# 8. 创建简单的 Agent 应用
echo -e "${YELLOW}[8/8] 创建 Agent 应用...${NC}"

# 创建 package.json
cat > package.json <<'EOF'
{
  "name": "moltbook-agent",
  "version": "1.0.0",
  "description": "Moltbook Agent - Curiosilly1",
  "main": "agent.js",
  "scripts": {
    "start": "node agent.js"
  },
  "dependencies": {
    "axios": "^1.6.2",
    "node-cron": "^3.0.3"
  }
}
EOF

# 创建 Agent 主文件
cat > agent.js <<'AGENTEOF'
const axios = require('axios');
const cron = require('node-cron');
const fs = require('fs');
const path = require('path');

const API_BASE = 'https://www.moltbook.com/api/v1';
const CONFIG_PATH = path.join(process.env.HOME, '.config/moltbook/credentials.json');

// 读取配置
let config;
try {
    config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
} catch (error) {
    console.error('❌ 无法读取配置文件:', error.message);
    process.exit(1);
}

const API_KEY = config.api_key;

// API 请求辅助函数
async function moltbookAPI(endpoint, method = 'GET', data = null) {
    try {
        const response = await axios({
            method,
            url: `${API_BASE}${endpoint}`,
            headers: {
                'Authorization': `Bearer ${API_KEY}`,
                'Content-Type': 'application/json'
            },
            data
        });
        return response.data;
    } catch (error) {
        console.error(`❌ API 错误 [${endpoint}]:`, error.response?.data || error.message);
        return null;
    }
}

// 检查认证状态
async function checkClaimStatus() {
    console.log('🔍 检查认证状态...');
    const status = await moltbookAPI('/agents/status');
    if (status) {
        console.log('📊 状态:', status.status);
        return status.status === 'claimed';
    }
    return false;
}

// 获取个人信息
async function getProfile() {
    console.log('👤 获取个人信息...');
    const profile = await moltbookAPI('/agents/me');
    if (profile && profile.success) {
        console.log(`✅ Agent: ${profile.agent.name}`);
        console.log(`📝 描述: ${profile.agent.description}`);
        console.log(`⭐ Karma: ${profile.agent.karma}`);
        console.log(`👥 关注者: ${profile.agent.follower_count}`);
    }
    return profile;
}

// 查看动态
async function checkFeed() {
    console.log('📰 检查动态...');
    const feed = await moltbookAPI('/feed?sort=hot&limit=10');
    if (feed && feed.success && feed.posts) {
        console.log(`📬 发现 ${feed.posts.length} 条新动态`);
        feed.posts.slice(0, 3).forEach((post, i) => {
            console.log(`  ${i + 1}. ${post.title} (👍 ${post.upvotes})`);
        });
    }
    return feed;
}

// Heartbeat 任务 - 每 4 小时执行一次
async function heartbeat() {
    console.log('\n💓 ========== Moltbook Heartbeat ==========');
    console.log(`⏰ 时间: ${new Date().toISOString()}`);
    
    // 检查是否已认证
    const isClaimed = await checkClaimStatus();
    if (!isClaimed) {
        console.log('⚠️  Agent 尚未被 claim，请先完成认证');
        return;
    }
    
    // 获取个人信息
    await getProfile();
    
    // 查看动态
    await checkFeed();
    
    console.log('💓 ========== Heartbeat 完成 ==========\n');
}

// 主程序
async function main() {
    console.log('🦞 Moltbook Agent 启动');
    console.log(`📛 Agent: Curiosilly`);
    console.log('');
    
    // 立即执行一次
    await heartbeat();
    
    // 设置定时任务：每 4 小时执行一次
    cron.schedule('0 */4 * * *', async () => {
        await heartbeat();
    });
    
    console.log('⏰ 定时任务已设置：每 4 小时检查一次 Moltbook');
    console.log('🔄 Agent 运行中...');
}

main();
AGENTEOF

# 安装依赖
echo "正在安装 Node.js 依赖..."
npm install

echo -e "${GREEN}✓ Agent 应用创建完成${NC}"

# 使用 PM2 启动
echo -e "${YELLOW}启动 Agent...${NC}"
pm2 delete moltbook-agent 2>/dev/null || true
pm2 start agent.js --name moltbook-agent
pm2 save
pm2 startup

echo ""
echo -e "${GREEN}=========================================="
echo "✅ 部署完成！"
echo "==========================================${NC}"
echo ""
echo "常用命令："
echo "  pm2 status          - 查看运行状态"
echo "  pm2 logs            - 查看日志"
echo "  pm2 restart moltbook-agent - 重启 Agent"
echo "  pm2 stop moltbook-agent    - 停止 Agent"
echo ""
echo -e "${YELLOW}请访问 Claim URL 完成认证：${NC}"
echo "$CLAIM_URL"
echo ""
echo -e "${GREEN}Agent 正在运行，每 4 小时会自动检查 Moltbook！🦞${NC}"
