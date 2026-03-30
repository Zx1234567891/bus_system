"""
公交安全管理系统 - Flask Web应用
"""
from flask import Flask, render_template, request, jsonify, session, redirect, url_for, send_from_directory
import pymysql
from pymysql.cursors import DictCursor
from datetime import datetime, date, timedelta
from decimal import Decimal
from functools import wraps
import os
import hashlib
import secrets
from werkzeug.utils import secure_filename

app = Flask(__name__)
app.config['JSON_AS_ASCII'] = False
app.config['SECRET_KEY'] = os.urandom(24)  # 用于session加密

# 文件上传配置
UPLOAD_FOLDER = os.path.join(os.path.dirname(__file__), 'static', 'uploads')
VIDEO_FOLDER = os.path.join(UPLOAD_FOLDER, 'videos')
ALLOWED_VIDEO_EXTENSIONS = {'mp4', 'avi', 'mov', 'wmv', 'flv', 'mkv', 'webm'}
MAX_VIDEO_SIZE = 100 * 1024 * 1024  # 100MB

# 确保上传目录存在
os.makedirs(VIDEO_FOLDER, exist_ok=True)

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['VIDEO_FOLDER'] = VIDEO_FOLDER
app.config['MAX_CONTENT_LENGTH'] = MAX_VIDEO_SIZE

# 数据库配置
DB_CONFIG = {
    'host': 'localhost',
    'port': 3306,
    'user': 'root',
    'password': 'root',
    'database': 'bus_safety_system',
    'charset': 'utf8mb4',
    'cursorclass': DictCursor
}

def get_db():
    """获取数据库连接"""
    return pymysql.connect(**DB_CONFIG)

def json_serial(obj):
    """JSON序列化辅助函数"""
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError(f"Type {type(obj)} not serializable")

def login_required(f):
    """登录验证装饰器"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('login_page'))
        return f(*args, **kwargs)
    return decorated_function

def admin_required(f):
    """管理员权限验证装饰器"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            # 对于API请求返回JSON，对于页面请求返回重定向
            if request.path.startswith('/api/'):
                return jsonify({'success': False, 'message': '未登录'}), 401
            return redirect(url_for('login_page'))
        if session.get('role') != 'admin':
            return jsonify({'success': False, 'message': '需要管理员权限'}), 403
        return f(*args, **kwargs)
    return decorated_function

def hash_password(password, salt=None):
    """密码哈希函数"""
    if salt is None:
        salt = secrets.token_hex(32)
    password_hash = hashlib.sha256((password + salt).encode()).hexdigest()
    return password_hash, salt

def verify_password(password, password_hash, salt):
    """验证密码"""
    computed_hash, _ = hash_password(password, salt)
    return computed_hash == password_hash

# ==================== 页面路由 ====================

@app.route('/')
@login_required
def index():
    """首页"""
    return render_template('index.html', user=session.get('user'))

@app.route('/login')
def login_page():
    """登录页面"""
    # 如果已登录，直接跳转到首页
    if 'user_id' in session:
        return redirect(url_for('index'))
    return render_template('login.html')

@app.route('/register')
def register_page():
    """注册页面"""
    # 如果已登录，直接跳转到首页
    if 'user_id' in session:
        return redirect(url_for('index'))
    return render_template('register.html')

# ==================== 认证API ====================

@app.route('/api/login', methods=['POST'])
def login():
    """用户登录"""
    data = request.json
    username = data.get('username')
    password = data.get('password')
    remember_me = data.get('remember_me', False)
    
    if not username or not password:
        return jsonify({'success': False, 'message': '用户名和密码不能为空'})
    
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # 查询用户凭证表
            cursor.execute("""
                SELECT uc.user_id, uc.employee_id, uc.username, uc.password_hash, 
                       uc.salt, uc.role, uc.is_active, uc.locked_until, uc.login_attempts,
                       e.name
                FROM user_credentials uc
                INNER JOIN employee e ON uc.employee_id = e.employee_id
                WHERE uc.username = %s AND uc.is_active = 1
                LIMIT 1
            """, (username,))
            
            user = cursor.fetchone()
            
            if not user:
                return jsonify({'success': False, 'message': '用户名或密码错误'})
            
            # 检查账号是否被锁定
            if user['locked_until'] and user['locked_until'] > datetime.now():
                return jsonify({'success': False, 'message': f"账号已被锁定，请在{user['locked_until'].strftime('%Y-%m-%d %H:%M:%S')}后重试"})
            
            # 验证密码
            if not verify_password(password, user['password_hash'], user['salt']):
                # 增加失败次数
                new_attempts = user['login_attempts'] + 1
                locked_until = None
                
                # 连续失败5次锁定30分钟
                if new_attempts >= 5:
                    locked_until = datetime.now() + timedelta(minutes=30)
                    cursor.execute("""
                        UPDATE user_credentials 
                        SET login_attempts = %s, locked_until = %s
                        WHERE user_id = %s
                    """, (new_attempts, locked_until, user['user_id']))
                    conn.commit()
                    return jsonify({'success': False, 'message': '密码错误次数过多，账号已被锁定30分钟'})
                else:
                    cursor.execute("""
                        UPDATE user_credentials 
                        SET login_attempts = %s
                        WHERE user_id = %s
                    """, (new_attempts, user['user_id']))
                    conn.commit()
                    return jsonify({'success': False, 'message': f'用户名或密码错误（还可尝试{5-new_attempts}次）'})
            
            # 登录成功，重置失败次数和更新最后登录时间
            cursor.execute("""
                UPDATE user_credentials 
                SET login_attempts = 0, locked_until = NULL, last_login = NOW()
                WHERE user_id = %s
            """, (user['user_id'],))
            conn.commit()
            
            # 设置session
            session['user_id'] = user['user_id']
            session['employee_id'] = user['employee_id']
            session['username'] = user['username']
            session['name'] = user['name']
            session['role'] = user['role']
            session.permanent = remember_me
            
            return jsonify({
                'success': True,
                'message': '登录成功',
                'user': {
                    'username': user['username'],
                    'name': user['name'],
                    'role': user['role']
                }
            })
    except Exception as e:
        return jsonify({'success': False, 'message': f'登录失败: {str(e)}'})
    finally:
        conn.close()

