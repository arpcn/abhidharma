#!/bin/bash

# 配置
JSON_URL="https://publish-01.obsidian.md/cache/39a393bd37490e3597370f63f89358a6"
MIRROR_DIR="mirror"
BACKUP_FILE="$MIRROR_DIR/abhidharma.json"
TEMP_FILE="/tmp/abhidharma_temp.json"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 开始JSON镜像备份${NC}"
echo "========================================"

# 创建目录
mkdir -p "$MIRROR_DIR"

# 下载JSON文件
echo -e "${YELLOW}📥 下载JSON文件...${NC}"
curl -s -L -o "$TEMP_FILE" "$JSON_URL"

# 检查下载是否成功
if [ ! -s "$TEMP_FILE" ]; then
    echo -e "${RED}❌ 下载失败，文件为空${NC}"
    exit 1
fi

# 验证JSON格式
echo -e "${YELLOW}🔍 验证JSON格式...${NC}"
if ! jq empty "$TEMP_FILE" 2>/dev/null; then
    echo -e "${RED}❌ 无效的JSON格式${NC}"
    echo "前100个字符:"
    head -c 100 "$TEMP_FILE"
    echo ""
    exit 1
fi

# 格式化JSON
echo -e "${YELLOW}🎨 格式化JSON...${NC}"
jq . "$TEMP_FILE" > "$TEMP_FILE.formatted"

# 检查文件大小
FILESIZE=$(stat -f%z "$TEMP_FILE.formatted" 2>/dev/null || stat -c%s "$TEMP_FILE.formatted")
echo -e "${GREEN}✅ JSON大小: ${FILESIZE} 字节${NC}"

# 提取基本信息
echo -e "${YELLOW}📊 分析JSON结构...${NC}"
JSON_TYPE=$(jq -r 'type' "$TEMP_FILE.formatted")
echo "数据类型: $JSON_TYPE"

if [ "$JSON_TYPE" = "array" ]; then
    LENGTH=$(jq '. | length' "$TEMP_FILE.formatted")
    echo "数组长度: $LENGTH"
    
    # 显示前3个元素的信息
    echo "前3个元素类型:"
    jq '.[0:3] | map(type)' "$TEMP_FILE.formatted"
    
elif [ "$JSON_TYPE" = "object" ]; then
    KEYS_COUNT=$(jq '. | keys | length' "$TEMP_FILE.formatted")
    echo "对象键数量: $KEYS_COUNT"
    
    # 显示所有键
    echo "所有键:"
    jq -r '. | keys[]' "$TEMP_FILE.formatted" | head -10
    if [ $KEYS_COUNT -gt 10 ]; then
        echo "... 还有 $((KEYS_COUNT - 10)) 个键"
    fi
fi

# 检查是否有变化
if [ -f "$BACKUP_FILE" ]; then
    echo -e "${YELLOW}🔍 检查数据变化...${NC}"
    
    # 比较格式化后的JSON（忽略空格差异）
    if cmp -s <(jq -c . "$TEMP_FILE.formatted") <(jq -c . "$BACKUP_FILE"); then
        echo -e "${GREEN}📝 JSON数据无变化，跳过更新${NC}"
        rm "$TEMP_FILE" "$TEMP_FILE.formatted"
        exit 0
    else
        echo -e "${YELLOW}🔄 检测到数据变化，准备更新${NC}"
    fi
else
    echo -e "${YELLOW}📄 首次备份，创建新文件${NC}"
fi

# 添加元数据
echo -e "${YELLOW}📝 添加元数据...${NC}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
METADATA=$(cat << EOF
{
  "_mirror_info": {
    "last_updated": "$TIMESTAMP",
    "source_url": "$JSON_URL",
    "backup_tool": "json-mirror.sh"
  }
}
EOF
)

# 合并数据
if [ "$JSON_TYPE" = "object" ]; then
    # 如果是对象，合并元数据
    jq --argjson meta "$METADATA" '. + $meta' "$TEMP_FILE.formatted" > "$BACKUP_FILE"
else
    # 如果是数组或其他，包装一下
    jq --argjson meta "$METADATA" '{data: ., _mirror_info: $meta._mirror_info}' "$TEMP_FILE.formatted" > "$BACKUP_FILE"
fi

# 创建其他版本
echo -e "${YELLOW}💾 创建多版本文件...${NC}"

# 1. 压缩版本
jq -c . "$BACKUP_FILE" > "$MIRROR_DIR/abhidharma.min.json"

# 2. 纯数据版本（无元数据）
cp "$TEMP_FILE.formatted" "$MIRROR_DIR/abhidharma.data.json"

# 3. 创建统计文件
create_stats() {
    STATS_FILE="$MIRROR_DIR/stats.json"
    cat > "$STATS_FILE" << EOF
{
  "backup_info": {
    "timestamp": "$TIMESTAMP",
    "source": "$JSON_URL",
    "file_size": $FILESIZE,
    "data_type": "$JSON_TYPE"
  },
  "files": {
    "main": "abhidharma.json",
    "minified": "abhidharma.min.json",
    "raw_data": "abhidharma.data.json"
  }
}
EOF
    echo -e "${GREEN}📊 统计文件已创建${NC}"
}

create_stats

# 清理临时文件
rm "$TEMP_FILE" "$TEMP_FILE.formatted"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ JSON镜像备份完成！${NC}"
echo -e "${GREEN}📁 文件位置: $MIRROR_DIR/${NC}"
echo ""
echo -e "${BLUE}📋 生成的文件:${NC}"
ls -lh "$MIRROR_DIR/" | tail -n +2
echo ""
echo -e "${BLUE}🔗 主文件:${NC} $BACKUP_FILE"
echo -e "${BLUE}⏰ 更新时间:${NC} $TIMESTAMP"
