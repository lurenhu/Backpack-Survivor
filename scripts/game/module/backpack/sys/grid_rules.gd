class_name GridRules
extends RefCounted
## 无状态网格计算。试放时传入工作副本，不改变正式占用。

static func rectangle(cols: int, rows: int, value: int = 0) -> Array[Array]:
	var grid: Array[Array] = []
	for y in rows:
		var row: Array = []
		row.resize(cols)
		row.fill(value)
		grid.append(row)
	return grid


static func rotated(shape: Array[Array], turns: int) -> Array[Array]:
	var result: Array[Array] = shape.duplicate(true)
	for turn in posmod(turns, 4):
		if result.is_empty():
			return []
		var next: Array[Array] = []
		for x in result[0].size():
			var row: Array = []
			for y in result.size():
				row.append(result[result.size() - 1 - y][x])
			next.append(row)
		result = next
	return result


static func can_place(shape: Array[Array], pos: Vector2i, grid: Array[Array]) -> bool:
	if shape.is_empty() or grid.is_empty():
		return false
	var has_cell := false
	for y in shape.size():
		for x in shape[y].size():
			if shape[y][x] != 1:
				continue
			has_cell = true
			var cell := pos + Vector2i(x, y)
			if cell.y < 0 or cell.y >= grid.size() or cell.x < 0 or cell.x >= grid[cell.y].size():
				return false
			if grid[cell.y][cell.x] != 0:
				return false
	return has_cell


static func mark(shape: Array[Array], pos: Vector2i, grid: Array[Array], value: int) -> void:
	for y in shape.size():
		for x in shape[y].size():
			if shape[y][x] == 1:
				grid[pos.y + y][pos.x + x] = value


static func find_position(shape: Array[Array], grid: Array[Array]) -> Vector2i:
	for y in grid.size():
		for x in grid[y].size():
			if can_place(shape, Vector2i(x, y), grid):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


static func purchasable_cells(grid: Array[Array]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in grid.size():
		for x in grid[y].size():
			if grid[y][x] == -1:
				continue
			for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var pos: Vector2i = Vector2i(x, y) + direction
				if pos.y >= 0 and pos.y < grid.size() and pos.x >= 0 and pos.x < grid[pos.y].size():
					if grid[pos.y][pos.x] == -1 and pos not in result:
						result.append(pos)
	return result