@app.route('/api/register', methods=['POST'])
def register():
    """用户注册"""
    data = request.json
    
    # 验证必填字段
    required_fields = ['emp_code', 'name', 'gender', 'id_card', 'hire_date', 'password']
    for field in required_fields:
        if not data.get(field):
            return jsonify({'success': False, 'message': f'{field}不能为空'})
    
    # 验证密码长度
    if len(data['password']) < 6:
        return jsonify({'success': False, 'message': '密码至少需要6位'})
    
    # 验证身份证号和手机号格式
    if len(data['id_card']) != 18:
        return jsonify({'success': False, 'message': '身份证号必须为18位'})
    
    if data.get('phone') and len(data['phone']) != 11:
        return jsonify({'success': False, 'message': '手机号必须为11位'})
    
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # 检查工号是否已存在
            cursor.execute("SELECT employee_id FROM employee WHERE emp_code = %s", (data['emp_code'],))
            if cursor.fetchone():
                return jsonify({'success': False, 'message': '该工号已被注册'})
            
            # 检查身份证号是否已存在
            cursor.execute("SELECT employee_id FROM employee WHERE id_card = %s", (data['id_card'],))
            if cursor.fetchone():
                return jsonify({'success': False, 'message': '该身份证号已被注册'})
            
            # 插入员工表
            cursor.execute("""
                INSERT INTO employee (emp_code, name, gender, id_card, phone, address, hire_date, status)
                VALUES (%s, %s, %s, %s, %s, %s, %s, '在职')
            """, (
                data['emp_code'],
                data['name'],
                data['gender'],
                data['id_card'],
                data.get('phone'),
                data.get('address'),
                data['hire_date']
            ))
            
            employee_id = cursor.lastrowid
            
            # 创建用户凭证
            password_hash, salt = hash_password(data['password'])
            avatar = data.get('avatar')  # 获取头像（可选）
            cursor.execute("""
                INSERT INTO user_credentials (employee_id, username, password_hash, salt, role, avatar, is_active)
                VALUES (%s, %s, %s, %s, 'employee', %s, 1)
            """, (employee_id, data['emp_code'], password_hash, salt, avatar))
            
            conn.commit()
            
            return jsonify({
                'success': True,
                'message': '注册成功，请使用您设置的密码登录',
                'employee_id': employee_id
            })
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'message': f'注册失败: {str(e)}'})
    finally:
        conn.close()

@app.route('/api/logout', methods=['POST'])
def logout():
    """用户登出"""
    session.clear()
    return jsonify({'success': True, 'message': '已成功登出'})

@app.route('/api/current-user')
@login_required
def get_current_user():
    """获取当前登录用户信息"""
    # 从数据库获取完整用户信息，包括头像
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT avatar FROM user_credentials WHERE user_id = %s
            """, (session.get('user_id'),))
            user_data = cursor.fetchone()
            
            return jsonify({
                'success': True,
                'user': {
                    'user_id': session.get('user_id'),
                    'username': session.get('username'),
                    'name': session.get('name'),
                    'role': session.get('role'),
                    'avatar': user_data['avatar'] if user_data else None
                }
            })
    except Exception as e:
        return jsonify({
            'success': True,
            'user': {
                'user_id': session.get('user_id'),
                'username': session.get('username'),
                'name': session.get('name'),
                'role': session.get('role'),
                'avatar': None
            }
        })
    finally:
        conn.close()

# ==================== 仪表盘API ====================

@app.route('/api/dashboard/charts')
@login_required
def get_dashboard_charts():
    """获取仪表盘图表数据"""
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # 1. 近30天违章趋势
            cursor.execute("""
                SELECT DATE(violation_time) as date, COUNT(*) as count
                FROM violation_record
                WHERE violation_time >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
                GROUP BY DATE(violation_time)
                ORDER BY date
            """)
            trend_data = cursor.fetchall()
            
            # 2. 违章类型分布
            cursor.execute("""
                SELECT vt.type_name, COUNT(*) as count
                FROM violation_record v
                INNER JOIN violation_type vt ON v.violation_type_id = vt.type_id
                GROUP BY v.violation_type_id, vt.type_name
                ORDER BY count DESC
                LIMIT 10
            """)
            type_data = cursor.fetchall()
            
            # 3. 车辆状态分布
            cursor.execute("""
                SELECT status, COUNT(*) as count
                FROM bus
                GROUP BY status
            """)
            bus_status_data = cursor.fetchall()
            
            # 4. 车队违章排名
            cursor.execute("""
                SELECT f.fleet_name, COUNT(v.record_id) as count
                FROM fleet f
                LEFT JOIN violation_record v ON f.fleet_id = v.fleet_id
                GROUP BY f.fleet_id, f.fleet_name
                ORDER BY count DESC
            """)
            fleet_ranking_data = cursor.fetchall()
            
            # 5. 违章严重程度分布
            cursor.execute("""
                SELECT vt.severity, COUNT(*) as count
                FROM violation_record v
                INNER JOIN violation_type vt ON v.violation_type_id = vt.type_id
                GROUP BY vt.severity
            """)
            severity_data = cursor.fetchall()
            
            return jsonify({
                'success': True,
                'data': {
                    'trend': [{'date': row['date'].isoformat(), 'count': row['count']} for row in trend_data],
                    'violationType': [{'name': row['type_name'], 'value': row['count']} for row in type_data],
                    'busStatus': [{'name': row['status'], 'value': row['count']} for row in bus_status_data],
                    'fleetRanking': [{'name': row['fleet_name'], 'value': row['count']} for row in fleet_ranking_data],
                    'severity': [{'name': row['severity'], 'value': row['count']} for row in severity_data]
                }
            })
    except Exception as e:
        return jsonify({'success': False, 'message': f'获取图表数据失败: {str(e)}'})
    finally:
        conn.close()

# ==================== 用户管理API（仅管理员） ====================

@app.route('/api/users')
@admin_required
def get_all_users():
    """获取所有用户（仅管理员）"""
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT user_id, employee_id, username, name, gender, phone, 
                       hire_date, employee_status, role, avatar, is_active, 
                       last_login, login_attempts, locked_until, created_at
                FROM v_user_info
                ORDER BY created_at DESC
            """)
            users = cursor.fetchall()
            
            # 处理日期序列化
            for user in users:
                for key in ['hire_date', 'last_login', 'locked_until', 'created_at']:
                    if user.get(key):
                        user[key] = user[key].isoformat()
            
            return jsonify({'success': True, 'data': users})
    except Exception as e:
        return jsonify({'success': False, 'message': f'获取用户列表失败: {str(e)}'})
    finally:
        conn.close()

