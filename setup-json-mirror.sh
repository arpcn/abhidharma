#!/bin/bash

echo "🚀 设置JSON镜像备份"
echo "======================"

# 1. 创建工作流目录
mkdir -p .github/workflows mirror

# 2. 创建JSON镜像工作流
cat > .github/workflows/json-mirror.yml << 'EOF'
name: JSON Mirror Backup

on:
  schedule:
    - cron: '0 */4 * * *'
  workflow_dispatch:

jobs:
  update-json:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
        
      - name: Setup jq
        run: sudo apt-get install -y jq
        
      - name: Download JSON
        run: |
          URL="https://publish-01.obsidian.md/cache/39a393bd37490e3597370f63f89358a6"
          mkdir -p mirror
          
          # 下载并验证
          curl -s -L -o mirror/abhidharma.json "$URL"
          
          if ! jq empty mirror/abhidharma.json 2>/dev/null; then
            echo "❌ 无效的JSON"
            exit 1
          fi
          
          # 格式化
          jq . mirror/abhidharma.json > mirror/abhidharma.pretty.json
          
          # 压缩版本
          jq -c . mirror/abhidharma.json > mirror/abhidharma.min.json
          
      - name: Add Metadata
        run: |
          TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
          jq --arg ts "$TIMESTAMP" --arg url "$URL" \
            '._mirror_info = {"last_updated": $ts, "source": $url}' \
            mirror/abhidharma.json > mirror/abhidharma.json.tmp
          mv mirror/abhidharma.json.tmp mirror/abhidharma.json
          
      - name: Create Info File
        run: |
          cat > mirror/README.md << 'EOM'
          # JSON镜像文件
          
          ## 文件说明
          - `abhidharma.json` - 完整JSON（带元数据）
          - `abhidharma.pretty.json` - 格式化版本
          - `abhidharma.min.json` - 压缩版本
          
          ## 使用
          ```javascript
          // 浏览器
          fetch('./mirror/abhidharma.json')
            .then(r => r.json())
            .then(data => console.log(data))
          
          // Node.js
          const data = require('./mirror/abhidharma.json')
          ```
          EOM
          
      - name: Commit Changes
        run: |
          git config user.email "json-bot@github.com"
          git config user.name "JSON Mirror Bot"
          git add mirror/
          git diff --staged --quiet || git commit -m "🔄 更新JSON镜像 $(date +'%Y-%m-%d %H:%M')"
          git push
EOF

# 3. 创建本地脚本
cat > scripts/json-mirror.sh << 'EOF'
#!/bin/bash
# JSON镜像备份脚本
URL="https://publish-01.obsidian.md/cache/39a393bd37490e3597370f63f89358a6"
curl -s "$URL" | jq . > mirror/abhidharma.json
echo "✅ JSON已保存到 mirror/abhidharma.json"
EOF

chmod +x scripts/json-mirror.sh

# 4. 创建测试脚本
cat > test-json.sh << 'EOF'
#!/bin/bash
echo "测试JSON下载..."
curl -s "https://publish-01.obsidian.md/cache/39a393bd37490e3597370f63f89358a6" | \
  jq -r 'if type=="array" then "数组，长度: " + (length|tostring) 
         elif type=="object" then "对象，键数: " + (keys|length|tostring)
         else "其他类型: " + type end'
EOF
chmod +x test-json.sh

# 5. 创建package.json（如果需要）
cat > package.json << 'EOF'
{
  "name": "json-mirror-backup",
  "version": "1.0.0",
  "scripts": {
    "backup": "bash scripts/json-mirror.sh",
    "test": "bash test-json.sh"
  }
}
EOF

echo "✅ 设置完成！"
echo ""
echo "下一步操作："
echo "1. 安装jq（如果需要）: sudo apt-get install jq 或 brew install jq"
echo "2. 测试: ./test-json.sh"
echo "3. 手动备份: ./scripts/json-mirror.sh"
echo "4. 提交: git add . && git commit -m '添加JSON镜像备份'"
echo "5. 推送: git push"
echo ""
echo "🚀 GitHub Actions将在每4小时自动运行"
echo "🔗 手动触发: 仓库 → Actions → JSON Mirror Backup → Run workflow"
