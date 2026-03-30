/**
 * 公交安全管理系统 - 前端JavaScript
 */

// ==================== 全局变量 ====================
let fleets = [];
let routes = [];
let drivers = [];
let buses = [];
let violationTypes = [];
let stations = [];
let managers = [];

// ==================== 页面初始化 ====================
document.addEventListener('DOMContentLoaded', function() {
    loadTheme(); // 加载保存的主题
    loadCurrentUser();
    initNavigation();
    loadInitialData();
    initForms();
    setDefaultDates();
    initDatePickers(); // 初始化日期选择器
});

// ==================== 主题管理 ====================

// 加载保存的主题
function loadTheme() {
    const savedTheme = localStorage.getItem('theme') || 'dark';
    document.documentElement.setAttribute('data-theme', savedTheme);
    updateThemeIcon(savedTheme);
}

// 切换主题
function toggleTheme() {
    const currentTheme = document.documentElement.getAttribute('data-theme');
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
    
    document.documentElement.setAttribute('data-theme', newTheme);
    localStorage.setItem('theme', newTheme);
    updateThemeIcon(newTheme);
    
    // 重新加载图表以应用新主题
    const currentPage = document.querySelector('.page.active');
    if (currentPage && currentPage.id === 'page-dashboard') {
        setTimeout(() => {
            loadDashboardCharts();
        }, 100);
    }
}

// 更新主题图标
function updateThemeIcon(theme) {
    const icon = document.querySelector('.theme-icon');
    if (icon) {
        icon.textContent = theme === 'dark' ? '☀️' : '🌙';
    }
}

// ==================== 用户认证相关 ====================

// 加载当前登录用户信息
async function loadCurrentUser() {
    try {
        const response = await fetch('/api/current-user');
        const data = await response.json();
        
        if (data.success && data.user) {
            const user = data.user;
            document.getElementById('userName').textContent = user.name || user.username;
            
            // 显示角色
            const roleMap = {
                'admin': '系统管理员',
                'captain': '车队队长',
                'driver': '司机',
                'employee': '员工'
            };
            document.getElementById('userRole').textContent = roleMap[user.role] || user.role;
            
            // 显示用户头像
            const userAvatar = document.querySelector('.user-avatar');
            if (user.avatar) {
                userAvatar.innerHTML = `<img src="/static/avatars/${user.avatar}" alt="头像" style="width: 40px; height: 40px; border-radius: 50%; object-fit: cover;">`;
            }
            
            // 如果是管理员，显示用户管理菜单
            if (user.role === 'admin') {
                document.getElementById('adminDivider').style.display = 'block';
                document.getElementById('userManagementNav').style.display = 'flex';
            }
        }
    } catch (error) {
        console.error('加载用户信息失败:', error);
    }
}

// 登出
async function logout() {
    if (!confirm('确定要退出登录吗？')) {
        return;
    }
    
    try {
        const response = await fetch('/api/logout', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        
        if (data.success) {
            window.location.href = '/login';
        } else {
            showToast('登出失败', 'error');
        }
    } catch (error) {
        console.error('登出失败:', error);
        showToast('登出失败', 'error');
    }
}

// 初始化导航
function initNavigation() {
    document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', function(e) {
            e.preventDefault();
            const page = this.dataset.page;
            switchPage(page);
        });
    });
}

// 切换页面
function switchPage(page) {
    // 更新导航状态
    document.querySelectorAll('.nav-item').forEach(item => {
        item.classList.toggle('active', item.dataset.page === page);
    });
    
    // 更新页面显示
    document.querySelectorAll('.page').forEach(p => {
        p.classList.remove('active');
    });
    document.getElementById(`page-${page}`).classList.add('active');
    
    // 更新标题
    const titles = {
        'dashboard': '系统概览',
        'add-driver': '录入司机信息',
        'add-bus': '录入车辆信息',
        'add-violation': '录入违章信息',
        'query-fleet-drivers': '查询车队司机',
        'query-driver-violations': '查询司机违章',
        'query-fleet-stats': '车队违章统计',
        'user-management': '用户管理'
    };
    document.getElementById('page-title').textContent = titles[page] || '公交安全管理系统';
    
    // 当切换到仪表盘页面时，重新加载图表
    if (page === 'dashboard') {
        setTimeout(() => {
            loadDashboardCharts();
        }, 200);
    }
}