@app.route('/api/users/<int:user_id>', methods=['GET'])
@admin_required
def get_user(user_id):
    """获取单个用户信息"""
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT * FROM v_user_info WHERE user_id = %s
            """, (user_id,))
            user = cursor.fetchone()
            
            if not user:
                return jsonify({'success': False, 'message': '用户不存在'})
            
            # 处理日期序列化
            for key in ['hire_date', 'last_login', 'locked_until', 'created_at', 'updated_at']:
                if user.get(key):
                    user[key] = user[key].isoformat()
            
            return jsonify({'success': True, 'data': user})
    except Exception as e:
        return jsonify({'success': False, 'message': f'获取用户信息失败: {str(e)}'})
    finally:
        conn.close()

@app.route('/api/users/<int:user_id>', methods=['PUT'])
@admin_required
def update_user(user_id):
    """更新用户信息（仅管理员）"""
    data = request.json
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # 更新用户凭证表
            if 'role' in data or 'is_active' in data or 'avatar' in data:
                update_fields = []
                params = []
                
                if 'role' in data:
                    update_fields.append('role = %s')
                    params.append(data['role'])
                
                if 'is_active' in data:
                    update_fields.append('is_active = %s')
                    params.append(1 if data['is_active'] else 0)
                
                if 'avatar' in data:
                    update_fields.append('avatar = %s')
                    params.append(data['avatar'])
                
                params.append(user_id)
                
                cursor.execute(f"""
                    UPDATE user_credentials 
                    SET {', '.join(update_fields)}
                    WHERE user_id = %s
                """, params)
            
            conn.commit()
            return jsonify({'success': True, 'message': '用户信息更新成功'})
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'message': f'更新失败: {str(e)}'})
    finally:
        conn.close()

@app.route('/api/users/<int:user_id>', methods=['DELETE'])
@admin_required
def delete_user(user_id):
    """删除用户（仅管理员）"""
    # 不允许删除自己
    if user_id == session.get('user_id'):
        return jsonify({'success': False, 'message': '不能删除自己的账号'})
    
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("DELETE FROM user_credentials WHERE user_id = %s", (user_id,))
            conn.commit()
            return jsonify({'success': True, 'message': '用户已删除'})
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'message': f'删除失败: {str(e)}'})
    finally:
        conn.close()

@app.route('/api/users/<int:user_id>/reset-password', methods=['POST'])
@admin_required
def admin_reset_password(user_id):
    """管理员重置用户密码"""
    data = request.json
    new_password = data.get('new_password')
    
    if not new_password or len(new_password) < 6:
        return jsonify({'success': False, 'message': '新密码至少需要6位'})
    
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            password_hash, salt = hash_password(new_password)
            cursor.execute("""
                UPDATE user_credentials 
                SET password_hash = %s, salt = %s, login_attempts = 0, locked_until = NULL
                WHERE user_id = %s
            """, (password_hash, salt, user_id))
            conn.commit()
            return jsonify({'success': True, 'message': '密码重置成功'})
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'message': f'重置失败: {str(e)}'})
    finally:
        conn.close()

@app.route('/api/users/unlock/<int:user_id>', methods=['POST'])
@admin_required
def unlock_user(user_id):
    """解锁用户账号"""
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                UPDATE user_credentials 
                SET login_attempts = 0, locked_until = NULL
                WHERE user_id = %s
            """, (user_id,))
            conn.commit()
            return jsonify({'success': True, 'message': '账号已解锁'})
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'message': f'解锁失败: {str(e)}'})
    finally:
        conn.close()

@app.route('/api/avatars')
def get_avatars():
    """获取可用的头像列表（公开访问，注册页面需要）"""
    import os
    avatars_dir = os.path.join(app.static_folder, 'avatars')
    try:
        if os.path.exists(avatars_dir):
            avatar_files = [f for f in os.listdir(avatars_dir) if f.endswith(('.png', '.jpg', '.jpeg', '.gif'))]
            return jsonify({'success': True, 'avatars': sorted(avatar_files)})
        else:
            return jsonify({'success': False, 'message': '头像目录不存在', 'avatars': []})
    except Exception as e:
        return jsonify({'success': False, 'message': f'获取头像列表失败: {str(e)}', 'avatars': []})

@app.route('/api/profile', methods=['PUT'])
@login_required
def update_profile():
    """用户更新自己的资料"""
    data = request.json
    user_id = session.get('user_id')
    
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # 允许用户修改头像
            if 'avatar' in data:
                cursor.execute("""
                    UPDATE user_credentials 
                    SET avatar = %s
                    WHERE user_id = %s
                """, (data['avatar'], user_id))
            
            conn.commit()
            return jsonify({'success': True, 'message': '资料更新成功'})
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'message': f'更新失败: {str(e)}'})
    finally:
        conn.close()

@app.route('/api/change-password', methods=['POST'])
@login_required
def change_password():
    """用户修改自己的密码"""
    data = request.json
    old_password = data.get('old_password')
    new_password = data.get('new_password')
    
    if not old_password or not new_password:
        return jsonify({'success': False, 'message': '旧密码和新密码不能为空'})
    
    if len(new_password) < 6:
        return jsonify({'success': False, 'message': '新密码至少需要6位'})
    
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # 验证旧密码
            cursor.execute("""
                SELECT password_hash, salt FROM user_credentials WHERE user_id = %s
            """, (session['user_id'],))
            user = cursor.fetchone()
            
            if not user or not verify_password(old_password, user['password_hash'], user['salt']):
                return jsonify({'success': False, 'message': '原密码错误'})
            
            # 更新密码
            password_hash, salt = hash_password(new_password)
            cursor.execute("""
                UPDATE user_credentials 
                SET password_hash = %s, salt = %s
                WHERE user_id = %s
            """, (password_hash, salt, session['user_id']))
            conn.commit()
            
            return jsonify({'success': True, 'message': '密码修改成功，请重新登录'})
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'message': f'修改失败: {str(e)}'})
    finally:
        conn.close()

# ==================== API路由 ====================

# ---------- 基础数据查询 ----------

@app.route('/api/fleets')
def get_fleets():
    """获取所有车队"""
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT f.fleet_id, f.fleet_code, f.fleet_name, 
                       e.name AS captain_name,
                       (SELECT COUNT(*) FROM route r WHERE r.fleet_id = f.fleet_id) AS route_count,
                       (SELECT COUNT(*) FROM driver d INNER JOIN route r ON d.route_id = r.route_id WHERE r.fleet_id = f.fleet_id) AS driver_count
                FROM fleet f
                LEFT JOIN employee e ON f.captain_id = e.employee_id
                ORDER BY f.fleet_code
            """)
            return jsonify({'success': True, 'data': cursor.fetchall()})
    finally:
        conn.close()

@app.route('/api/routes')
def get_routes():
    """获取所有线路"""
    fleet_id = request.args.get('fleet_id')
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            sql = """
                SELECT r.route_id, r.route_code, r.route_name, r.fleet_id,
                       f.fleet_name, r.start_station, r.end_station, r.status
                FROM route r
                INNER JOIN fleet f ON r.fleet_id = f.fleet_id
            """
            if fleet_id:
                sql += " WHERE r.fleet_id = %s"
                cursor.execute(sql + " ORDER BY r.route_code", (fleet_id,))
            else:
                cursor.execute(sql + " ORDER BY f.fleet_code, r.route_code")
            return jsonify({'success': True, 'data': cursor.fetchall()})
    finally:
        conn.close()

@app.route('/api/drivers')
def get_drivers():
    """获取所有司机"""
    fleet_id = request.args.get('fleet_id')
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            sql = """
                SELECT d.driver_id, e.emp_code, e.name, e.gender, e.phone,
                       e.hire_date, d.license_no, d.license_type, d.driving_years,
                       d.is_route_captain, d.route_id, r.route_code, r.route_name,
                       f.fleet_id, f.fleet_name
                FROM driver d
                INNER JOIN employee e ON d.driver_id = e.employee_id
                LEFT JOIN route r ON d.route_id = r.route_id
                LEFT JOIN fleet f ON r.fleet_id = f.fleet_id
            """
            if fleet_id:
                sql += " WHERE f.fleet_id = %s"
                cursor.execute(sql + " ORDER BY r.route_code, e.emp_code", (fleet_id,))
            else:
                cursor.execute(sql + " ORDER BY f.fleet_name, r.route_code, e.emp_code")
            
            data = cursor.fetchall()
            # 处理日期序列化
            for row in data:
                if row.get('hire_date'):
                    row['hire_date'] = row['hire_date'].isoformat()
            return jsonify({'success': True, 'data': data})
    finally:
        conn.close()

@app.route('/api/buses')
def get_buses():
    """获取所有车辆"""
    route_id = request.args.get('route_id')
    status = request.args.get('status')
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            sql = """
                SELECT b.bus_id, b.plate_number, b.bus_code, b.model, b.brand,
                       b.seats, b.status, b.route_id, r.route_code, r.route_name,
                       b.purchase_date, b.last_maintenance_date, b.next_maintenance_date
                FROM bus b
                LEFT JOIN route r ON b.route_id = r.route_id
            """
            conditions = []
            params = []
            
            if route_id:
                conditions.append("b.route_id = %s")
                params.append(route_id)
            
            if status:
                conditions.append("b.status = %s")
                params.append(status)
            
            if conditions:
                sql += " WHERE " + " AND ".join(conditions)
            
            sql += " ORDER BY r.route_code, b.plate_number"
            
            cursor.execute(sql, tuple(params) if params else None)
            return jsonify({'success': True, 'data': cursor.fetchall()})
    finally:
        conn.close()

@app.route('/api/violation-types')
def get_violation_types():
    """获取所有违章类型"""
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT type_id, type_code, type_name, penalty_points, 
                       fine_amount, severity
                FROM violation_type ORDER BY type_id
            """)
            data = cursor.fetchall()
            for row in data:
                if row.get('fine_amount'):
                    row['fine_amount'] = float(row['fine_amount'])
            return jsonify({'success': True, 'data': data})
    finally:
        conn.close()

