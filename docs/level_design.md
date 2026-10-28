# LEVEL DESIGN

## 1. Luồng tổng & Quy tắc chung

- **Cấu trúc:** Hub & Spoke (1 Hub + 4 Map nguyên tố).
- **Tiến trình mở map:** `Castaway Cove (Hub)` ➔ **Bắt buộc qua `Coral Valley` trước** ➔ Mở khóa đồng thời 3 vùng còn lại (đi tự do) ➔ Gom đủ 4 `Ancient Keys` ➔ Mở khu trung tâm tại Hub (`Ancient Stone Tablet`) ➔ `Final Boss`.
- **Khu vực ẩn (Secret):** Rải rác các map, chứa `Blueprint` hoặc `Rương` (**100 – 200 Gold**).
- **Chức năng Checkpoint:** Lưu tiến trình + Đổi Charm.
- **Flow chuẩn 1 vùng:**
  `Entrance` (Gimmick intro) ➔ `Exploration` (Loot/Combat) ➔ `Challenge` (Gimmick + Combat) ➔ `Checkpoint` ➔ `Boss Approach` ➔ `Boss Room` ➔ `Reward & Fast Travel về Hub`.

## 2. Bảng tra nhanh 5 khu vực

| Khu vực | Nguyên tố | Gimmick & Thông số kỹ thuật | Phần thưởng / Mở khóa |
| :--- | :--- | :--- | :--- |
| **Castaway Cove** | Hub | Khu an toàn (không quái/bẫy). Chứa NPC, chỗ đổi Charm, Forge/Upgrade, `Ancient Stone Tablet`. | - |
| **Coral Valley** | Nước | • **Tidal Shift:** Chu kỳ **25–45s**.<br>• **Wooden Crates:** Đẩy thùng lúc nước rút, nổi thành bục khi nước dâng (có nút Reset). | • `Ancient Key of Tides`<br>• Charm: `Tide Grapple`<br>• NPC: Thợ rèn<br>• Mở 3 map còn lại |
| **Misty Swamp** | Mộc | • **Mud:** **-50% Speed**, **Cấm Dash**.<br>• **Fog:** Overlay che camera, giảm tầm nhìn. | • `Ancient Key of Flora`<br>• Charm: `Devil Contract`<br>• NPC: Ếch phù thủy |
| **Smithy Mountain** | Lửa | • **Heatstroke:** Mỗi **30s = -0.5 Tim** (Kháng bằng Charm `Lava Shield`).<br>• **Lava Pool:** **-1 HP/s** khi chạm. Có lava ẩn (lại gần mới bốc khói). | • `Ancient Key of Embers`<br>• Charm: `Meteor Strike` |
| **Frostwind Graveyard** | Gió | • **Blizzard:** Chu kỳ **20–30s**. Giảm tầm nhìn, **-30% Speed**, **-30% hồi Stamina**, spawn quái riêng.<br>• **Ice Slide:** Trượt thẳng tới khi hết băng/chạm vật cản. **Khóa mọi input** khi trượt. | • `Ancient Key of Gale`<br>• Charm: `Glacial Spikes` |

## 3. Chi tiết cơ chế & Level Flow từng vùng

### 3.1. Castaway Cove (Hub)

- **Theme:** Xanh lá, cỏ, hoa, yên bình.
- **Chức năng:** Điểm đầu game, tập trung NPC, thay Charm, nâng cấp/chế tạo, đặt `Ancient Stone Tablet`, điểm nhận Fast Travel từ các Spoke về.

### 3.2. Coral Valley (Nước) - *[Map mở đầu]*

- **Theme & Địa hình:** Cát, san hô, biển. Địa hình chia cắt thành nhiều đảo nhỏ, cồn cát, khoảng nước.
- **Boss:** Thuyền trưởng Cá nóc bụng phệ.

- **Cơ chế cần code:**

 1. **Tidal Shift (Chu kỳ 25–45s):**

	 - *Nước rút:* Lộ bãi cát ngầm, mở đường đi/giải đố, spawn một số quái.
	 - *Nước dâng:* Ngập đường đi, quái dưới nước biến mất. **Player đứng ở vùng ngập lúc nước dâng = Chết ngay (Insta-kill)**.
  
 2. **Wooden Crates (Thùng gỗ):**

	 - Đẩy được khi nước rút. Khi nước dâng thì nổi lên làm bục nhảy.
	 - Có **Nút bấm (Button)** để reset vị trí thùng về mặc định.

- **Flow:** `Entrance` ➔ `Bãi biển` ➔ `Khu vực thủy triều` ➔ `Puzzle thùng gỗ` ➔ `Combat Area` ➔ `Checkpoint` ➔ `Boss Approach` ➔ `Boss Room`.

### 3.3. Misty Swamp (Mộc)

- **Theme & Địa hình:** Đầm lầy, sương mù, cây đước, u ám. Nhiều vùng đất nhỏ, rễ cây, vũng lầy.
- **Cơ chế cần code:**

  1. **Mud (Vũng lầy):** Khi Foxy dẫm lên bị **giảm 50% tốc độ chạy** và **khóa Dash**.

  2. **Fog (Sương mù):** Lớp Overlay trước camera che quái, đường đi và khu vực ẩn.

- **Flow:** `Entrance` ➔ `Fog Tutorial` ➔ `Mud Area` ➔ `Enemy Ambush` ➔ `Exploration Area` ➔ `Checkpoint` ➔ `Dense Swamp (Fog + Mud)` ➔ `Boss Approach` ➔ `Boss Room`.

### 3.4. Smithy Mountain (Lửa)

- **Theme & Địa hình:** Núi lửa, dung nham, đá bazan/obsidian, cột hơi nóng. Nhịp độ cao.

- **Cơ chế cần code:**

  1. **Heatstroke (Sốc nhiệt):** Cứ mỗi **30s** đứng trong vùng nóng bị trừ **0.5 Tim**. Chỉ miễn nhiễm khi lắp Charm `Lava Shield`.

  2. **Lava Pool (Hồ dung nham):** Đứng lên nhận sát thương đốt **1 HP/s** liên tục. Một số ô lava ẩn dưới đất, khi Player tới gần mới hiện khói cảnh báo rồi lộ ra.

- **Flow:** `Entrance` ➔ `Heatstroke Intro` ➔ `Lava Crossing` ➔ `Obsidian Maze` ➔ `Combat Arena` ➔ `Checkpoint` ➔ `Boss Approach` ➔ `Boss Room`.

### 3.5. Frostwind Graveyard (Gió)

- **Theme & Địa hình:** Tuyết trắng, núi băng, nghĩa địa cổ, particle tuyết rơi/bão tuyết.

- **Cơ chế cần code:**

  1. **Blizzard (Bão tuyết - Chu kỳ 20–30s):**

	 - *Khi bão nổi:* Giảm tầm nhìn, **-30% tốc độ di chuyển**, **-30% tốc độ hồi Stamina**, spawn quái đặc thù.
	 - *Khi hết bão:* Mọi chỉ số về bình thường, quái đặc thù biến mất.
	
  2. **Ice Slide (Băng trơn):** Bước vào sẽ trượt theo hướng đang đi cho tới khi hết băng hoặc đâm tường. **Trong lúc trượt: Khóa toàn bộ hành động (di chuyển, dash, skill...)**.

- **Flow:** `Entrance` ➔ `Blizzard Tutorial` ➔ `Ice Slide Tutorial` ➔ `Combat Area` ➔ `Challenge Area` ➔ `Checkpoint` ➔ `Boss Approach` ➔ `Boss Room`.