// 设置默认日期
function setDefaultDates() {
    const today = new Date().toISOString().split('T')[0];
    const yearAgo = new Date(Date.now() - 365 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
    
    document.getElementById('query-start-date').value = yearAgo;
    document.getElementById('query-end-date').value = today;
    document.getElementById('stats-start-date').value = yearAgo;
    document.getElementById('stats-end-date').value = today;
}

// 初始化日期选择器
function initDatePickers() {
    // 配置flatpickr的默认选项
    const datePickerOptions = {
        locale: "zh",
        dateFormat: "Y-m-d",
        altInput: true,
        altFormat: "Y年m月d日",
        allowInput: true,
        clickOpens: true
    };
    
    const dateTimePickerOptions = {
        locale: "zh",
        enableTime: true,
        dateFormat: "Y-m-d H:i",
        altInput: true,
        altFormat: "Y年m月d日 H:i",
        time_24hr: true,
        allowInput: true,
        clickOpens: true
    };
    
    // 明确初始化每个日期输入框
    const dateInputs = [
        '#driver-hire-date',           // 司机入职日期
        '#driver-license-expire',      // 驾照到期日期
        '#bus-purchase-date',          // 车辆购置日期
        '#query-start-date',           // 查询开始日期
        '#query-end-date',             // 查询结束日期
        '#stats-start-date',           // 统计开始日期
        '#stats-end-date'              // 统计结束日期
    ];
    
    const dateTimeInputs = [
        '#violation-time'              // 违章时间
    ];
    
    // 初始化日期输入框
    dateInputs.forEach(selector => {
        const element = document.querySelector(selector);
        if (element) {
            flatpickr(element, datePickerOptions);
        }
    });
    
    // 初始化日期时间输入框
    dateTimeInputs.forEach(selector => {
        const element = document.querySelector(selector);
        if (element) {
            flatpickr(element, dateTimePickerOptions);
        }
    });
    
    // 也初始化所有type="date"和type="datetime-local"的输入框（作为备份）
    flatpickr('input[type="date"]:not([data-flatpickr])', datePickerOptions);
    flatpickr('input[type="datetime-local"]:not([data-flatpickr])', dateTimePickerOptions);
}

// ==================== 数据加载 ====================
async function loadInitialData() {
    try {
        await Promise.all([
            loadFleets(),
            loadRoutes(),
            loadDrivers(),
            loadBuses(),
            loadViolationTypes(),
            loadStations(),
            loadManagers()
        ]);
        
        updateDashboard();
        populateSelects();
        loadDashboardCharts();  // 加载仪表盘图表
    } catch (error) {
        console.error('加载数据失败:', error);
        showToast('数据加载失败', 'error');
    }
}

async function loadFleets() {
    const response = await fetch('/api/fleets');
    const result = await response.json();
    if (result.success) {
        fleets = result.data;
    }
}

async function loadRoutes() {
    const response = await fetch('/api/routes');
    const result = await response.json();
    if (result.success) {
        routes = result.data;
    }
}

async function loadDrivers() {
    const response = await fetch('/api/drivers');
    const result = await response.json();
    if (result.success) {
        drivers = result.data;
    }
}

async function loadBuses() {
    const response = await fetch('/api/buses');
    const result = await response.json();
    if (result.success) {
        buses = result.data;
    }
}

async function loadViolationTypes() {
    const response = await fetch('/api/violation-types');
    const result = await response.json();
    if (result.success) {
        violationTypes = result.data;
    }
}

async function loadStations() {
    const response = await fetch('/api/stations');
    const result = await response.json();
    if (result.success) {
        stations = result.data;
    }
}

async function loadManagers() {
    const response = await fetch('/api/managers');
    const result = await response.json();
    if (result.success) {
        managers = result.data;
    }
}

// ==================== 更新仪表盘 ====================
function updateDashboard() {
    document.getElementById('stat-fleets').textContent = fleets.length;
    document.getElementById('stat-routes').textContent = routes.length;
    document.getElementById('stat-drivers').textContent = drivers.length;
    document.getElementById('stat-buses').textContent = buses.length;
    
    // 更新车队表格
    const tbody = document.querySelector('#fleet-table tbody');
    tbody.innerHTML = fleets.map(f => `
        <tr>
            <td>${f.fleet_code}</td>
            <td>${f.fleet_name}</td>
            <td>${f.captain_name || '-'}</td>
            <td>${f.route_count}</td>
            <td>${f.driver_count}</td>
        </tr>
    `).join('');
}

// ==================== 填充下拉框 ====================
function populateSelects() {
    // 线路下拉框
    const routeOptions = routes.map(r => 
        `<option value="${r.route_id}">[${r.fleet_name}] ${r.route_code} - ${r.route_name}</option>`
    ).join('');
    
    document.getElementById('driver-route-select').innerHTML = '<option value="">暂不分配</option>' + routeOptions;
    document.getElementById('bus-route-select').innerHTML = '<option value="">暂不分配</option>' + routeOptions;
    document.getElementById('query-bus-route-select').innerHTML = '<option value="">全部线路</option>' + routeOptions;
    
    // 车队下拉框
    const fleetOptions = fleets.map(f => 
        `<option value="${f.fleet_id}">${f.fleet_code} - ${f.fleet_name}</option>`
    ).join('');
    
    document.getElementById('query-fleet-select').innerHTML = '<option value="">请选择车队</option>' + fleetOptions;
    document.getElementById('stats-fleet-select').innerHTML = '<option value="">请选择车队</option>' + fleetOptions;
    
    // 司机下拉框
    const driverOptions = drivers.map(d => 
        `<option value="${d.driver_id}">${d.emp_code} - ${d.name} (${d.fleet_name || '未分配'})</option>`
    ).join('');
    
    document.getElementById('violation-driver-select').innerHTML = '<option value="">请选择司机</option>' + driverOptions;
    document.getElementById('query-driver-select').innerHTML = '<option value="">请选择司机</option>' + driverOptions;
    
    // 车辆下拉框
    const busOptions = buses.map(b => 
        `<option value="${b.bus_id}">${b.plate_number} - ${b.bus_code} (${b.route_code || '未分配'})</option>`
    ).join('');
    
    document.getElementById('violation-bus-select').innerHTML = '<option value="">请选择车辆</option>' + busOptions;
    
    // 违章类型下拉框
    const typeOptions = violationTypes.map(t => 
        `<option value="${t.type_id}">${t.type_name} (扣${t.penalty_points}分, 罚${t.fine_amount}元)</option>`
    ).join('');
    
    document.getElementById('violation-type-select').innerHTML = '<option value="">请选择违章类型</option>' + typeOptions;
    
    // 站点下拉框
    const stationOptions = stations.map(s => 
        `<option value="${s.station_id}">${s.station_name}</option>`
    ).join('');
    
    document.getElementById('violation-station-select').innerHTML = '<option value="">不指定</option>' + stationOptions;
    
    // 记录人下拉框（队长和路队长）
    const managerOptions = managers.map(m => 
        `<option value="${m.employee_id}">${m.name} (${m.role} - ${m.dept})</option>`
    ).join('');
    
    document.getElementById('violation-recorder-select').innerHTML = '<option value="">请选择记录人（队长/路队长）</option>' + managerOptions;
}

// ==================== 表单处理 ====================
function initForms() {
    // 司机表单
    document.getElementById('driver-form').addEventListener('submit', async function(e) {
        e.preventDefault();
        const formData = new FormData(this);
        const data = Object.fromEntries(formData.entries());
        
        try {
            const response = await fetch('/api/driver', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            });
            const result = await response.json();
            
            if (result.success) {
                showToast('司机信息录入成功！', 'success');
                this.reset();
                await loadDrivers();
                populateSelects();
            } else {
                showToast(result.message || '录入失败', 'error');
            }
        } catch (error) {
            showToast('网络错误', 'error');
        }
    });
    
    // 车辆表单
    document.getElementById('bus-form').addEventListener('submit', async function(e) {
        e.preventDefault();
        const formData = new FormData(this);
        const data = Object.fromEntries(formData.entries());
        
        try {
            const response = await fetch('/api/bus', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            });
            const result = await response.json();
            
            if (result.success) {
                showToast('车辆信息录入成功！', 'success');
                this.reset();
                await loadBuses();
                populateSelects();
            } else {
                showToast(result.message || '录入失败', 'error');
            }
        } catch (error) {
            showToast('网络错误', 'error');
        }
    });
    
    // 违章表单
    document.getElementById('violation-form').addEventListener('submit', async function(e) {
        e.preventDefault();
        const formData = new FormData(this);
        const data = Object.fromEntries(formData.entries());
        
        try {
            const response = await fetch('/api/violation', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            });
            const result = await response.json();
            
            if (result.success) {
                showToast('违章信息录入成功！', 'success');
                this.reset();
                removeVideo(); // 清除视频
            } else {
                showToast(result.message || '录入失败', 'error');
            }
        } catch (error) {
            showToast('网络错误', 'error');
        }
    });
    
    // 查询车辆表单
    document.getElementById('query-buses-form').addEventListener('submit', function(e) {
        e.preventDefault();
        queryBuses();
    });
}