@app.route('/api/stations')
def get_stations():
    """获取所有站点"""
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT station_id, station_code, station_name FROM station ORDER BY station_code")
            return jsonify({'success': True, 'data': cursor.fetchall()})
    finally:
        conn.close()

# ---------- 功能1：录入司机信息 ----------

@app.route('/api/driver', methods=['POST'])
def add_driver():
    """添加司机"""
    data = request.json
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # 插入员工表
            cursor.execute("""
                INSERT INTO employee (emp_code, name, gender, id_card, phone, address, hire_date)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            """, (data['emp_code'], data['name'], data['gender'], data['id_card'],
                  data.get('phone'), data.get('address'), data['hire_date']))
            
            employee_id = cursor.lastrowid
            
            # 插入司机表
            cursor.execute("""
                INSERT INTO driver (driver_id, license_no, license_type, license_expire_date, 
                                   driving_years, route_id)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (employee_id, data['license_no'], data['license_type'], 
                  data['license_expire_date'], data.get('driving_years', 0),
                  data.get('route_id') or None))
            
            # 自动为新司机创建用户账号
            # 默认密码：123456
            default_password = '123456'
            password_hash, salt = hash_password(default_password)
            cursor.execute("""
                INSERT INTO user_credentials (employee_id, username, password_hash, salt, role, is_active)
                VALUES (%s, %s, %s, %s, 'driver', 1)
            """, (employee_id, data['emp_code'], password_hash, salt))
            
            conn.commit()
            return jsonify({'success': True, 'message': '司机添加成功，默认密码：123456', 'id': employee_id})
    except Exception as e:
        conn.rollback()
        error_msg = str(e)
        # 解析MySQL错误，返回友好提示
        if '1062' in error_msg or 'Duplicate entry' in error_msg:
            if 'emp_code' in error_msg:
                error_msg = '该工号已存在，请使用其他工号'
            elif 'id_card' in error_msg:
                error_msg = '该身份证号已被使用，请检查身份证号是否正确'
            elif 'license_no' in error_msg:
                error_msg = '该驾驶证号已存在'
            else:
                error_msg = '数据重复，请检查输入信息'
        elif '1048' in error_msg or 'cannot be null' in error_msg:
            error_msg = '必填字段不能为空，请检查所有必填项'
        elif '1452' in error_msg:
            error_msg = '线路不存在，请选择有效的线路'
        return jsonify({'success': False, 'message': error_msg})
    finally:
        conn.close()

# ---------- 功能2：录入车辆信息 ----------

@app.route('/api/bus', methods=['POST'])
def add_bus():
    """添加车辆"""
    data = request.json
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO bus (plate_number, bus_code, model, brand, seats, 
                                purchase_date, route_id, status)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """, (data['plate_number'], data['bus_code'], data.get('model'),
                  data.get('brand'), data.get('seats'), data.get('purchase_date'),
                  data.get('route_id') or None, data.get('status', '运营中')))
            
            conn.commit()
            return jsonify({'success': True, 'message': '车辆添加成功', 'id': cursor.lastrowid})
    except Exception as e:
        conn.rollback()
        error_msg = str(e)
        # 解析MySQL错误，返回友好提示
        if '1062' in error_msg or 'Duplicate entry' in error_msg:
            if 'plate_number' in error_msg:
                error_msg = '该车牌号已存在，请检查车牌号是否正确'
            elif 'bus_code' in error_msg:
                error_msg = '该车辆编号已存在，请使用其他编号'
            else:
                error_msg = '数据重复，请检查输入信息'
        elif '1048' in error_msg or 'cannot be null' in error_msg:
            error_msg = '必填字段不能为空，请检查所有必填项'
        elif '1452' in error_msg:
            error_msg = '线路不存在，请选择有效的线路'
        return jsonify({'success': False, 'message': error_msg})
    finally:
        conn.close()

@app.route('/api/bus/<int:bus_id>', methods=['GET'])
def get_bus(bus_id):
    """获取单个车辆信息"""
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT b.bus_id, b.plate_number, b.bus_code, b.model, b.brand,
                       b.seats, b.status, b.route_id, b.purchase_date,
                       r.route_code, r.route_name
                FROM bus b
                LEFT JOIN route r ON b.route_id = r.route_id
                WHERE b.bus_id = %s
            """, (bus_id,))
            bus = cursor.fetchone()
            if bus:
                return jsonify({'success': True, 'data': bus})
            else:
                return jsonify({'success': False, 'message': '车辆不存在'})
    finally:
        conn.close()

@app.route('/api/bus/<int:bus_id>', methods=['PUT'])
def update_bus(bus_id):
    """更新车辆信息"""
    data = request.json
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                UPDATE bus 
                SET plate_number = %s, bus_code = %s, model = %s, brand = %s,
                    seats = %s, purchase_date = %s, route_id = %s, status = %s
                WHERE bus_id = %s
            """, (data['plate_number'], data['bus_code'], data.get('model'),
                  data.get('brand'), data.get('seats'), data.get('purchase_date'),
                  data.get('route_id') or None, data.get('status', '运营中'), bus_id))
            
            conn.commit()
            return jsonify({'success': True, 'message': '车辆信息更新成功'})
    except Exception as e:
        conn.rollback()
        error_msg = str(e)
        # 解析MySQL错误，返回友好提示
        if '1062' in error_msg or 'Duplicate entry' in error_msg:
            if 'plate_number' in error_msg:
                error_msg = '该车牌号已被其他车辆使用'
            elif 'bus_code' in error_msg:
                error_msg = '该车辆编号已被其他车辆使用'
            else:
                error_msg = '数据重复，请检查输入信息'
        elif '1048' in error_msg or 'cannot be null' in error_msg:
            error_msg = '必填字段不能为空'
        elif '1452' in error_msg:
            error_msg = '线路不存在，请选择有效的线路'
        return jsonify({'success': False, 'message': error_msg})
    finally:
        conn.close()

