#!/bin/bash
set -e

echo "=========================================="
echo "Moltbook Agent 部署脚本"
echo "Agent 名称: Ariel_K"
echo "=========================================="

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 1. 检查并安装 Node.js
echo -e "${YELLOW}[1/9] 检查 Node.js 环境...${NC}"
if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v)
    echo -e "${GREEN}✓ Node.js 已安装: $NODE_VERSION${NC}"
else
    echo -e "${YELLOW}正在安装 Node.js 20...${NC}"
    curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
    yum install -y nodejs
    echo -e "${GREEN}✓ Node.js 安装完成${NC}"
fi

# 2. 检查并安装必要工具
echo -e "${YELLOW}[2/9] 检查必要工具...${NC}"
if ! command -v curl &> /dev/null; then
    yum install -y curl
fi
if ! command -v jq &> /dev/null; then
    yum install -y jq
fi
echo -e "${GREEN}✓ 工具已就绪${NC}"

# 3. 安装 PM2
echo -e "${YELLOW}[3/9] 安装 PM2 进程管理器...${NC}"
if ! command -v pm2 &> /dev/null; then
    npm install -g pm2
    echo -e "${GREEN}✓ PM2 安装完成${NC}"
else
    echo -e "${GREEN}✓ PM2 已安装${NC}"
fi

# 4. 创建项目目录
echo -e "${YELLOW}[4/9] 创建项目目录...${NC}"
mkdir -p ~/moltbook-agent-ariel
cd ~/moltbook-agent-ariel

# 5. 下载 Moltbook Skill 文件
echo -e "${YELLOW}[5/9] 下载 Moltbook Skill 文件...${NC}"
mkdir -p ~/.moltbot/skills/moltbook
curl -s https://www.moltbook.com/skill.md > ~/.moltbot/skills/moltbook/SKILL.md
curl -s https://www.moltbook.com/heartbeat.md > ~/.moltbot/skills/moltbook/HEARTBEAT.md
curl -s https://www.moltbook.com/messaging.md > ~/.moltbot/skills/moltbook/MESSAGING.md
curl -s https://www.moltbook.com/skill.json > ~/.moltbot/skills/moltbook/package.json
echo -e "${GREEN}✓ Skill 文件下载完成${NC}"

# 6. 注册 Moltbook Agent
echo -e "${YELLOW}[6/9] 注册 Moltbook Agent (Ariel_K)...${NC}"
REGISTER_RESPONSE=$(curl -s -X POST https://www.moltbook.com/api/v1/agents/register \
  -H "Content-Type: application/json" \
  -d '{"name": "Ariel_K", "description": "Meincybo"}')

# 保存注册响应到文件
echo "$REGISTER_RESPONSE" > registration_output.txt
echo "$REGISTER_RESPONSE" | jq '.' 2>/dev/null || echo "$REGISTER_RESPONSE"

# 提取信息
API_KEY=$(echo "$REGISTER_RESPONSE" | jq -r '.agent.api_key // empty' 2>/dev/null)
CLAIM_URL=$(echo "$REGISTER_RESPONSE" | jq -r '.agent.claim_url // empty' 2>/dev/null)
VERIFICATION_CODE=$(echo "$REGISTER_RESPONSE" | jq -r '.agent.verification_code // empty' 2>/dev/null)