// ==================== 查询功能 ====================

// 查询车辆信息
async function queryBuses() {
    const routeId = document.getElementById('query-bus-route-select').value;
    const status = document.getElementById('query-bus-status-select').value;
    
    try {
        let url = '/api/buses';
        const params = [];
        if (routeId) params.push(`route_id=${routeId}`);
        if (status) params.push(`status=${encodeURIComponent(status)}`);
        if (params.length > 0) url += '?' + params.join('&');
        
        const response = await fetch(url);
        const result = await response.json();
        
        if (result.success) {
            const buses = result.data || [];
            displayBusResults(buses);
            showToast(`查询成功，找到 ${buses.length} 辆车辆`, 'success');
        } else {
            showToast(result.message || '查询失败', 'error');
        }
    } catch (error) {
        console.error('Query buses error:', error);
        showToast('查询失败，请重试', 'error');
    }
}

// 显示车辆查询结果
function displayBusResults(buses) {
    const resultsDiv = document.getElementById('bus-query-results');
    const tbody = document.getElementById('bus-result-tbody');
    const countSpan = document.getElementById('bus-result-count');
    
    // 显示结果区域
    resultsDiv.style.display = 'block';
    countSpan.textContent = buses.length;
    
    // 清空表格
    tbody.innerHTML = '';
    
    if (buses.length === 0) {
        tbody.innerHTML = '<tr><td colspan="9" style="text-align: center;">暂无数据</td></tr>';
        return;
    }
    
    // 填充表格
    buses.forEach(bus => {
        const row = document.createElement('tr');
        
        // 状态颜色标记
        let statusClass = '';
        switch(bus.status) {
            case '运营中': statusClass = 'status-success'; break;
            case '维修中': statusClass = 'status-warning'; break;
            case '报废': statusClass = 'status-danger'; break;
            case '备用': statusClass = 'status-info'; break;
        }
        
        row.innerHTML = `
            <td>${bus.plate_number || '-'}</td>
            <td>${bus.bus_code || '-'}</td>
            <td>${bus.model || '-'}</td>
            <td>${bus.brand || '-'}</td>
            <td>${bus.seats || '-'}</td>
            <td>${bus.route_code ? bus.route_code + ' ' + (bus.route_name || '') : '-'}</td>
            <td>${bus.purchase_date || '-'}</td>
            <td><span class="status-badge ${statusClass}">${bus.status || '-'}</span></td>
            <td>
                <button class="btn btn-sm btn-primary" onclick="editBus(${bus.bus_id})">编辑</button>
            </td>
        `;
        tbody.appendChild(row);
    });
}

