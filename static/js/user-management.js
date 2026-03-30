// 用户管理JavaScript

// 页面标题映射
const pageTitles = {
    'user-management': '用户管理'
};

// 刷新用户列表
async function refreshUserList() {
    try {
        const response = await fetch('/api/users');
        
        // 检查登录状态
        if (response.status === 401) {
            alert('登录已过期，请重新登录');
            window.location.href = '/login';
            return;
        }
        
        const data = await response.json();
        
        if (data.success) {
            const tbody = document.querySelector('#users-table tbody');
            tbody.innerHTML = '';
            
            const roleMap = {
                'admin': '<span class="badge badge-admin">管理员</span>',
                'captain': '<span class="badge badge-captain">队长</span>',
                'driver': '<span class="badge badge-driver">司机</span>',
                'employee': '<span class="badge badge-employee">员工</span>'
            };
            
            data.data.forEach(user => {
                const row = document.createElement('tr');
                const lastLogin = user.last_login ? new Date(user.last_login).toLocaleString() : '从未登录';
                const lockedStatus = user.locked_until && new Date(user.locked_until) > new Date() ? 
                    `<span class="status-locked">🔒 已锁定</span>` : '';
                const avatarSrc = user.avatar ? `/static/avatars/${user.avatar}` : 'data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' width=\'40\' height=\'40\'%3E%3Crect fill=\'%23ddd\' width=\'40\' height=\'40\'/%3E%3Ctext x=\'50%25\' y=\'50%25\' dominant-baseline=\'middle\' text-anchor=\'middle\' font-size=\'20\' fill=\'%23999\'%3E👤%3C/text%3E%3C/svg%3E';
                
                row.innerHTML = `
                    <td><img src="${avatarSrc}" alt="头像" class="user-avatar-small" onerror="this.src='data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' width=\'40\' height=\'40\'%3E%3Crect fill=\'%23ddd\' width=\'40\' height=\'40\'/%3E%3Ctext x=\'50%25\' y=\'50%25\' dominant-baseline=\'middle\' text-anchor=\'middle\' font-size=\'20\' fill=\'%23999\'%3E👤%3C/text%3E%3C/svg%3E'"></td>
                    <td>${user.user_id}</td>
                    <td>${user.username}</td>
                    <td>${user.name}</td>
                    <td>${user.gender}</td>
                    <td>${roleMap[user.role] || user.role}</td>
                    <td>
                        <span class="status-${user.is_active ? 'active' : 'inactive'}">
                            ${user.is_active ? '✓ 激活' : '✗ 禁用'}
                        </span>
                        ${lockedStatus}
                    </td>
                    <td>${lastLogin}</td>
                    <td>${user.login_attempts}</td>
                    <td>
                        <button class="btn-small btn-primary" onclick="editUser(${user.user_id})">编辑</button>
                        <button class="btn-small btn-warning" onclick="showResetPassword(${user.user_id}, '${user.username}')">重置密码</button>
                        ${user.locked_until && new Date(user.locked_until) > new Date() ? 
                            `<button class="btn-small btn-success" onclick="unlockUser(${user.user_id})">解锁</button>` : ''}
                        <button class="btn-small btn-danger" onclick="deleteUser(${user.user_id}, '${user.name}')">删除</button>
                    </td>
                `;
                tbody.appendChild(row);
            });
            
            showToast('用户列表已更新', 'success');
        } else {
            showToast(data.message || '获取用户列表失败', 'error');
        }
    } catch (error) {
        console.error('刷新用户列表失败:', error);
        showToast('刷新用户列表失败', 'error');
    }
}

// 编辑用户
async function editUser(userId) {
    try {
        const response = await fetch(`/api/users/${userId}`);
        const data = await response.json();
        
        if (data.success) {
            const user = data.data;
            document.getElementById('editUserId').value = user.user_id;
            document.getElementById('editUsername').value = user.username;
            document.getElementById('editName').value = user.name;
            document.getElementById('editRole').value = user.role;
            document.getElementById('editIsActive').checked = user.is_active;
            document.getElementById('editAvatar').value = user.avatar || '';
            
            // 显示当前头像
            const currentAvatar = document.getElementById('currentAvatar');
            if (user.avatar) {
                currentAvatar.src = `/static/avatars/${user.avatar}`;
            } else {
                currentAvatar.src = 'data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' width=\'60\' height=\'60\'%3E%3Crect fill=\'%23ddd\' width=\'60\' height=\'60\'/%3E%3Ctext x=\'50%25\' y=\'50%25\' dominant-baseline=\'middle\' text-anchor=\'middle\' font-size=\'24\' fill=\'%23999\'%3E👤%3C/text%3E%3C/svg%3E';
            }
            
            // 加载头像列表
            loadAvatars();
            
            document.getElementById('userModal').style.display = 'flex';
        }
    } catch (error) {
        showToast('获取用户信息失败', 'error');
    }
}

