"""
测试DeepSeek API连接
"""
import requests
import json

# API配置
API_KEY = "sk-00b42e6023f2492cadb7a1a4e7b17e27"
API_URL = "https://api.deepseek.com/v1/chat/completions"

def test_api():
    """测试API连接"""
    print("=" * 60)
    print("DeepSeek API 连接测试")
    print("=" * 60)
    
    # 测试消息
    messages = [
        {"role": "system", "content": "你是一个友好的助手"},
        {"role": "user", "content": "你好，请简单介绍一下自己"}
    ]
    
    print("\n[1] 准备请求...")
    print(f"   API URL: {API_URL}")
    print(f"   API KEY: {API_KEY[:10]}...{API_KEY[-10:]}")
    
    try:
        print("\n[2] 发送请求...")
        response = requests.post(
            API_URL,
            headers={
                'Content-Type': 'application/json',
                'Authorization': f'Bearer {API_KEY}'
            },
            json={
                'model': 'deepseek-chat',
                'messages': messages,
                'temperature': 0.7,
                'max_tokens': 500
            },
            timeout=30
        )
        
        print(f"\n[3] 响应状态码: {response.status_code}")
        
        if response.status_code == 200:
            print("\n✓ API连接成功！")
            result = response.json()
            
            if 'choices' in result and len(result['choices']) > 0:
                reply = result['choices'][0]['message']['content']
                print(f"\n[4] AI回复:")
                print("-" * 60)
                print(reply)
                print("-" * 60)
                print("\n✓ 测试完成，API工作正常！")
            else:
                print("\n× 响应格式异常")
                print(json.dumps(result, indent=2, ensure_ascii=False))
        else:
            print(f"\n× API返回错误: {response.status_code}")
            print(f"   错误详情: {response.text}")
            
            # 常见错误说明
            if response.status_code == 401:
                print("\n⚠ 可能的问题: API密钥无效或已过期")
            elif response.status_code == 429:
                print("\n⚠ 可能的问题: API调用频率超限")
            elif response.status_code == 500:
                print("\n⚠ 可能的问题: DeepSeek服务器错误")
                
    except requests.exceptions.ConnectionError as e:
        print(f"\n× 连接错误: {e}")
        print("\n⚠ 可能的问题:")
        print("   1. 无网络连接")
        print("   2. 需要VPN/代理")
        print("   3. 防火墙阻止")
        print("   4. DNS解析问题")
        
    except requests.exceptions.Timeout:
        print("\n× 请求超时")
        print("\n⚠ 可能的问题:")
        print("   1. 网络速度慢")
        print("   2. API服务响应慢")
        
    except Exception as e:
        print(f"\n× 未知错误: {e}")
        import traceback
        traceback.print_exc()
    
    print("\n" + "=" * 60)

if __name__ == '__main__':
    test_api()