// 功能4：查询车队司机
async function queryFleetDrivers() {
    const fleetId = document.getElementById('query-fleet-select').value;
    if (!fleetId) {
        showToast('请选择车队', 'error');
        return;
    }
    
    try {
        const response = await fetch(`/api/drivers/by-fleet/${fleetId}`);
        const result = await response.json();
        
        if (result.success) {
            const fleet = fleets.find(f => f.fleet_id == fleetId);
            document.getElementById('fleet-name-display').textContent = fleet?.fleet_name || '';
            
            const tbody = document.querySelector('#fleet-drivers-table tbody');
            tbody.innerHTML = result.data.map(d => `
                <tr>
                    <td>${d.emp_code}</td>
                    <td>${d.name}</td>
                    <td>${d.gender}</td>
                    <td>${d.phone || '-'}</td>
                    <td>${d.route_code || '-'}</td>
                    <td>${d.license_type}</td>
                    <td>${d.driving_years}年</td>
                    <td>${d.is_route_captain ? '<span class="status-tag confirmed">是</span>' : '否'}</td>
                </tr>
            `).join('');
            
            document.getElementById('fleet-drivers-summary').textContent = `共 ${result.data.length} 名司机`;
            document.getElementById('fleet-drivers-result').style.display = 'block';
        }
    } catch (error) {
        showToast('查询失败', 'error');
    }
}

// 功能5：查询司机违章详情
async function queryDriverViolations() {
    const driverId = document.getElementById('query-driver-select').value;
    const startDate = document.getElementById('query-start-date').value;
    const endDate = document.getElementById('query-end-date').value;
    
    if (!driverId || !startDate || !endDate) {
        showToast('请填写完整的查询条件', 'error');
        return;
    }
    
    try {
        const response = await fetch(`/api/violations/by-driver?driver_id=${driverId}&start_date=${startDate}&end_date=${endDate}`);
        const result = await response.json();
        
        if (result.success) {
            const driver = drivers.find(d => d.driver_id == driverId);
            document.getElementById('driver-name-display').textContent = driver ? `${driver.name} (${driver.emp_code})` : '';
            
            // 统计摘要
            document.getElementById('violation-stats').innerHTML = `
                <div class="stat-item">
                    <div class="value">${result.stats.count}</div>
                    <div class="label">违章次数</div>
                </div>
                <div class="stat-item">
                    <div class="value">${result.stats.total_points}</div>
                    <div class="label">总扣分</div>
                </div>
                <div class="stat-item">
                    <div class="value">¥${result.stats.total_fine.toFixed(2)}</div>
                    <div class="label">总罚款</div>
                </div>
            `;
            
            const tbody = document.querySelector('#driver-violations-table tbody');
            tbody.innerHTML = result.data.map(v => `
                <tr>
                    <td>${formatDateTime(v.violation_time)}</td>
                    <td>${v.violation_name}</td>
                    <td>${v.plate_number}</td>
                    <td>${v.violation_location || '-'}</td>
                    <td>${v.penalty_points}</td>
                    <td>¥${v.fine_amount.toFixed(2)}</td>
                    <td>${getSeverityTag(v.severity)}</td>
                    <td>${getStatusTag(v.status)}</td>
                    <td>${v.video_url ? `<button class="btn btn-sm" onclick="viewViolationVideo('${v.video_url}')">📹 查看视频</button>` : '-'}</td>
                    <td>
                        <button class="btn btn-sm btn-danger" onclick="deleteViolation(${v.record_id})">🗑️ 删除</button>
                    </td>
                </tr>
            `).join('');
            
            document.getElementById('driver-violations-result').style.display = 'block';
        }
    } catch (error) {
        showToast('查询失败', 'error');
    }
}

// 功能6：查询车队违章统计
async function queryFleetStats() {
    const fleetId = document.getElementById('stats-fleet-select').value;
    const startDate = document.getElementById('stats-start-date').value;
    const endDate = document.getElementById('stats-end-date').value;
    
    if (!fleetId || !startDate || !endDate) {
        showToast('请填写完整的查询条件', 'error');
        return;
    }
    
    try {
        const response = await fetch(`/api/violations/stats-by-fleet?fleet_id=${fleetId}&start_date=${startDate}&end_date=${endDate}`);
        const result = await response.json();
        
        if (result.success) {
            const fleet = fleets.find(f => f.fleet_id == fleetId);
            document.getElementById('stats-fleet-name-display').textContent = fleet?.fleet_name || '';
            
            // 统计摘要
            document.getElementById('fleet-stats-summary').innerHTML = `
                <div class="stat-item">
                    <div class="value">${result.stats.total_count}</div>
                    <div class="label">总违章次数</div>
                </div>
                <div class="stat-item">
                    <div class="value">${result.stats.total_points}</div>
                    <div class="label">总扣分</div>
                </div>
                <div class="stat-item">
                    <div class="value">¥${result.stats.total_fine.toFixed(2)}</div>
                    <div class="label">总罚款</div>
                </div>
            `;
            
            // 图表
            const maxCount = Math.max(...result.data.map(d => d.count), 1);
            document.getElementById('stats-chart').innerHTML = result.data.map(d => {
                const height = (d.count / maxCount) * 100;
                const barClass = d.severity === '严重' || d.severity === '特别严重' ? 'severe' : 
                                d.severity === '一般' ? 'warning' : '';
                return `
                    <div class="chart-bar">
                        <div class="count">${d.count}次</div>
                        <div class="bar ${barClass}" style="height: ${height}px;"></div>
                        <div class="label">${d.type_name}</div>
                    </div>
                `;
            }).join('');
            
            // 表格
            const tbody = document.querySelector('#fleet-stats-table tbody');
            tbody.innerHTML = result.data.map(d => `
                <tr>
                    <td>${d.type_name}</td>
                    <td><strong>${d.count}</strong></td>
                    <td>${d.total_points || 0}</td>
                    <td>¥${(d.total_fine || 0).toFixed(2)}</td>
                    <td>${getSeverityTag(d.severity)}</td>
                </tr>
            `).join('');
            
            document.getElementById('fleet-stats-result').style.display = 'block';
        }
    } catch (error) {
        showToast('查询失败', 'error');
    }
}

// ==================== 工具函数 ====================