if [ -n "$API_KEY" ] && [ "$API_KEY" != "null" ] && [ "$API_KEY" != "" ]; then
    echo -e "${GREEN}✓ 注册成功！${NC}"
    
    # 7. 保存 API Key
    echo -e "${YELLOW}[7/9] 保存 API Key 和配置...${NC}"
    mkdir -p ~/.config/moltbook
    cat > ~/.config/moltbook/credentials.json <<EOF
{
  "api_key": "$API_KEY",
  "agent_name": "Ariel_K",
  "registered_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    chmod 600 ~/.config/moltbook/credentials.json
    
    # 保存详细信息到文件
    cat > ~/MOLTBOOK_CREDENTIALS.txt <<EOF
========================================
Moltbook Agent 认证信息
========================================
Agent Name: Ariel_K
API Key: $API_KEY
Claim URL: $CLAIM_URL
Verification Code: $VERIFICATION_CODE
注册时间: $(date)
========================================

重要提醒：
1. 请妥善保存此文件
2. 访问 Claim URL 完成认证
3. 在 X (Twitter) 发推文包含 Verification Code
========================================
EOF
    
    echo -e "${GREEN}✓ API Key 已保存${NC}"
    echo -e "${GREEN}✓ 完整信息已保存到: ~/MOLTBOOK_CREDENTIALS.txt${NC}"
    
    echo "export MOLTBOOK_API_KEY=\"$API_KEY\"" >> ~/.bashrc
    export MOLTBOOK_API_KEY="$API_KEY"
    
else
    echo -e "${RED}✗ 注册失败${NC}"
    echo "响应内容: $REGISTER_RESPONSE"
    echo -e "${YELLOW}可能原因：${NC}"
    echo "1. Agent 名称 'Ariel_K' 已被使用"
    echo "2. 网络连接问题"
    echo "3. API 服务异常"
    exit 1
fi

# 8. 创建 Agent 应用
echo -e "${YELLOW}[8/9] 创建 Agent 应用...${NC}"

cat > package.json <<'PKGEOF'
{
  "name": "moltbook-agent-ariel",
  "version": "1.0.0",
  "description": "Moltbook Agent - Ariel_K",
  "main": "agent.js",
  "scripts": {
    "start": "node agent.js"
  },
  "dependencies": {
    "axios": "^1.6.2",
    "node-cron": "^3.0.3"
  }
}
PKGEOF

cat > agent.js <<'AGENTEOF'
const axios = require('axios');
const cron = require('node-cron');
const fs = require('fs');
const path = require('path');

const API_BASE = 'https://www.moltbook.com/api/v1';
const CONFIG_PATH = path.join(process.env.HOME, '.config/moltbook/credentials.json');

let config;
try {
    config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
} catch (error) {
    console.error('❌ 无法读取配置:', error.message);
    process.exit(1);
}

const API_KEY = config.api_key;
const AGENT_NAME = config.agent_name;

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

async function checkClaimStatus() {
    console.log('🔍 检查认证状态...');
    const status = await moltbookAPI('/agents/status');
    if (status) {
        console.log('📊 状态:', status.status);
        if (status.status === 'pending_claim') {
            console.log('⚠️  请访问 Claim URL 完成认证');
            console.log('📄 查看详情: cat ~/MOLTBOOK_CREDENTIALS.txt');
        }
        return status.status === 'claimed';
    }
    return false;
}

async function getProfile() {
    console.log('👤 获取个人信息...');
    const profile = await moltbookAPI('/agents/me');
    if (profile && profile.success) {
        console.log(`✅ Agent: ${profile.agent.name}`);
        console.log(`📝 描述: ${profile.agent.description}`);
        console.log(`⭐ Karma: ${profile.agent.karma}`);
        console.log(`👥 关注者: ${profile.agent.follower_count}`);
        console.log(`📅 最后活跃: ${profile.agent.last_active || 'N/A'}`);
    }
    return profile;
}

async function checkFeed() {
    console.log('📰 检查动态...');
    const feed = await moltbookAPI('/feed?sort=hot&limit=10');
    if (feed && feed.success && feed.posts) {
        console.log(`📬 发现 ${feed.posts.length} 条新动态`);
        if (feed.posts.length > 0) {
            console.log('热门帖子：');
            feed.posts.slice(0, 3).forEach((post, i) => {
                console.log(`  ${i + 1}. ${post.title}`);
                console.log(`     👍 ${post.upvotes} | 💬 ${post.comment_count || 0} | 作者: ${post.author.name}`);
            });
        }
    }
    return feed;
}

async function heartbeat() {
    console.log('\n💓 ========== Moltbook Heartbeat ==========');
    console.log(`⏰ 时间: ${new Date().toISOString()}`);
    console.log(`📛 Agent: ${AGENT_NAME}`);
    
    const isClaimed = await checkClaimStatus();
    if (!isClaimed) {
        console.log('⚠️  Agent 尚未被 claim，部分功能受限');
        console.log('💓 ========== Heartbeat 完成 ==========\n');
        return;
    }
    
    await getProfile();
    await checkFeed();
    
    console.log('💓 ========== Heartbeat 完成 ==========\n');
}

async function main() {
    console.log('🦞 ========================================');
    console.log('   Moltbook Agent 启动');
    console.log('========================================');
    console.log(`📛 Agent: ${AGENT_NAME}`);
    console.log(`🔑 API Key: ${API_KEY.substring(0, 20)}...`);
    console.log('========================================\n');
    
    // 立即执行一次
    await heartbeat();
    
    // 设置定时任务：每 4 小时执行一次
    cron.schedule('0 */4 * * *', async () => {
        await heartbeat();
    });
    
    console.log('⏰ 定时任务已设置：每 4 小时检查一次 Moltbook');
    console.log('🔄 Agent 运行中...');
    console.log('📝 查看认证信息: cat ~/MOLTBOOK_CREDENTIALS.txt\n');
}

// 错误处理
process.on('uncaughtException', (error) => {
    console.error('❌ 未捕获的异常:', error);
});

process.on('unhandledRejection', (reason, promise) => {
    console.error('❌ 未处理的 Promise 拒绝:', reason);
});

main();
AGENTEOF

echo "正在安装 Node.js 依赖..."
npm install

echo -e "${GREEN}✓ Agent 应用创建完成${NC}"

# 9. 使用 PM2 启动
echo -e "${YELLOW}[9/9] 启动 Agent...${NC}"
pm2 delete ariel-k-agent 2>/dev/null || true
pm2 start agent.js --name ariel-k-agent
pm2 save
pm2 startup systemd -u root --hp /root

echo ""
echo -e "${GREEN}=========================================="
echo "✅ 部署完成！"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}重要信息已保存到：${NC}"
echo -e "${GREEN}  ~/MOLTBOOK_CREDENTIALS.txt${NC}"
echo ""
echo -e "${YELLOW}查看认证信息：${NC}"
echo "  cat ~/MOLTBOOK_CREDENTIALS.txt"
echo ""
echo -e "${YELLOW}常用命令：${NC}"
echo "  pm2 status              - 查看状态"
echo "  pm2 logs ariel-k-agent  - 查看日志"
echo "  pm2 restart ariel-k-agent - 重启"
echo "  pm2 stop ariel-k-agent    - 停止"
echo ""
echo -e "${BLUE}=========================================="
echo "🎉 重要信息预览："
echo "==========================================${NC}"
echo -e "${GREEN}API Key: $API_KEY${NC}"
echo -e "${GREEN}Claim URL: $CLAIM_URL${NC}"
echo -e "${GREEN}Verification Code: $VERIFICATION_CODE${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""
echo -e "${YELLOW}下一步：${NC}"
echo "1. 访问 Claim URL"
echo "2. 在 X (Twitter) 发推文包含 Verification Code"
echo "3. 完成认证，Agent 即可激活！🦞"
echo ""
