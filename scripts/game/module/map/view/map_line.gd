class_name MapLine
extends Line2D

## 设置两个节点中心连接线
func setup_connection(node_1: MapNodeButton, node_2: MapNodeButton):
	var center_1 = node_1.position + node_1.size / 2.0
	var center_2 = node_2.position + node_2.size / 2.0
	add_point(center_1)
	add_point(center_2)