function formatDateTime(dateStr) {
    if (!dateStr) return '-';
    const date = new Date(dateStr);
    return date.toLocaleString('zh-CN', { 
        year: 'numeric', 
        month: '2-digit', 
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit'
    });
}

function getStatusTag(status) {
    const statusMap = {
        '待处理': 'pending',
        '已确认': 'confirmed',
        '已申诉': 'appeal',
        '已撤销': 'cancelled'
    };
    return `<span class="status-tag ${statusMap[status] || ''}">${status}</span>`;
}

function getSeverityTag(severity) {
    const severityMap = {
        '轻微': 'minor',
        '一般': 'normal',
        '严重': 'serious',
        '特别严重': 'critical'
    };
    return `<span class="severity-tag ${severityMap[severity] || ''}">${severity}</span>`;
}

function showToast(message, type = 'success') {
    const toast = document.getElementById('toast');
    toast.textContent = message;
    toast.className = `toast ${type} show`;
    
    setTimeout(() => {
        toast.classList.remove('show');
    }, 3000);
}

// ==================== 个人资料编辑 ====================

// 打开个人资料对话框
async function openProfileModal() {
    try {
        const response = await fetch('/api/current-user');
        const data = await response.json();
        
        if (data.success && data.user) {
            const user = data.user;
            document.getElementById('profileUsername').value = user.username;
            document.getElementById('profileName').value = user.name;
            document.getElementById('profileAvatar').value = user.avatar || '';
            
            // 显示当前头像
            const profileCurrentAvatar = document.getElementById('profileCurrentAvatar');
            if (user.avatar) {
                profileCurrentAvatar.src = `/static/avatars/${user.avatar}`;
            } else {
                profileCurrentAvatar.src = 'data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' width=\'60\' height=\'60\'%3E%3Crect fill=\'%23ddd\' width=\'60\' height=\'60\'/%3E%3Ctext x=\'50%25\' y=\'50%25\' dominant-baseline=\'middle\' text-anchor=\'middle\' font-size=\'24\' fill=\'%23999\'%3E👤%3C/text%3E%3C/svg%3E';
            }
            
            // 加载头像列表
            await loadProfileAvatars();
            
            document.getElementById('profileModal').style.display = 'flex';
        }
    } catch (error) {
        showToast('加载个人信息失败', 'error');
    }
}

// 关闭个人资料对话框
function closeProfileModal() {
    document.getElementById('profileModal').style.display = 'none';
    document.getElementById('profileAvatarPicker').style.display = 'none';
}

// 加载头像列表（个人资料）
async function loadProfileAvatars() {
    try {
        const response = await fetch('/api/avatars');
        const data = await response.json();
        
        if (data.success && data.avatars.length > 0) {
            const avatarGrid = document.getElementById('profileAvatarGrid');
            avatarGrid.innerHTML = '';
            
            data.avatars.forEach(avatar => {
                const avatarItem = document.createElement('div');
                avatarItem.className = 'avatar-item';
                avatarItem.innerHTML = `<img src="/static/avatars/${avatar}" alt="${avatar}">`;
                avatarItem.onclick = () => selectProfileAvatar(avatar);
                avatarGrid.appendChild(avatarItem);
            });
        }
    } catch (error) {
        console.error('加载头像列表失败:', error);
    }
}

// 显示头像选择器（个人资料）
function showProfileAvatarPicker() {
    const picker = document.getElementById('profileAvatarPicker');
    picker.style.display = picker.style.display === 'none' ? 'block' : 'none';
}

// 选择头像（个人资料）
function selectProfileAvatar(avatarFilename) {
    document.getElementById('profileAvatar').value = avatarFilename;
    document.getElementById('profileCurrentAvatar').src = `/static/avatars/${avatarFilename}`;
    document.getElementById('profileAvatarPicker').style.display = 'none';
    showToast('头像已选择', 'success');
}

// 保存个人资料
async function saveProfile() {
    const avatar = document.getElementById('profileAvatar').value;
    
    try {
        const response = await fetch('/api/profile', {
            method: 'PUT',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({ avatar })
        });
        
        const data = await response.json();
        
        if (data.success) {
            showToast('个人资料已更新', 'success');
            closeProfileModal();
            // 刷新用户信息显示
            loadCurrentUser();
        } else {
            showToast(data.message, 'error');
        }
    } catch (error) {
        showToast('保存失败', 'error');
    }
}

// ==================== 仪表盘图表 ====================

// 加载仪表盘图表数据
async function loadDashboardCharts() {
    try {
        const response = await fetch('/api/dashboard/charts');
        const data = await response.json();
        
        if (data.success) {
            // 确保图表容器存在后再初始化
            setTimeout(() => {
                // 优先使用模拟数据（因为真实数据可能没有变化）
                const trendData = generateMockTrendData();
                const violationTypeData = generateMockViolationTypeData();
                const busStatusData = generateMockBusStatusData();
                const fleetRankingData = generateMockFleetRankingData();
                const severityData = generateMockSeverityData();
                
                console.log('趋势数据:', trendData); // 调试输出
                
                initTrendChart(trendData);
                initViolationTypeChart(violationTypeData);
                initBusStatusChart(busStatusData);
                initFleetRankingChart(fleetRankingData);
                initSeverityChart(severityData);
            }, 100);
        } else {
            console.error('获取图表数据失败:', data.message);
            // 显示模拟数据
            showMockData();
        }
    } catch (error) {
        console.error('加载图表数据失败:', error);
        // 显示模拟数据
        showMockData();
    }
}

