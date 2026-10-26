class_name Inventory
extends Node

## UI có thể lắng nghe signal này để cập nhật sau khi túi thay đổi.
signal changed

@export_range(20, 40, 1) var capacity: int = 20
var slots: Array[InventorySlot] = []


func _ready() -> void:
    for _c in range(capacity):
        var slot: InventorySlot = InventorySlot.new()
        slots.append(slot)


# thêm item, trả về số lượng còn thừa
func add_item(item: BaseItem, amount: int) -> int:
    if amount <= 0:
        return 0
    
    if item == null or item.max_stack < 1:
        return amount

    var remaining: int = amount

    # tìm slot đã chứa cùng item
    for slot in slots:
        if slot.is_empty() or slot.is_full():
            continue

        if item.item_id == slot.item.item_id:
            var added: int = mini(remaining, slot.item.max_stack - slot.quantity)
            remaining -= added
            slot.quantity += added

            if remaining == 0:
                changed.emit()
                return 0

    # tìm slot trống để thêm
    for slot in slots:
        if not slot.is_empty():
            continue

        var added: int = mini(remaining, item.max_stack)
        slot.item = item
        slot.quantity = added
        remaining -= added

        if remaining == 0:
            changed.emit()
            return 0

    if remaining < amount:
        changed.emit()
    return remaining


# Xóa item
func remove_item(item_id: StringName, amount: int) -> int:
    if amount <= 0:
        return 0
    
    var remaining: int = amount
    for slot in slots:
        if slot.is_empty():
            continue
        if slot.item.item_id != item_id:
            continue
        
        var removed: int = mini(remaining, slot.quantity)
        slot.quantity -= removed
        remaining -= removed

        if slot.quantity <= 0:
            slot.item = null
            slot.quantity = 0
        
        if remaining == 0:
            break
        
    var removed_total: int = amount - remaining
    if removed_total > 0:
        changed.emit()
    return removed_total


## Trả về tổng số lượng item trong tất cả các ô
func count_item(item_id: StringName) -> int:
    var total: int = 0
    for slot in slots:
        if not slot.is_empty() and slot.item.item_id == item_id:
            total += slot.quantity
    return total


## Kiểm tra có đủ số lượng cần dùng hay không; yêu cầu 0 luôn đủ
func has_item(item_id: StringName, amount: int = 1) -> bool:
    return amount >= 0 and count_item(item_id) >= amount


## Index không hợp lệ trả về null. Ô trả về là dữ liệu thật của túi
func get_slot(index: int) -> InventorySlot:
    if index < 0 or index >= slots.size():
        return null
    return slots[index]


func get_empty_slot_count() -> int:
    var total: int = 0
    for slot in slots:
        if slot.is_empty():
            total += 1
    return total


## Tổng số item có thể thêm, tính cả ô trống lẫn stack chưa đầy
func get_available_space(item: BaseItem) -> int:
    if item == null or item.max_stack < 1:
        return 0

    var total: int = 0
    for slot in slots:
        if slot.is_empty():
            total += item.max_stack
        elif slot.item.item_id == item.item_id:
            total += maxi(0, slot.item.max_stack - slot.quantity)
    return total


## Chỉ kiểm tra, không thêm item; true khi chứa được toàn bộ amount
func can_add_item(item: BaseItem, amount: int = 1) -> bool:
    if amount < 0 or item == null or item.max_stack < 1:
        return false
    return get_available_space(item) >= amount


## Lấy item từ đúng một ô, phục vụ thao tác dùng hoặc bỏ đồ trên UI
func remove_from_slot(index: int, amount: int) -> int:
    var slot: InventorySlot = get_slot(index)
    if slot == null or amount <= 0 or slot.is_empty():
        return 0

    var removed: int = mini(amount, slot.quantity)
    slot.quantity -= removed
    if slot.quantity == 0:
        slot.item = null
    changed.emit()
    return removed


## Làm rỗng túi nhưng giữ nguyên số ô và các đối tượng InventorySlot
func clear() -> void:
    var had_items: bool = false
    for slot in slots:
        if slot.item != null or slot.quantity != 0:
            had_items = true
        slot.item = null
        slot.quantity = 0

    if had_items:
        changed.emit()
