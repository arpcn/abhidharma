#!/usr/bin/env python3
"""
JSON文件镜像备份脚本
"""

import os
import json
import sys
import requests
from datetime import datetime
from pathlib import Path

# 配置
JSON_URL = 'https://publish-01.obsidian.md/cache/39a393bd37490e3597370f63f89358a6'
MIRROR_DIR = Path('mirror')
MIRROR_FILE = MIRROR_DIR / 'abhidharma.json'

def fetch_json(url):
    """获取JSON数据"""
    try:
        print(f"📥 正在获取JSON数据: {url}")
        response = requests.get(url, timeout=15)
        response.raise_for_status()
        
        # 验证JSON格式
        data = response.json()
        print(f"✅ JSON获取成功，类型: {type(data).__name__}")
        
        if isinstance(data, list):
            print(f"📊 数组长度: {len(data)}")
        elif isinstance(data, dict):
            print(f"📊 对象键数量: {len(data)}")
        
        return {
            'success': True,
            'data': data,
            'raw_text': response.text,
            'size': len(response.text),
            'content_type': response.headers.get('Content-Type', ''),
            'etag': response.headers.get('ETag', '')
        }
    except json.JSONDecodeError as e:
        print(f"❌ JSON解析失败: {e}")
        return {'success': False, 'error': f'JSON解析失败: {e}'}
    except Exception as e:
        print(f"❌ 获取失败: {e}")
        return {'success': False, 'error': str(e)}

def save_json_files(data):
    """保存JSON文件的不同版本"""
    # 确保目录存在
    MIRROR_DIR.mkdir(exist_ok=True)
    
    timestamp = datetime.utcnow().isoformat() + 'Z'
    metadata = {
        '_mirror_info': {
            'last_updated': timestamp,
            'source_url': JSON_URL,
            'format_version': '1.0'
        }
    }
    
    # 1. 标准JSON文件（带元数据）
    if isinstance(data, dict):
        data_with_meta = {**data, **metadata}
    elif isinstance(data, list):
        data_with_meta = {
            '_entries': data,
            **metadata
        }
    else:
        data_with_meta = {
            '_data': data,
            **metadata
        }
    
    with open(MIRROR_FILE, 'w', encoding='utf-8') as f:
        json.dump(data_with_meta, f, ensure_ascii=False, indent=2)
    
    print(f"💾 标准JSON已保存: {MIRROR_FILE}")
    
    # 2. 压缩版本（无空格）
    min_file = MIRROR_DIR / 'abhidharma.min.json'
    with open(min_file, 'w', encoding='utf-8') as f:
        json.dump(data_with_meta, f, ensure_ascii=False, separators=(',', ':'))
    
    # 3. 纯数据版本（无元数据）
    pure_file = MIRROR_DIR / 'abhidharma.data.json'
    with open(pure_file, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    # 4. 创建统计信息
    create_stats_file(data)
    
    return {
        'standard': MIRROR_FILE,
        'minified': min_file,
        'data_only': pure_file,
        'size': os.path.getsize(MIRROR_FILE)
    }

def create_stats_file(data):
    """创建统计信息文件"""
    stats = {
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'source': JSON_URL,
        'stats': {}
    }
    
    if isinstance(data, list):
        stats['stats']['type'] = 'array'
        stats['stats']['length'] = len(data)
        
        # 分析前几个元素的类型
        if data:
            sample_types = []
            for i, item in enumerate(data[:5]):
                sample_types.append({
                    'index': i,
                    'type': type(item).__name__
                })
            stats['stats']['sample_types'] = sample_types
            
    elif isinstance(data, dict):
        stats['stats']['type'] = 'object'
        stats['stats']['keys'] = list(data.keys())
        stats['stats']['key_count'] = len(data)
    
    stats_file = MIRROR_DIR / 'stats.json'
    with open(stats_file, 'w', encoding='utf-8') as f:
        json.dump(stats, f, ensure_ascii=False, indent=2)
    
    # 创建Markdown格式的统计
    md_file = MIRROR_DIR / 'STATS.md'
    with open(md_file, 'w', encoding='utf-8') as f:
        f.write(f"# JSON镜像统计\n\n")
        f.write(f"- **最后更新**: {stats['timestamp']}\n")
        f.write(f"- **源地址**: {stats['source']}\n")
        f.write(f"- **数据类型**: {stats['stats'].get('type', 'unknown')}\n")
        
        if 'length' in stats['stats']:
            f.write(f"- **数组长度**: {stats['stats']['length']}\n")
        elif 'key_count' in stats['stats']:
            f.write(f"- **对象键数**: {stats['stats']['key_count']}\n")
        
        f.write(f"\n## 可用的JSON文件\n")
        f.write(f"1. `abhidharma.json` - 完整版（带元数据）\n")
        f.write(f"2. `abhidharma.min.json` - 压缩版\n")
        f.write(f"3. `abhidharma.data.json` - 纯数据版\n")
        f.write(f"4. `stats.json` - 统计信息\n")
    
    print(f"📊 统计文件已创建")

def compare_json(old_data, new_data):
    """比较JSON数据是否变化"""
    import json
    
    # 简单比较：转换为字符串比较（忽略元数据）
    def clean_data(data):
        """清理数据，移除镜像元数据"""
        if isinstance(data, dict):
            cleaned = {k: v for k, v in data.items() 
                      if not k.startswith('_mirror_')}
            return json.dumps(cleaned, sort_keys=True)
        return json.dumps(data, sort_keys=True)
    
    old_clean = clean_data(old_data)
    new_clean = clean_data(new_data)
    
    return old_clean != new_clean

def main():
    """主函数"""
    print("🚀 开始JSON镜像备份")
    print("=" * 50)
    
    # 获取JSON数据
    result = fetch_json(JSON_URL)
    if not result['success']:
        print(f"❌ 失败: {result['error']}")
        sys.exit(1)
    
    # 检查现有文件
    old_data = None
    if MIRROR_FILE.exists():
        try:
            with open(MIRROR_FILE, 'r', encoding='utf-8') as f:
                old_data = json.load(f)
        except:
            pass
    
    # 比较数据
    if old_data and not compare_json(old_data, result['data']):
        print("📝 JSON数据无变化，跳过更新")
        sys.exit(0)
    
    # 保存文件
    saved_files = save_json_files(result['data'])
    
    print("\n" + "=" * 50)
    print("🎉 JSON镜像备份完成")
    print(f"📁 保存位置: {MIRROR_DIR}/")
    print(f"📏 文件大小: {saved_files['size']} 字节")
    
    # 显示文件列表
    print("\n📋 生成的文件:")
    for file in MIRROR_DIR.glob('*'):
        size = file.stat().st_size
        print(f"  - {file.name} ({size:,} 字节)")

if __name__ == "__main__":
    main()