// 生成模拟数据
function generateMockTrendData() {
    const data = [];
    for (let i = 29; i >= 0; i--) {
        const date = new Date();
        date.setDate(date.getDate() - i);
        // 生成0-8之间的随机违章次数，模拟真实趋势
        const baseCount = 3; // 基础违章次数
        const variation = Math.floor(Math.random() * 6) - 2; // -2到+3的变化
        const count = Math.max(0, baseCount + variation); // 确保不为负数
        data.push({
            date: date.toISOString().split('T')[0],
            count: count
        });
    }
    return data;
}

function generateMockViolationTypeData() {
    return [
        {name: '超速行驶', value: 8},
        {name: '闯红灯', value: 5},
        {name: '违规变道', value: 4},
        {name: '不按规定车道', value: 3},
        {name: '违规停车', value: 2}
    ];
}

function generateMockBusStatusData() {
    return [
        {name: '运营中', value: 45},
        {name: '维修中', value: 8},
        {name: '备用', value: 12},
        {name: '报废', value: 3}
    ];
}

function generateMockFleetRankingData() {
    return [
        {name: '第一车队', value: 12},
        {name: '第二车队', value: 8},
        {name: '第三车队', value: 5}
    ];
}

function generateMockSeverityData() {
    return [
        {name: '轻微', value: 10},
        {name: '一般', value: 15},
        {name: '严重', value: 5},
        {name: '特别严重', value: 2}
    ];
}

function showMockData() {
    setTimeout(() => {
        initTrendChart(generateMockTrendData());
        initViolationTypeChart(generateMockViolationTypeData());
        initBusStatusChart(generateMockBusStatusData());
        initFleetRankingChart(generateMockFleetRankingData());
        initSeverityChart(generateMockSeverityData());
    }, 100);
}

// 1. 近30天违章趋势图
function initTrendChart(data) {
    const container = document.getElementById('trendChart');
    if (!container) {
        console.error('图表容器 trendChart 不存在');
        return;
    }
    const chart = echarts.init(container);
    const dates = data.map(item => item.date);
    const counts = data.map(item => item.count);
    
    // 获取当前主题
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    const textColor = isDark ? '#ffffff' : '#333333';
    const axisLineColor = isDark ? '#475569' : '#e2e8f0';
    
    const option = {
        tooltip: {
            trigger: 'axis',
            axisPointer: { type: 'cross' }
        },
        grid: { left: '3%', right: '4%', bottom: '3%', containLabel: true },
        xAxis: {
            type: 'category',
            boundaryGap: false,
            data: dates,
            axisLabel: {
                color: textColor,
                formatter: function(value) {
                    return value.split('-')[2] + '日';
                }
            },
            axisLine: { lineStyle: { color: axisLineColor } },
            splitLine: { lineStyle: { color: axisLineColor } }
        },
        yAxis: { 
            type: 'value',
            name: '违章次数',
            nameTextStyle: { color: textColor },
            minInterval: 1, // 确保Y轴刻度为整数
            axisLabel: { 
                color: textColor,
                formatter: '{value} 次' // 显示单位
            },
            axisLine: { lineStyle: { color: axisLineColor } },
            splitLine: { lineStyle: { color: axisLineColor } }
        },
        series: [{
            name: '违章次数',
            type: 'line',
            smooth: true,
            areaStyle: {
                color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
                    { offset: 0, color: 'rgba(58, 77, 233, 0.8)' },
                    { offset: 1, color: 'rgba(58, 77, 233, 0.1)' }
                ])
            },
            lineStyle: { color: '#3A4DE9', width: 2 },
            itemStyle: { color: '#3A4DE9' },
            data: counts
        }]
    };
    
    chart.setOption(option);
    window.addEventListener('resize', () => chart.resize());
}

// 2. 违章类型分布饼图
function initViolationTypeChart(data) {
    const container = document.getElementById('violationTypeChart');
    if (!container) return;
    const chart = echarts.init(container);
    
    // 获取当前主题
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    const textColor = isDark ? '#ffffff' : '#333333';
    
    const option = {
        tooltip: { trigger: 'item', formatter: '{b}: {c} ({d}%)' },
        legend: { 
            orient: 'vertical', 
            left: 'left', 
            top: 'middle',
            textStyle: { color: textColor }
        },
        series: [{
            name: '违章类型',
            type: 'pie',
            radius: ['40%', '70%'],
            avoidLabelOverlap: false,
            itemStyle: {
                borderRadius: 10,
                borderColor: '#fff',
                borderWidth: 2
            },
            label: { 
                show: false,
                color: textColor
            },
            emphasis: {
                label: {
                    show: true,
                    fontSize: 16,
                    fontWeight: 'bold',
                    color: textColor
                }
            },
            data: data
        }]
    };
    
    chart.setOption(option);
    window.addEventListener('resize', () => chart.resize());
}

