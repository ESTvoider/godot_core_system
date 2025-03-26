class_name InputEventProcessor
extends RefCounted

## 事件处理器列表
var _handlers: Array[InputEventHandler] = []
## 事件过滤器列表
var _filters: Array[InputFilter] = []

## 添加事件处理器
## [param handler] 事件处理器
func add_handler(handler: InputEventHandler) -> void:
	if not _handlers.has(handler):
		_handlers.append(handler)

## 移除事件处理器
## [param handler] 事件处理器
func remove_handler(handler: InputEventHandler) -> void:
	_handlers.erase(handler)

## 添加事件过滤器
## [param filter] 事件过滤器
func add_filter(filter: InputFilter) -> void:
	if not _filters.has(filter):
		_filters.append(filter)

## 移除事件过滤器
## [param filter] 事件过滤器
func remove_filter(filter: InputFilter) -> void:
	_filters.erase(filter)

## 处理输入事件
## [param event] 输入事件
## [return] 是否继续处理事件
func process_event(event: InputEvent) -> bool:
	# 应用所有过滤器
	for filter in _filters:
		if not filter.filter_event(event):
			return false
	
	# 应用所有处理器
	for handler in _handlers:
		if not handler.process_event(event):
			return false
	
	return true

## 清除所有处理器和过滤器
func clear() -> void:
	_handlers.clear()
	_filters.clear()

# 预定义的事件处理器

## 输入事件处理器基类
class InputEventHandler:
	## 处理输入事件
	## [param event] 输入事件
	## [return] 是否继续处理事件
	func process_event(_event: InputEvent) -> bool:
		return true

## 输入过滤器基类
class InputFilter:
	## 过滤输入事件
	## [param event] 输入事件
	## [return] 是否通过过滤
	func filter_event(_event: InputEvent) -> bool:
		return true

## 按键重映射处理器
class KeyRemapHandler extends InputEventHandler:
	## 重映射完成信号
	signal remap_completed(action: String, event: InputEvent)
	
	var _remapping_action: String = ""
	var _is_remapping: bool = false
	
	## 开始重映射动作
	## [param action] 要重映射的动作名称
	func start_remap(action: String) -> void:
		_remapping_action = action
		_is_remapping = true
	
	## 取消重映射
	func cancel_remap() -> void:
		_remapping_action = ""
		_is_remapping = false
	
	## 处理输入事件
	## [param event] 输入事件
	## [return] 是否继续处理事件
	func process_event(event: InputEvent) -> bool:
		if not _is_remapping:
			return true
		
		if event.is_pressed():
			remap_completed.emit(_remapping_action, event)
			_is_remapping = false
			_remapping_action = ""
			return false
		
		return true

## 按键组合处理器
class KeyComboHandler extends InputEventHandler:
	var _active_keys: Array[int] = []
	var _combo_actions: Dictionary = {}
	
	## 注册按键组合动作
	## [param keys] 按键列表
	## [param action] 动作名称
	func register_combo(keys: Array[int], action: String) -> void:
		var key_str = ",".join(keys.map(func(k): return str(k)))
		_combo_actions[key_str] = action
	
	func process_event(event: InputEvent) -> bool:
		if not event is InputEventKey:
			return true
		
		var key_event = event as InputEventKey
		
		if key_event.pressed and not _active_keys.has(key_event.keycode):
			_active_keys.append(key_event.keycode)
		elif not key_event.pressed:
			_active_keys.erase(key_event.keycode)
		
		# 检查是否触发组合键动作
		var key_str = ",".join(_active_keys.map(func(k): return str(k)))
		if _combo_actions.has(key_str):
			var action = _combo_actions[key_str]
			var combo_event = InputEventAction.new()
			combo_event.action = action
			combo_event.pressed = true
			Input.parse_input_event(combo_event)
		
		return true

## 手势处理器
class GestureHandler extends InputEventHandler:
	var _gesture_patterns: Dictionary = {}
	var _current_gesture: Array = []
	var _gesture_timeout: float = 0.5  # 手势超时时间（秒）
	var _last_input_time: float = 0.0
	
	## 注册手势模式
	## [param pattern] 手势模式（方向序列）
	## [param action] 动作名称
	func register_gesture(pattern: Array, action: String) -> void:
		var pattern_str = ",".join(pattern)
		_gesture_patterns[pattern_str] = action
	
	func process_event(event: InputEvent) -> bool:
		if event is InputEventMouseMotion:
			var motion = event as InputEventMouseMotion
			var current_time = Time.get_ticks_msec() / 1000.0
			
			# 检查是否超时
			if current_time - _last_input_time > _gesture_timeout:
				_current_gesture.clear()
			
			# 添加方向
			if motion.velocity.length() > 10:  # 最小移动阈值
				var direction = _get_direction(motion.velocity)
				if not _current_gesture.is_empty() and _current_gesture[-1] != direction:
					_current_gesture.append(direction)
					_last_input_time = current_time
			
			# 检查是否匹配任何手势
			var gesture_str = ",".join(_current_gesture)
			if _gesture_patterns.has(gesture_str):
				var action = _gesture_patterns[gesture_str]
				var gesture_event = InputEventAction.new()
				gesture_event.action = action
				gesture_event.pressed = true
				Input.parse_input_event(gesture_event)
				_current_gesture.clear()
		
		return true
	
	func _get_direction(velocity: Vector2) -> String:
		var angle = rad_to_deg(velocity.angle())
		if angle < -135: return "left"
		elif angle < -45: return "up"
		elif angle < 45: return "right"
		elif angle < 135: return "down"
		else: return "left"

# 预定义的事件过滤器

## 按键过滤器
class KeyFilter extends InputFilter:
	var _blocked_keys: Array[int] = []
	
	func block_key(key: int) -> void:
		if not _blocked_keys.has(key):
			_blocked_keys.append(key)
	
	func unblock_key(key: int) -> void:
		_blocked_keys.erase(key)
	
	func filter_event(event: InputEvent) -> bool:
		if event is InputEventKey:
			return not _blocked_keys.has(event.keycode)
		return true

## 动作过滤器
class ActionFilter extends InputFilter:
	var _blocked_actions: Array[String] = []
	
	func block_action(action: String) -> void:
		if not _blocked_actions.has(action):
			_blocked_actions.append(action)
	
	func unblock_action(action: String) -> void:
		_blocked_actions.erase(action)
	
	func filter_event(event: InputEvent) -> bool:
		if event.is_action_type():
			for action in _blocked_actions:
				if event.is_action(action):
					return false
		return true