// 保存用户
async function saveUser() {
    const userId = document.getElementById('editUserId').value;
    const role = document.getElementById('editRole').value;
    const is_active = document.getElementById('editIsActive').checked;
    const avatar = document.getElementById('editAvatar').value;
    
    try {
        const response = await fetch(`/api/users/${userId}`, {
            method: 'PUT',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({ role, is_active, avatar })
        });
        
        const data = await response.json();
        
        if (data.success) {
            showToast('用户信息已更新', 'success');
            closeUserModal();
            refreshUserList();
        } else {
            showToast(data.message, 'error');
        }
    } catch (error) {
        showToast('保存失败', 'error');
    }
}

// 关闭用户编辑对话框
function closeUserModal() {
    document.getElementById('userModal').style.display = 'none';
}

// 显示重置密码对话框
function showResetPassword(userId, username) {
    document.getElementById('resetUserId').value = userId;
    document.getElementById('resetUsername').textContent = username;
    document.getElementById('newPassword').value = '';
    document.getElementById('confirmNewPassword').value = '';
    document.getElementById('resetPasswordModal').style.display = 'flex';
}

// 关闭重置密码对话框
function closeResetPasswordModal() {
    document.getElementById('resetPasswordModal').style.display = 'none';
}

// 确认重置密码
async function confirmResetPassword() {
    const userId = document.getElementById('resetUserId').value;
    const newPassword = document.getElementById('newPassword').value;
    const confirmPassword = document.getElementById('confirmNewPassword').value;
    
    if (!newPassword || newPassword.length < 6) {
        showToast('密码至少需要6位', 'error');
        return;
    }
    
    if (newPassword !== confirmPassword) {
        showToast('两次输入的密码不一致', 'error');
        return;
    }
    
    try {
        const response = await fetch(`/api/users/${userId}/reset-password`, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({ new_password: newPassword })
        });
        
        const data = await response.json();
        
        if (data.success) {
            showToast('密码重置成功', 'success');
            closeResetPasswordModal();
            refreshUserList();
        } else {
            showToast(data.message, 'error');
        }
    } catch (error) {
        showToast('重置失败', 'error');
    }
}

// 解锁用户
async function unlockUser(userId) {
    if (!confirm('确定要解锁此用户吗？')) return;
    
    try {
        const response = await fetch(`/api/users/unlock/${userId}`, {
            method: 'POST'
        });
        
        const data = await response.json();
        
        if (data.success) {
            showToast('用户已解锁', 'success');
            refreshUserList();
        } else {
            showToast(data.message, 'error');
        }
    } catch (error) {
        showToast('解锁失败', 'error');
    }
}

// 删除用户
async function deleteUser(userId, username) {
    if (!confirm(`确定要删除用户"${username}"吗？此操作不可撤销！`)) return;
    
    try {
        const response = await fetch(`/api/users/${userId}`, {
            method: 'DELETE'
        });
        
        const data = await response.json();
        
        if (data.success) {
            showToast('用户已删除', 'success');
            refreshUserList();
        } else {
            showToast(data.message, 'error');
        }
    } catch (error) {
        showToast('删除失败', 'error');
    }
}

// 加载可用头像列表
async function loadAvatars() {
    try {
        const response = await fetch('/api/avatars');
        const data = await response.json();
        
        if (data.success && data.avatars.length > 0) {
            const avatarGrid = document.getElementById('avatarGrid');
            avatarGrid.innerHTML = '';
            
            data.avatars.forEach(avatar => {
                const avatarItem = document.createElement('div');
                avatarItem.className = 'avatar-item';
                avatarItem.innerHTML = `<img src="/static/avatars/${avatar}" alt="${avatar}">`;
                avatarItem.onclick = () => selectAvatar(avatar);
                avatarGrid.appendChild(avatarItem);
            });
        }
    } catch (error) {
        console.error('加载头像列表失败:', error);
    }
}

// 显示头像选择器
function showAvatarPicker() {
    const picker = document.getElementById('avatarPicker');
    picker.style.display = picker.style.display === 'none' ? 'block' : 'none';
}

// 选择头像
function selectAvatar(avatarFilename) {
    document.getElementById('editAvatar').value = avatarFilename;
    document.getElementById('currentAvatar').src = `/static/avatars/${avatarFilename}`;
    document.getElementById('avatarPicker').style.display = 'none';
    showToast('头像已选择', 'success');
}

// 初始化用户管理页面
document.addEventListener('DOMContentLoaded', function() {
    // 监听页面切换到用户管理时刷新列表
    const observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
            const userManagementPage = document.getElementById('page-user-management');
            if (userManagementPage && userManagementPage.classList.contains('active')) {
                refreshUserList();
            }
        });
    });
    
    const userManagementPage = document.getElementById('page-user-management');
    if (userManagementPage) {
        observer.observe(userManagementPage, {
            attributes: true,
            attributeFilter: ['class']
        });
    }
});