# ---------- 视频上传功能 ----------

def allowed_video_file(filename):
    """检查是否为允许的视频文件"""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_VIDEO_EXTENSIONS

@app.route('/api/upload-video', methods=['POST'])
def upload_video():
    """上传违章视频"""
    if 'video' not in request.files:
        return jsonify({'success': False, 'message': '没有上传文件'})
    
    file = request.files['video']
    
    if file.filename == '':
        return jsonify({'success': False, 'message': '没有选择文件'})
    
    if not allowed_video_file(file.filename):
        return jsonify({'success': False, 'message': '不支持的视频格式，仅支持: ' + ', '.join(ALLOWED_VIDEO_EXTENSIONS)})
    
    try:
        # 生成唯一文件名
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        random_str = secrets.token_hex(4)
        original_ext = file.filename.rsplit('.', 1)[1].lower()
        filename = f"violation_{timestamp}_{random_str}.{original_ext}"
        
        # 保存文件
        filepath = os.path.join(app.config['VIDEO_FOLDER'], filename)
        file.save(filepath)
        
        # 返回相对URL
        video_url = f'/static/uploads/videos/{filename}'
        
        return jsonify({
            'success': True, 
            'message': '视频上传成功',
            'video_url': video_url,
            'filename': filename
        })
    except Exception as e:
        return jsonify({'success': False, 'message': f'上传失败: {str(e)}'})

# ---------- 功能3：录入违章信息 ----------

@app.route('/api/violation', methods=['POST'])
def add_violation():
    """添加违章记录"""
    data = request.json
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # 获取司机所属车队和线路
            cursor.execute("""
                SELECT r.fleet_id, d.route_id
                FROM driver d
                INNER JOIN route r ON d.route_id = r.route_id
                WHERE d.driver_id = %s
            """, (data['driver_id'],))
            
            driver_info = cursor.fetchone()
            if not driver_info:
                return jsonify({'success': False, 'message': '司机不存在或未分配线路'})
            
            # 插入违章记录
            cursor.execute("""
                INSERT INTO violation_record (driver_id, bus_id, fleet_id, route_id,
                    station_id, violation_type_id, violation_time, violation_location,
                    recorded_by, remarks, video_url)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (data['driver_id'], data['bus_id'], driver_info['fleet_id'],
                  driver_info['route_id'], data.get('station_id') or None,
                  data['violation_type_id'], data['violation_time'],
                  data.get('violation_location'), data['recorded_by'],
                  data.get('remarks'), data.get('video_url')))
            
            conn.commit()
            return jsonify({'success': True, 'message': '违章记录添加成功', 'id': cursor.lastrowid})
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'message': str(e)})
    finally:
        conn.close()

# ---------- 功能4：查询车队司机 ----------

@app.route('/api/drivers/by-fleet/<int:fleet_id>')
def get_drivers_by_fleet(fleet_id):
    """查询某车队下的司机"""
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT d.driver_id, e.emp_code, e.name, e.gender, e.phone,
                       e.id_card, e.hire_date, e.status AS emp_status,
                       d.license_no, d.license_type, d.license_expire_date,
                       d.driving_years, d.is_route_captain,
                       r.route_code, r.route_name
                FROM driver d
                INNER JOIN employee e ON d.driver_id = e.employee_id
                LEFT JOIN route r ON d.route_id = r.route_id
                LEFT JOIN fleet f ON r.fleet_id = f.fleet_id
                WHERE f.fleet_id = %s
                ORDER BY r.route_code, e.emp_code
            """, (fleet_id,))
            
            data = cursor.fetchall()
            for row in data:
                for key in ['hire_date', 'license_expire_date']:
                    if row.get(key):
                        row[key] = row[key].isoformat()
            return jsonify({'success': True, 'data': data})
    finally:
        conn.close()

# ---------- 功能5：查询司机违章详情 ----------

@app.route('/api/violations/by-driver')
def get_violations_by_driver():
    """查询司机在指定时间段的违章"""
    driver_id = request.args.get('driver_id')
    start_date = request.args.get('start_date')
    end_date = request.args.get('end_date')
    
    if not all([driver_id, start_date, end_date]):
        return jsonify({'success': False, 'message': '缺少必要参数'})
    
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT vr.record_id, vr.violation_time, vr.violation_location,
                       vr.status, vr.remarks, vr.video_url,
                       e.name AS driver_name, e.emp_code,
                       b.plate_number, r.route_code,
                       s.station_name,
                       vt.type_name AS violation_name, vt.penalty_points,
                       vt.fine_amount, vt.severity,
                       er.name AS recorder_name
                FROM violation_record vr
                INNER JOIN driver d ON vr.driver_id = d.driver_id
                INNER JOIN employee e ON d.driver_id = e.employee_id
                INNER JOIN bus b ON vr.bus_id = b.bus_id
                INNER JOIN route r ON vr.route_id = r.route_id
                LEFT JOIN station s ON vr.station_id = s.station_id
                INNER JOIN violation_type vt ON vr.violation_type_id = vt.type_id
                INNER JOIN employee er ON vr.recorded_by = er.employee_id
                WHERE vr.driver_id = %s
                  AND DATE(vr.violation_time) >= %s
                  AND DATE(vr.violation_time) <= %s
                ORDER BY vr.violation_time DESC
            """, (driver_id, start_date, end_date))
            
            data = cursor.fetchall()
            for row in data:
                if row.get('violation_time'):
                    row['violation_time'] = row['violation_time'].isoformat()
                if row.get('fine_amount'):
                    row['fine_amount'] = float(row['fine_amount'])
            
            # 计算统计
            total_points = sum(r.get('penalty_points', 0) or 0 for r in data)
            total_fine = sum(r.get('fine_amount', 0) or 0 for r in data)
            
            return jsonify({
                'success': True, 
                'data': data,
                'stats': {
                    'count': len(data),
                    'total_points': total_points,
                    'total_fine': total_fine
                }
            })
    finally:
        conn.close()

@app.route('/api/violation/<int:record_id>', methods=['DELETE'])
def delete_violation(record_id):
    """删除违章记录"""
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # 先检查记录是否存在
            cursor.execute("SELECT record_id FROM violation_record WHERE record_id = %s", (record_id,))
            if not cursor.fetchone():
                return jsonify({'success': False, 'message': '违章记录不存在'})
            
            # 删除记录
            cursor.execute("DELETE FROM violation_record WHERE record_id = %s", (record_id,))
            conn.commit()
            
            return jsonify({'success': True, 'message': '违章记录已删除'})
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'message': f'删除失败: {str(e)}'})
    finally:
        conn.close()

# ---------- 功能6：查询车队违章统计 ----------

@app.route('/api/violations/stats-by-fleet')
def get_violation_stats_by_fleet():
    """查询车队违章统计"""
    fleet_id = request.args.get('fleet_id')
    start_date = request.args.get('start_date')
    end_date = request.args.get('end_date')
    
    if not all([fleet_id, start_date, end_date]):
        return jsonify({'success': False, 'message': '缺少必要参数'})
    
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT vt.type_name, vt.severity,
                       COUNT(*) AS count,
                       SUM(vt.penalty_points) AS total_points,
                       SUM(vt.fine_amount) AS total_fine
                FROM violation_record vr
                INNER JOIN violation_type vt ON vr.violation_type_id = vt.type_id
                WHERE vr.fleet_id = %s
                  AND DATE(vr.violation_time) >= %s
                  AND DATE(vr.violation_time) <= %s
                  AND vr.status != '已撤销'
                GROUP BY vt.type_id, vt.type_name, vt.severity
                ORDER BY count DESC
            """, (fleet_id, start_date, end_date))
            
            data = cursor.fetchall()
            for row in data:
                if row.get('total_fine'):
                    row['total_fine'] = float(row['total_fine'])
            
            # 总计
            total_count = sum(r['count'] for r in data)
            total_points = sum(r.get('total_points', 0) or 0 for r in data)
            total_fine = sum(r.get('total_fine', 0) or 0 for r in data)
            
            return jsonify({
                'success': True,
                'data': data,
                'stats': {
                    'total_count': total_count,
                    'total_points': total_points,
                    'total_fine': total_fine
                }
            })
    finally:
        conn.close()

