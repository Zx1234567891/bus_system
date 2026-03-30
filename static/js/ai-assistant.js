// AI智能助手功能（支持自然语言数据库查询）

let chatHistory = [];
let isProcessing = false;

// 初始化
document.addEventListener('DOMContentLoaded', function() {
    const aiInput = document.getElementById('ai-input');

    if (aiInput) {
        // Enter键发送，Shift+Enter换行
        aiInput.addEventListener('keydown', function(e) {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                sendMessage();
            }
        });

        // 自动调整输入框高度
        aiInput.addEventListener('input', function() {
            this.style.height = 'auto';
            this.style.height = Math.min(this.scrollHeight, 200) + 'px';
        });
    }
});

// 发送建议问题
function sendSuggestion(question) {
    const aiInput = document.getElementById('ai-input');
    aiInput.value = question;
    sendMessage();
}

// 发送消息（流式输出）
async function sendMessage() {
    if (isProcessing) return;

    const aiInput = document.getElementById('ai-input');
    const message = aiInput.value.trim();

    if (!message) return;

    // 清空输入框
    aiInput.value = '';
    aiInput.style.height = 'auto';

    // 隐藏欢迎界面
    const welcome = document.querySelector('.ai-welcome');
    if (welcome) {
        welcome.style.display = 'none';
    }

    // 添加用户消息
    addMessage('user', message);

    // 添加AI消息容器（用于流式显示）
    const chatContainer = document.getElementById('ai-chat-container');
    const messageDiv = document.createElement('div');
    messageDiv.className = 'ai-message assistant';
    messageDiv.innerHTML = `
        <div class="ai-avatar assistant">🤖</div>
        <div class="ai-message-content">
            <div class="ai-loading-dots" style="display: inline-flex; gap: 4px;">
                <div class="ai-loading-dot"></div>
                <div class="ai-loading-dot"></div>
                <div class="ai-loading-dot"></div>
            </div>
        </div>
    `;
    chatContainer.appendChild(messageDiv);
    chatContainer.scrollTop = chatContainer.scrollHeight;

    const contentDiv = messageDiv.querySelector('.ai-message-content');

    isProcessing = true;
    document.getElementById('ai-send-btn').disabled = true;

    try {
        // 使用EventSource接收流式数据
        const response = await fetch('/api/ai-chat', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                message: message,
                history: chatHistory
            })
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        // 移除加载动画
        contentDiv.innerHTML = '';

        let fullContent = '';
        const reader = response.body.getReader();
        const decoder = new TextDecoder();

        while (true) {
            const { done, value } = await reader.read();

            if (done) break;

            // 解码数据块
            const chunk = decoder.decode(value, { stream: true });
            const lines = chunk.split('\n');

            for (const line of lines) {
                if (line.startsWith('data: ')) {
                    const dataStr = line.substring(6);

                    try {
                        const data = JSON.parse(dataStr);

                        // 处理错误
                        if (data.error) {
                            contentDiv.innerHTML = `<span style="color: var(--danger-color);">错误: ${data.error}</span>`;
                            break;
                        }

                        // 处理增量内容
                        if (data.content) {
                            fullContent += data.content;
                            contentDiv.innerHTML = formatMessage(fullContent);

                            // 自动滚动
                            chatContainer.scrollTop = chatContainer.scrollHeight;
                        }

                        // 处理完成
                        if (data.done) {
                            // 更新历史记录
                            chatHistory = data.history || chatHistory;
                        }
                    } catch (e) {
                        // JSON解析错误，忽略
                        console.warn('Parse error:', e);
                    }
                }
            }
        }

        // 如果没有内容，显示错误
        if (!fullContent) {
            contentDiv.innerHTML = '<span style="color: var(--danger-color);">未收到回复，请重试</span>';
        }

    } catch (error) {
        // 显示错误
        contentDiv.innerHTML = `<span style="color: var(--danger-color);">网络错误: ${error.message}</span>`;
        console.error('AI Chat Error:', error);
    } finally {
        isProcessing = false;
        document.getElementById('ai-send-btn').disabled = false;
        aiInput.focus();
    }
}

// 添加消息到聊天
function addMessage(role, content) {
    const chatContainer = document.getElementById('ai-chat-container');

    const messageDiv = document.createElement('div');
    messageDiv.className = `ai-message ${role}`;

    const avatar = role === 'user' ? '👤' : '🤖';
    const avatarClass = role === 'user' ? 'user' : 'assistant';

    // 将内容转换为HTML（支持Markdown格式）
    const htmlContent = formatMessage(content);

    messageDiv.innerHTML = `
        <div class="ai-avatar ${avatarClass}">${avatar}</div>
        <div class="ai-message-content">${htmlContent}</div>
    `;

    chatContainer.appendChild(messageDiv);
    chatContainer.scrollTop = chatContainer.scrollHeight;
}

