#!/bin/bash

FILE="${1:-mirror/abhidharma.json}"

if [ ! -f "$FILE" ]; then
    echo "❌ 文件不存在: $FILE"
    exit 1
fi

echo "🔍 验证JSON文件: $FILE"
echo "======================"

# 1. 验证JSON格式
echo "1. 验证JSON格式..."
if jq empty "$FILE" 2>/dev/null; then
    echo "   ✅ 有效的JSON格式"
else
    echo "   ❌ 无效的JSON格式"
    exit 1
fi

# 2. 检查文件大小
SIZE=$(stat -f%z "$FILE" 2>/dev/null || stat -c%s "$FILE")
echo "2. 文件大小: $SIZE 字节"

# 3. 检查数据类型
TYPE=$(jq -r 'type' "$FILE")
echo "3. 数据类型: $TYPE"

# 4. 检查元数据
echo "4. 检查元数据..."
if jq -e '._mirror_info' "$FILE" >/dev/null 2>&1; then
    echo "   ✅ 包含元数据"
    jq '._mirror_info' "$FILE"
else
    echo "   ℹ️  无元数据"
fi

# 5. 数据统计
echo "5. 数据统计:"
case $TYPE in
    "array")
        LENGTH=$(jq '. | length' "$FILE")
        echo "   📊 数组长度: $LENGTH"
        echo "   前3个元素:"
        jq '.[0:3]' "$FILE"
        ;;
    "object")
        KEYS=$(jq '. | keys | length' "$FILE")
        echo "   📊 对象键数: $KEYS"
        echo "   所有键:"
        jq -r '. | keys[]' "$FILE" | head -20
        ;;
    *)
        echo "   📊 其他类型，原始值:"
        jq '.' "$FILE" | head -5
        ;;
esac

echo ""
echo "✅ 验证完成"