# ---------- 获取管理人员列表（队长和路队长） ----------

@app.route('/api/managers')
def get_managers():
    """获取有管理权限的人员（队长和路队长）"""
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT e.employee_id, e.emp_code, e.name, '队长' AS role, f.fleet_name AS dept
                FROM employee e
                INNER JOIN fleet f ON e.employee_id = f.captain_id
                UNION
                SELECT e.employee_id, e.emp_code, e.name, '路队长' AS role, r.route_name AS dept
                FROM employee e
                INNER JOIN driver d ON e.employee_id = d.driver_id
                INNER JOIN route r ON d.route_id = r.route_id
                WHERE d.is_route_captain = 1
                ORDER BY role, dept
            """)
            return jsonify({'success': True, 'data': cursor.fetchall()})
    finally:
        conn.close()

# ========== AI智能助手API ==========

# DeepSeek API配置
DEEPSEEK_API_KEY = "sk-00b42e6023f2492cadb7a1a4e7b17e27"
DEEPSEEK_API_URL = "https://api.deepseek.com/v1/chat/completions"

# 数据库表结构描述（供AI生成SQL使用）
DB_SCHEMA_DESC = """
【数据库名】bus_safety_system（MySQL）

【数据库表结构】
1. employee（员工基础信息表）
   - employee_id INT PRIMARY KEY AUTO_INCREMENT  -- 员工ID
   - emp_code VARCHAR(20) UNIQUE  -- 员工工号
   - name VARCHAR(50)  -- 姓名
   - gender ENUM('男','女')  -- 性别
   - id_card VARCHAR(18) UNIQUE  -- 身份证号
   - phone VARCHAR(11)  -- 联系电话
   - address VARCHAR(200)  -- 家庭住址
   - hire_date DATE  -- 入职日期
   - status ENUM('在职','离职','休假')  -- 状态

2. fleet（车队信息表）
   - fleet_id INT PRIMARY KEY AUTO_INCREMENT  -- 车队ID
   - fleet_code VARCHAR(20) UNIQUE  -- 车队编号
   - fleet_name VARCHAR(100)  -- 车队名称
   - captain_id INT  -- 队长ID（关联employee.employee_id）
   - description VARCHAR(500)  -- 描述

3. route（公交线路表）
   - route_id INT PRIMARY KEY AUTO_INCREMENT  -- 线路ID
   - route_code VARCHAR(20) UNIQUE  -- 线路编号（如101路）
   - route_name VARCHAR(100)  -- 线路名称
   - fleet_id INT  -- 所属车队ID（关联fleet.fleet_id）
   - start_station VARCHAR(100)  -- 起点站
   - end_station VARCHAR(100)  -- 终点站
   - total_distance DECIMAL(10,2)  -- 总里程
   - ticket_price DECIMAL(5,2)  -- 票价
   - status ENUM('运营中','停运','调整中')

4. driver（司机信息表，继承employee）
   - driver_id INT PRIMARY KEY  -- 司机ID（=employee_id）
   - license_no VARCHAR(20) UNIQUE  -- 驾驶证号
   - license_type ENUM('A1','A3','B1')  -- 驾照类型
   - license_expire_date DATE  -- 驾照有效期
   - route_id INT  -- 所属线路ID（关联route.route_id）
   - is_route_captain TINYINT(1)  -- 是否路队长(0/1)
   - driving_years INT  -- 驾龄

5. bus（公交车辆表）
   - bus_id INT PRIMARY KEY AUTO_INCREMENT  -- 车辆ID
   - plate_number VARCHAR(10) UNIQUE  -- 车牌号
   - bus_code VARCHAR(20) UNIQUE  -- 车辆编号
   - model VARCHAR(50)  -- 车型
   - brand VARCHAR(50)  -- 品牌
   - seats INT  -- 座位数
   - purchase_date DATE  -- 购置日期
   - route_id INT  -- 所属线路ID
   - status ENUM('运营中','维修中','报废','备用')

6. station（公交站点表）
   - station_id INT PRIMARY KEY AUTO_INCREMENT
   - station_code VARCHAR(20) UNIQUE  -- 站点编号
   - station_name VARCHAR(100)  -- 站点名称
   - address VARCHAR(200)

7. violation_type（违章类型表）
   - type_id INT PRIMARY KEY AUTO_INCREMENT
   - type_code VARCHAR(20) UNIQUE  -- 违章代码
   - type_name VARCHAR(100)  -- 违章名称（闯红灯/未礼让斑马线/压线/违章停车等）
   - penalty_points INT  -- 扣分
   - fine_amount DECIMAL(10,2)  -- 罚款
   - severity ENUM('轻微','一般','严重','特别严重')

8. violation_record（违章记录表）
   - record_id INT PRIMARY KEY AUTO_INCREMENT
   - driver_id INT  -- 违章司机ID
   - bus_id INT  -- 违章车辆ID
   - fleet_id INT  -- 所属车队ID
   - route_id INT  -- 所属线路ID
   - station_id INT  -- 违章站点ID
   - violation_type_id INT  -- 违章类型ID
   - violation_time DATETIME  -- 违章时间
   - violation_location VARCHAR(200)  -- 违章地点
   - recorded_by INT  -- 记录人ID
   - status ENUM('待处理','已确认','已申诉','已撤销')
   - remarks VARCHAR(500)
   - video_url VARCHAR(500)

【常用视图】
- v_driver_info: 司机完整信息（含员工信息+线路+车队）
- v_violation_detail: 违章记录详情（含所有关联信息）
- v_driver_violation_stats: 司机违章统计
- v_fleet_violation_stats: 车队违章统计
"""

# 自然语言转SQL的系统提示词
NL2SQL_SYSTEM_PROMPT = """你是一个专业的SQL生成助手，负责将用户的自然语言请求转换为MySQL SQL语句并解读执行结果。

""" + DB_SCHEMA_DESC + """