// 3. 车辆状态分布环形图
function initBusStatusChart(data) {
    const container = document.getElementById('busStatusChart');
    if (!container) return;
    const chart = echarts.init(container);
    
    // 获取当前主题
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    const textColor = isDark ? '#ffffff' : '#333333';
    
    const colorMap = {
        '运营中': '#52c41a',
        '维修中': '#faad14',
        '备用': '#1890ff',
        '报废': '#f5222d'
    };
    
    const processedData = data.map(item => ({
        ...item,
        itemStyle: { color: colorMap[item.name] || '#999' }
    }));
    
    const option = {
        tooltip: { trigger: 'item' },
        legend: { 
            orient: 'horizontal', 
            bottom: '0%', 
            left: 'center',
            textStyle: { color: textColor }
        },
        series: [{
            name: '车辆状态',
            type: 'pie',
            radius: ['50%', '70%'],
            center: ['50%', '45%'],
            avoidLabelOverlap: false,
            itemStyle: {
                borderRadius: 8,
                borderColor: '#fff',
                borderWidth: 3
            },
            label: {
                show: true,
                position: 'center',
                formatter: function(params) {
                    if (params.dataIndex === 0) {
                        const total = data.reduce((sum, item) => sum + item.value, 0);
                        return '{total|' + total + '}\n{label|总车辆}';
                    }
                    return '';
                },
                rich: {
                    total: {
                        fontSize: 32,
                        fontWeight: 'bold',
                        color: textColor
                    },
                    label: {
                        fontSize: 14,
                        color: isDark ? '#cbd5e1' : '#999',
                        padding: [5, 0, 0, 0]
                    }
                }
            },
            emphasis: {
                label: {
                    show: true,
                    fontSize: 16,
                    fontWeight: 'bold'
                }
            },
            data: processedData
        }]
    };
    
    chart.setOption(option);
    window.addEventListener('resize', () => chart.resize());
}

// 4. 车队违章排名柱状图
function initFleetRankingChart(data) {
    const container = document.getElementById('fleetRankingChart');
    if (!container) return;
    const chart = echarts.init(container);
    const fleetNames = data.map(item => item.name);
    const counts = data.map(item => item.value);
    
    // 获取当前主题
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    const textColor = isDark ? '#ffffff' : '#333333';
    const axisLineColor = isDark ? '#475569' : '#e2e8f0';
    
    const option = {
        tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
        grid: { left: '3%', right: '4%', bottom: '3%', containLabel: true },
        xAxis: {
            type: 'value',
            boundaryGap: [0, 0.01],
            axisLabel: { color: textColor },
            axisLine: { lineStyle: { color: axisLineColor } },
            splitLine: { lineStyle: { color: axisLineColor } }
        },
        yAxis: {
            type: 'category',
            data: fleetNames,
            axisLabel: { color: textColor },
            axisLine: { lineStyle: { color: axisLineColor } }
        },
        series: [{
            name: '违章次数',
            type: 'bar',
            data: counts,
            itemStyle: {
                color: new echarts.graphic.LinearGradient(0, 0, 1, 0, [
                    { offset: 0, color: '#667eea' },
                    { offset: 1, color: '#764ba2' }
                ]),
                borderRadius: [0, 5, 5, 0]
            },
            label: {
                show: true,
                position: 'right',
                formatter: '{c}次',
                color: textColor
            }
        }]
    };
    
    chart.setOption(option);
    window.addEventListener('resize', () => chart.resize());
}

// 5. 违章严重程度雷达图
function initSeverityChart(data) {
    const container = document.getElementById('severityChart');
    if (!container) return;
    const chart = echarts.init(container);
    
    // 获取当前主题
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    const textColor = isDark ? '#ffffff' : '#333333';
    const splitLineColor = isDark ? '#475569' : '#e2e8f0';
    
    const indicator = data.map(item => ({ name: item.name, max: Math.max(...data.map(d => d.value)) * 1.2 }));
    const values = data.map(item => item.value);
    
    const option = {
        tooltip: {},
        legend: { 
            bottom: '0%',
            textStyle: { color: textColor }
        },
        radar: {
            indicator: indicator,
            shape: 'polygon',
            splitNumber: 4,
            axisName: {
                color: textColor
            },
            splitArea: {
                areaStyle: {
                    color: ['rgba(250, 250, 250, 0.3)', 'rgba(200, 200, 200, 0.3)']
                }
            },
            splitLine: {
                lineStyle: {
                    color: splitLineColor
                }
            }
        },
        series: [{
            name: '违章严重程度',
            type: 'radar',
            data: [{
                value: values,
                name: '违章次数',
                areaStyle: {
                    color: 'rgba(255, 87, 51, 0.3)'
                },
                lineStyle: {
                    color: '#ff5733',
                    width: 2
                },
                itemStyle: {
                    color: '#ff5733'
                }
            }]
        }]
    };
    
    chart.setOption(option);
    window.addEventListener('resize', () => chart.resize());
}

// ==================== 视频上传功能 ====================

// 监听视频文件选择
document.addEventListener('DOMContentLoaded', function() {
    const videoInput = document.getElementById('violation-video');
    if (videoInput) {
        videoInput.addEventListener('change', handleVideoUpload);
    }
});

// 处理视频上传
async function handleVideoUpload(event) {
    const file = event.target.files[0];
    if (!file) return;
    
    // 检查文件大小（100MB）
    const maxSize = 100 * 1024 * 1024;
    if (file.size > maxSize) {
        showToast('视频文件不能超过100MB', 'error');
        event.target.value = '';
        return;
    }
    
    // 检查文件类型
    const allowedTypes = ['video/mp4', 'video/avi', 'video/mov', 'video/wmv', 'video/flv', 'video/mkv', 'video/webm'];
    if (!allowedTypes.includes(file.type) && !file.name.match(/\.(mp4|avi|mov|wmv|flv|mkv|webm)$/i)) {
        showToast('不支持的视频格式', 'error');
        event.target.value = '';
        return;
    }
    
    // 显示文件名
    document.getElementById('video-filename').textContent = file.name;
    
    // 显示上传进度
    document.getElementById('video-upload-progress').style.display = 'block';
    document.getElementById('video-preview').style.display = 'none';
    
    // 上传视频
    const formData = new FormData();
    formData.append('video', file);
    
    try {
        const response = await fetch('/api/upload-video', {
            method: 'POST',
            body: formData
        });
        
        const result = await response.json();
        
        if (result.success) {
            // 保存视频URL
            document.getElementById('violation-video-url').value = result.video_url;
            
            // 显示视频预览
            const videoPlayer = document.getElementById('violation-video-player');
            videoPlayer.src = result.video_url;
            document.getElementById('video-preview').style.display = 'block';
            document.getElementById('video-upload-progress').style.display = 'none';
            
            showToast('视频上传成功', 'success');
        } else {
            showToast(result.message || '视频上传失败', 'error');
            event.target.value = '';
            document.getElementById('video-filename').textContent = '';
            document.getElementById('video-upload-progress').style.display = 'none';
        }
    } catch (error) {
        showToast('视频上传失败: ' + error.message, 'error');
        event.target.value = '';
        document.getElementById('video-filename').textContent = '';
        document.getElementById('video-upload-progress').style.display = 'none';
    }
}

