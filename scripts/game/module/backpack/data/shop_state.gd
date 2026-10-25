class_name ShopState
extends RefCounted

const CARD_COUNT: int = 4
var node_key: String = ""
var pool: Array[int] = []
## 每项为 {offer_id, config_id, price, sold}，编号在刷新及新局后不复用。
var offers: Array[Dictionary] = []