【你的工作流程】
用户会用自然语言描述想要查询或修改的数据库操作，你需要：
1. 分析用户意图，判断是查询(SELECT)还是修改(INSERT/UPDATE/DELETE)操作
2. 生成对应的SQL语句
3. 将SQL语句用特殊标记包裹，格式为：```sql\nSQL语句\n```
4. 在SQL之后，简要说明这条SQL的作用

【重要规则】
- 只生成与公交安全管理系统相关的SQL
- SELECT查询可以直接执行
- INSERT/UPDATE/DELETE修改操作也可以执行，但要在SQL前提醒用户这是修改操作
- 禁止生成DROP TABLE、DROP DATABASE、TRUNCATE等破坏性操作
- 禁止修改表结构（ALTER TABLE）
- 每次只生成一条SQL语句
- SQL语句末尾不要加分号
- 使用中文别名让结果更易读
- 如果用户请求不明确，请主动询问补充信息
- 如果用户的请求与数据库操作无关（如闲聊、问系统功能），正常回复即可，不需要生成SQL

【示例】
用户："查询第一车队的所有司机"
回复：我来帮您查询第一车队的所有司机信息：
```sql
SELECT e.emp_code AS 工号, e.name AS 姓名, e.gender AS 性别, e.phone AS 电话, r.route_name AS 所属线路, CASE WHEN d.is_route_captain=1 THEN '是' ELSE '否' END AS 是否路队长 FROM driver d INNER JOIN employee e ON d.driver_id = e.employee_id LEFT JOIN route r ON d.route_id = r.route_id LEFT JOIN fleet f ON r.fleet_id = f.fleet_id WHERE f.fleet_name LIKE '%第一车队%'
```
这条SQL会查询第一车队下所有司机的基本信息，包括工号、姓名、性别、电话、所属线路和是否为路队长。

用户："把司机赵大勇的电话改为13999999999"
回复：这是一条**修改操作**，将更新司机赵大勇的电话号码：
```sql
UPDATE employee SET phone = '13999999999' WHERE name = '赵大勇'
```
这条SQL会将姓名为"赵大勇"的员工电话修改为13999999999。
"""

# 普通聊天系统提示词
SYSTEM_PROMPT = """你是一个专业的公交安全管理系统智能助手。你的任务是帮助用户理解和使用公交安全管理系统。

【系统功能】
1. **司机管理**
   - 录入司机信息（工号、姓名、驾驶证等）
   - 自动创建用户账号（默认密码：123456）
   - 查询车队司机信息

2. **车辆管理**
   - 录入车辆信息（车牌号、车型、所属车队等）
   - 车辆维护记录管理

3. **违章记录管理**
   - 录入违章信息（司机、车辆、类型、时间、地点等）
   - **支持上传违章视频**（最大100MB，支持MP4/AVI/MOV等格式）
   - 实时视频预览
   - 查询司机违章详情
   - **弹窗查看违章视频**
   - 车队违章统计分析

4. **用户管理**（仅管理员）
   - 查看所有用户
   - 编辑用户角色和状态
   - 重置密码
   - 解锁账号

5. **AI自然语言查询**（新功能）
   - 支持使用自然语言查询数据库信息
   - 支持使用自然语言修改数据库数据
   - AI会自动将自然语言转换为SQL并执行
   - 示例查询："查询第一车队的所有司机"、"统计各车队违章次数"
   - 示例修改："把司机赵大勇的电话改为13999999999"

【用户角色】
- **admin（管理员）**：所有权限
- **captain（车队队长）**：管理车队和违章记录
- **driver（司机）**：查看自己的信息和违章记录

【使用指南】
1. **登录**：使用工号或用户名登录，默认密码123456
2. **录入司机**：填写司机信息后自动创建账号
3. **录入违章**：选择司机、车辆、类型，可上传视频证据
4. **查询违章**：选择司机和时间范围，可点击查看视频
5. **用户管理**：管理员可管理所有用户账号
6. **自然语言查询**：在AI助手中直接输入自然语言描述即可查询或修改数据库

【注意事项】
- 视频文件不能超过100MB
- 支持深色/浅色主题切换
- 所有数据实时保存到MySQL数据库