// 删除视频
function removeVideo() {
    document.getElementById('violation-video').value = '';
    document.getElementById('violation-video-url').value = '';
    document.getElementById('video-filename').textContent = '';
    document.getElementById('video-preview').style.display = 'none';
    document.getElementById('violation-video-player').src = '';
}

// 查看违章视频（弹窗显示）
function viewViolationVideo(videoUrl) {
    if (!videoUrl) {
        showToast('没有视频文件', 'error');
        return;
    }
    
    // 创建模态窗口
    const modal = document.createElement('div');
    modal.className = 'video-modal';
    modal.innerHTML = `
        <div class="video-modal-content">
            <div class="video-modal-header">
                <h3>违章视频</h3>
                <button class="video-modal-close" onclick="this.closest('.video-modal').remove()">✕</button>
            </div>
            <div class="video-modal-body">
                <video controls autoplay style="width: 100%; max-height: 70vh; border-radius: 8px;">
                    <source src="${videoUrl}" type="video/mp4">
                    您的浏览器不支持视频播放
                </video>
            </div>
        </div>
    `;
    
    document.body.appendChild(modal);
    
    // 点击背景关闭
    modal.addEventListener('click', function(e) {
        if (e.target === modal) {
            modal.remove();
        }
    });
}

// 删除违章记录
async function deleteViolation(recordId) {
    if (!confirm('确定要删除这条违章记录吗？此操作不可恢复！')) {
        return;
    }
    
    try {
        const response = await fetch(`/api/violation/${recordId}`, {
            method: 'DELETE'
        });
        
        const result = await response.json();
        
        if (result.success) {
            showToast('违章记录已删除', 'success');
            // 重新查询刷新列表
            queryDriverViolations();
        } else {
            showToast(result.message || '删除失败', 'error');
        }
    } catch (error) {
        showToast('删除失败，请重试', 'error');
        console.error('Delete violation error:', error);
    }
}

// ==================== 车辆编辑功能 ====================

// 打开编辑车辆弹窗
async function editBus(busId) {
    try {
        // 获取车辆详细信息
        const response = await fetch(`/api/bus/${busId}`);
        const result = await response.json();
        
        if (result.success) {
            const bus = result.data;
            
            // 填充表单
            document.getElementById('editBusId').value = bus.bus_id;
            document.getElementById('editPlateNumber').value = bus.plate_number || '';
            document.getElementById('editBusCode').value = bus.bus_code || '';
            document.getElementById('editModel').value = bus.model || '';
            document.getElementById('editBrand').value = bus.brand || '';
            document.getElementById('editSeats').value = bus.seats || '';
            document.getElementById('editPurchaseDate').value = bus.purchase_date || '';
            document.getElementById('editRouteId').value = bus.route_id || '';
            document.getElementById('editStatus').value = bus.status || '运营中';
            
            // 填充线路下拉框
            const routeOptions = routes.map(r => 
                `<option value="${r.route_id}">[${r.fleet_name}] ${r.route_code} - ${r.route_name}</option>`
            ).join('');
            document.getElementById('editRouteId').innerHTML = '<option value="">暂不分配</option>' + routeOptions;
            document.getElementById('editRouteId').value = bus.route_id || '';
            
            // 显示弹窗
            document.getElementById('editBusModal').style.display = 'flex';
        } else {
            showToast(result.message || '获取车辆信息失败', 'error');
        }
    } catch (error) {
        console.error('Edit bus error:', error);
        showToast('获取车辆信息失败', 'error');
    }
}

// 关闭编辑车辆弹窗
function closeEditBusModal() {
    document.getElementById('editBusModal').style.display = 'none';
}

// 保存车辆编辑
async function saveBusEdit() {
    const busId = document.getElementById('editBusId').value;
    const data = {
        plate_number: document.getElementById('editPlateNumber').value,
        bus_code: document.getElementById('editBusCode').value,
        model: document.getElementById('editModel').value,
        brand: document.getElementById('editBrand').value,
        seats: document.getElementById('editSeats').value,
        purchase_date: document.getElementById('editPurchaseDate').value,
        route_id: document.getElementById('editRouteId').value || null,
        status: document.getElementById('editStatus').value
    };
    
    if (!data.plate_number || !data.bus_code) {
        showToast('请填写车牌号和车辆编号', 'error');
        return;
    }
    
    try {
        const response = await fetch(`/api/bus/${busId}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        
        const result = await response.json();
        
        if (result.success) {
            showToast('车辆信息更新成功', 'success');
            closeEditBusModal();
            // 刷新车辆列表
            await loadBuses();
            queryBuses();
        } else {
            showToast(result.message || '更新失败', 'error');
        }
    } catch (error) {
        console.error('Save bus edit error:', error);
        showToast('更新失败，请重试', 'error');
    }
}