// 添加错误消息
function addError(message) {
    const chatContainer = document.getElementById('ai-chat-container');

    const errorDiv = document.createElement('div');
    errorDiv.className = 'ai-error';
    errorDiv.innerHTML = `
        <span>⚠️</span>
        <span>${message}</span>
    `;

    chatContainer.appendChild(errorDiv);
    chatContainer.scrollTop = chatContainer.scrollHeight;
}

// 格式化消息（增强Markdown支持，含表格渲染）
function formatMessage(text) {
    // 转义HTML
    text = text.replace(/&/g, '&amp;')
               .replace(/</g, '&lt;')
               .replace(/>/g, '&gt;');

    // 代码块（带语言标识）
    text = text.replace(/```(\w*)\s*\n?([\s\S]*?)```/g, function(match, lang, code) {
        const langLabel = lang ? `<span class="code-lang">${lang}</span>` : '';
        return `<pre class="code-block">${langLabel}<code>${code.trim()}</code></pre>`;
    });

    // 行内代码
    text = text.replace(/`([^`]+)`/g, '<code class="inline-code">$1</code>');

    // 粗体
    text = text.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');

    // 斜体
    text = text.replace(/\*(.+?)\*/g, '<em>$1</em>');

    // 水平线
    text = text.replace(/^---$/gm, '<hr style="border:none;border-top:1px solid var(--border-color);margin:12px 0;">');

    // Markdown表格渲染
    text = renderMarkdownTables(text);

    // 列表项
    text = text.replace(/^[\-\*] (.+)$/gm, '<li>$1</li>');
    // 把连续的li包裹成ul
    text = text.replace(/((?:<li>.*?<\/li>\s*)+)/g, '<ul>$1</ul>');

    // 数字列表
    text = text.replace(/^\d+\. (.+)$/gm, '<li>$1</li>');

    // 换行
    text = text.replace(/\n\n/g, '</p><p>');
    text = '<p>' + text + '</p>';

    // 清理空段落
    text = text.replace(/<p><\/p>/g, '');

    return text;
}

// 渲染Markdown表格
function renderMarkdownTables(text) {
    // 匹配Markdown表格: | ... | ... | \n | --- | --- | \n | ... | ... |
    const tableRegex = /(\|[^\n]+\|\s*\n\|[\s\-:|]+\|\s*\n(?:\|[^\n]+\|\s*\n?)*)/g;

    return text.replace(tableRegex, function(tableStr) {
        const lines = tableStr.trim().split('\n').filter(l => l.trim());
        if (lines.length < 3) return tableStr;

        // 解析表头
        const headers = lines[0].split('|').filter(c => c.trim()).map(c => c.trim());
        // 跳过分隔行 lines[1]
        // 解析数据行
        const rows = [];
        for (let i = 2; i < lines.length; i++) {
            const cells = lines[i].split('|').filter(c => c.trim() !== '').map(c => c.trim());
            if (cells.length > 0) {
                rows.push(cells);
            }
        }

        // 构建HTML表格
        let html = '<div class="ai-table-wrapper"><table class="ai-result-table">';
        html += '<thead><tr>';
        headers.forEach(h => {
            html += `<th>${h}</th>`;
        });
        html += '</tr></thead><tbody>';

        rows.forEach(row => {
            html += '<tr>';
            for (let i = 0; i < headers.length; i++) {
                html += `<td>${row[i] || ''}</td>`;
            }
            html += '</tr>';
        });

        html += '</tbody></table></div>';
        return html;
    });
}

// 清空对话
function clearChat() {
    if (!confirm('确定要清空所有对话吗？')) {
        return;
    }

    const chatContainer = document.getElementById('ai-chat-container');
    chatContainer.innerHTML = `
        <div class="ai-welcome">
            <div class="ai-welcome-icon">🤖</div>
            <h4>您好！我是公交安全管理系统智能助手</h4>
            <p>我可以帮助您查询和管理数据库信息，试试用自然语言提问：</p>
            <div class="ai-suggestions">
                <button class="suggestion-btn" onclick="sendSuggestion('查询第一车队的所有司机')">🔍 查询第一车队的所有司机</button>
                <button class="suggestion-btn" onclick="sendSuggestion('统计各车队的违章次数')">📊 统计各车队的违章次数</button>
                <button class="suggestion-btn" onclick="sendSuggestion('查询司机赵大勇的违章记录')">📋 查询司机赵大勇的违章记录</button>
                <button class="suggestion-btn" onclick="sendSuggestion('显示所有运营中的车辆信息')">🚍 显示所有运营中的车辆信息</button>
                <button class="suggestion-btn" onclick="sendSuggestion('如何录入司机信息？')">📝 如何录入司机信息？</button>
                <button class="suggestion-btn" onclick="sendSuggestion('系统有哪些功能？')">💡 系统有哪些功能？</button>
            </div>
        </div>
    `;

    chatHistory = [];
    showToast('对话已清空', 'success');
}