请用友好、专业的语气回答用户问题，提供清晰的操作步骤和实用建议。"""

def call_deepseek_non_stream(messages, temperature=0.3, max_tokens=2000):
    """调用DeepSeek API（非流式），返回完整回复内容"""
    import requests as req
    try:
        response = req.post(
            DEEPSEEK_API_URL,
            headers={
                'Content-Type': 'application/json',
                'Authorization': f'Bearer {DEEPSEEK_API_KEY}'
            },
            json={
                'model': 'deepseek-chat',
                'messages': messages,
                'temperature': temperature,
                'max_tokens': max_tokens,
                'stream': False
            },
            timeout=60
        )
        if response.status_code == 200:
            result = response.json()
            if 'choices' in result and len(result['choices']) > 0:
                return result['choices'][0]['message']['content']
        return None
    except Exception as e:
        print(f"[AI] DeepSeek非流式调用错误: {str(e)}")
        return None

def extract_sql_from_response(ai_response):
    """从AI回复中提取SQL语句"""
    import re
    # 匹配 ```sql ... ``` 代码块中的SQL
    pattern = r'```sql\s*\n?(.*?)\n?\s*```'
    matches = re.findall(pattern, ai_response, re.DOTALL | re.IGNORECASE)
    if matches:
        sql = matches[0].strip()
        # 移除末尾分号
        if sql.endswith(';'):
            sql = sql[:-1].strip()
        return sql
    return None

def is_dangerous_sql(sql):
    """检查SQL是否包含危险操作"""
    dangerous_keywords = [
        'DROP TABLE', 'DROP DATABASE', 'TRUNCATE', 'ALTER TABLE',
        'CREATE TABLE', 'CREATE DATABASE', 'GRANT', 'REVOKE',
        'DROP INDEX', 'DROP VIEW', 'DROP PROCEDURE', 'DROP FUNCTION'
    ]
    sql_upper = sql.upper().strip()
    for keyword in dangerous_keywords:
        if keyword in sql_upper:
            return True
    return False

def is_modification_sql(sql):
    """检查SQL是否是修改操作"""
    sql_upper = sql.upper().strip()
    return sql_upper.startswith(('INSERT', 'UPDATE', 'DELETE'))

def execute_nl_sql(sql):
    """执行自然语言生成的SQL并返回结果"""
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(sql)
            # 判断是否是SELECT查询
            if sql.strip().upper().startswith('SELECT'):
                rows = cursor.fetchall()
                # 处理日期和Decimal序列化
                for row in rows:
                    for key, val in row.items():
                        if isinstance(val, (datetime, date)):
                            row[key] = val.isoformat()
                        elif isinstance(val, Decimal):
                            row[key] = float(val)
                return {'success': True, 'type': 'query', 'data': rows, 'count': len(rows)}
            else:
                conn.commit()
                affected = cursor.rowcount
                return {'success': True, 'type': 'modify', 'affected_rows': affected}
    except Exception as e:
        conn.rollback()
        return {'success': False, 'error': str(e)}
    finally:
        conn.close()

def format_query_result_as_table(data):
    """将查询结果格式化为Markdown表格"""
    if not data:
        return "查询结果为空，没有找到匹配的数据。"

    # 获取列名
    columns = list(data[0].keys())

    # 构建表头
    header = "| " + " | ".join(str(col) for col in columns) + " |"
    separator = "| " + " | ".join("---" for _ in columns) + " |"

    # 构建数据行（最多显示50行）
    rows = []
    for row in data[:50]:
        row_str = "| " + " | ".join(str(row.get(col, '')) for col in columns) + " |"
        rows.append(row_str)

    table = header + "\n" + separator + "\n" + "\n".join(rows)

    if len(data) > 50:
        table += f"\n\n... 共 {len(data)} 条记录，仅显示前50条"

    return table

@app.route('/api/ai-chat', methods=['POST'])
def ai_chat():
    """AI聊天API - 流式输出，支持自然语言数据库查询"""
    from flask import Response, stream_with_context
    import json
    import re

    try:
        data = request.json
        user_message = data.get('message', '').strip()
        history = data.get('history', [])

        if not user_message:
            return jsonify({'success': False, 'message': '消息不能为空'})

        # 判断是否是数据库查询/修改意图的关键词
        db_keywords = [
            '查询', '查找', '搜索', '查看', '显示', '列出', '统计', '分析',
            '修改', '更新', '更改', '删除', '移除', '添加', '插入', '新增',
            '多少', '哪些', '哪个', '谁', '几个', '几条', '有没有',
            '司机', '车队', '线路', '车辆', '违章', '站点', '车牌',
            '工号', '姓名', '电话', '驾驶证', '扣分', '罚款'
        ]

        # 检查用户消息是否包含数据库操作意图
        has_db_intent = any(kw in user_message for kw in db_keywords)

        if has_db_intent:
            # ===== 自然语言数据库查询模式 =====
            print(f"[AI-NL2SQL] 检测到数据库查询意图: {user_message[:50]}...")

            # Step 1: 调用DeepSeek生成SQL
            nl2sql_messages = [
                {'role': 'system', 'content': NL2SQL_SYSTEM_PROMPT}
            ]
            # 添加历史上下文
            if history:
                nl2sql_messages.extend(history[-10:])
            nl2sql_messages.append({'role': 'user', 'content': user_message})

            ai_response = call_deepseek_non_stream(nl2sql_messages, temperature=0.3, max_tokens=2000)

            if not ai_response:
                # 降级到普通聊天流式模式
                return _stream_chat(user_message, history, SYSTEM_PROMPT)

            # Step 2: 提取SQL
            sql = extract_sql_from_response(ai_response)

            if sql:
                # 安全检查
                if is_dangerous_sql(sql):
                    result_text = "**安全警告**：检测到危险操作，已拒绝执行。\n\n系统不允许执行DROP、TRUNCATE、ALTER等破坏性操作。"
                    return _send_nl2sql_response(user_message, result_text, history)

                print(f"[AI-NL2SQL] 生成SQL: {sql}")

                # Step 3: 执行SQL
                exec_result = execute_nl_sql(sql)

                # Step 4: 组合最终回复
                if exec_result['success']:
                    if exec_result['type'] == 'query':
                        # 查询结果
                        table_str = format_query_result_as_table(exec_result['data'])
                        result_text = ai_response + "\n\n---\n**执行结果**（共 " + str(exec_result['count']) + " 条记录）：\n\n" + table_str
                    else:
                        # 修改结果
                        result_text = ai_response + "\n\n---\n**执行成功**：影响了 " + str(exec_result['affected_rows']) + " 条记录。"
                else:
                    result_text = ai_response + "\n\n---\n**执行出错**：" + exec_result['error'] + "\n\n请检查查询条件是否正确。"

                return _send_nl2sql_response(user_message, result_text, history)
            else:
                # AI没有生成SQL（可能是普通对话），直接返回AI的回复
                return _send_nl2sql_response(user_message, ai_response, history)

        # ===== 普通聊天流式模式 =====
        return _stream_chat(user_message, history, SYSTEM_PROMPT)

    except Exception as e:
        print(f"[AI] 系统错误: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'系统错误: {str(e)}'})

def _send_nl2sql_response(user_message, result_text, history):
    """发送NL2SQL的非流式结果（用SSE格式包装以兼容前端）"""
    from flask import Response
    import json

    def generate():
        # 一次性发送全部内容
        yield f"data: {json.dumps({'content': result_text}, ensure_ascii=False)}\n\n"
        # 更新历史
        new_history = list(history)
        new_history.append({'role': 'user', 'content': user_message})
        new_history.append({'role': 'assistant', 'content': result_text})
        yield f"data: {json.dumps({'done': True, 'history': new_history[-20:]}, ensure_ascii=False)}\n\n"

    return Response(
        generate(),
        mimetype='text/event-stream',
        headers={
            'Cache-Control': 'no-cache',
            'X-Accel-Buffering': 'no'
        }
    )

def _stream_chat(user_message, history, system_prompt):
    """普通聊天的流式输出"""
    from flask import Response, stream_with_context
    import json

    messages = [{'role': 'system', 'content': system_prompt}]
    if history:
        messages.extend(history[-20:])
    messages.append({'role': 'user', 'content': user_message})

    print(f"[AI] 正在调用DeepSeek API（流式模式）...")
    print(f"[AI] 用户消息: {user_message[:50]}...")

    def generate():
        import requests as req

        try:
            response = req.post(
                DEEPSEEK_API_URL,
                headers={
                    'Content-Type': 'application/json',
                    'Authorization': f'Bearer {DEEPSEEK_API_KEY}'
                },
                json={
                    'model': 'deepseek-chat',
                    'messages': messages,
                    'temperature': 0.7,
                    'max_tokens': 8000,
                    'stream': True
                },
                timeout=60,
                stream=True
            )

            if response.status_code != 200:
                error_msg = f'AI服务错误 ({response.status_code})'
                yield f"data: {json.dumps({'error': error_msg}, ensure_ascii=False)}\n\n"
                return

            full_content = ""

            for line in response.iter_lines():
                if line:
                    line = line.decode('utf-8')
                    if line.startswith('data: '):
                        data_str = line[6:]

                        if data_str == '[DONE]':
                            history.append({'role': 'user', 'content': user_message})
                            history.append({'role': 'assistant', 'content': full_content})
                            yield f"data: {json.dumps({'done': True, 'history': history[-20:]}, ensure_ascii=False)}\n\n"
                            break

                        try:
                            chunk_data = json.loads(data_str)
                            if 'choices' in chunk_data and len(chunk_data['choices']) > 0:
                                delta = chunk_data['choices'][0].get('delta', {})
                                content = delta.get('content', '')
                                if content:
                                    full_content += content
                                    yield f"data: {json.dumps({'content': content}, ensure_ascii=False)}\n\n"
                        except json.JSONDecodeError:
                            continue

            print(f"[AI] 流式输出完成，总长度: {len(full_content)} 字符")

        except Exception as e:
            print(f"[AI] 流式输出错误: {str(e)}")
            yield f"data: {json.dumps({'error': str(e)}, ensure_ascii=False)}\n\n"

    return Response(
        stream_with_context(generate()),
        mimetype='text/event-stream',
        headers={
            'Cache-Control': 'no-cache',
            'X-Accel-Buffering': 'no'
        }
    )

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)

