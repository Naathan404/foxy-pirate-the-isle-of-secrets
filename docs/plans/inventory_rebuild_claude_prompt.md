# Prompt cho Claude Code: làm lại Inventory

> Sao chép toàn bộ phần bên dưới cho Claude Code chạy tại thư mục gốc repository.
> Ba ảnh tham chiếu của artist được lưu cùng tài liệu trong `inventory_references/`.

---

Bạn là senior Godot UI/gameplay engineer. Hãy **triển khai hoàn chỉnh** màn hình Inventory mới trong project này, tích hợp với gameplay thật và kiểm chứng trong game. Không chỉ lập kế hoạch hoặc dựng mockup. Trước khi sửa code, đọc `AGENTS.md`, `docs/project/conventions.md`, `docs/project/testing.md` và các file liên quan trực tiếp. Giữ nguyên thay đổi sẵn có của người dùng, kể cả file chưa được Git theo dõi; không reset, xóa hoặc format hàng loạt. Kiểm tra `git status` trước khi làm.

## Mục tiêu và nguồn thiết kế

Thay giao diện Inventory cũ bằng một màn hình thống nhất gồm đúng bốn tab theo thứ tự **Inventory, Weapon, Charms, Journey**. Giao diện dùng các asset artist đã chốt trong `res://assets/ui/HUD_Fox/` và tham khảo bố cục, màu sắc, phong cách của:

- `docs/plans/inventory_references/inventory.jpg`
- `docs/plans/inventory_references/weapons.jpg`
- `docs/plans/inventory_references/charms.jpg`

Ảnh là tham chiếu bố cục tương đối, không phải đặc tả gameplay. Chữ Journal trong ảnh phải đổi thành **Journey**. Ô potion trong ảnh Inventory vẽ ba ô là hiểu lầm: **chỉ có hai ô loadout, chính và phụ**. Ba ô ở ảnh Charms là socket charm và phải tuân theo hệ thống charm thực tế. Ảnh không quy định số weapon có thể equip hoặc sức chứa inventory; lấy từ hệ thống hiện có. Journey chưa có ảnh riêng: thiết kế cùng hệ thị giác, ưu tiên khả năng đọc enemy/boss và dùng asset phù hợp hiện có.

Font chính là `res://assets/fonts/ShadowsIntoLight-Regular.ttf` (Shadows Into Light); font phụ là `res://assets/fonts/PatrickHand-Regular.ttf` và `res://assets/fonts/ReenieBeanie-Regular.ttf`. Dùng font chính xuyên suốt vai trò chính; chọn font phụ có chủ ý cho nội dung dài hoặc nhãn phụ để dễ đọc. Kiểm tra glyph thực tế, đặc biệt tiếng Việt nếu xuất hiện, và cấu hình fallback khi cần. Không thay font toàn project nếu phạm vi chỉ cần màn hình này.

Asset gồm nhóm `HUD_Fox/Inventory`, `HUD_Fox/Weapons`, `HUD_Fox/Charms` và các asset chung. Xem trực tiếp kích thước, alpha và nội dung trước khi chọn; tái sử dụng frame, icon, background, nút, đường trang trí và trạng thái selected phù hợp. Không giả định mọi ảnh đều là texture đơn lẻ có thể kéo giãn tùy ý; tránh méo, che chữ hoặc làm mờ. `Background_Animated.mp4` là asset tham khảo, không mặc định Godot có thể phát trực tiếp MP4: chỉ tích hợp animation nếu đã xác nhận pipeline tương thích và hiệu năng; nền tĩnh hoàn chỉnh là đủ. Không vẽ lại hay sửa asset gốc nếu không cần.

## Khảo sát và hợp đồng hiện hữu

Trước khi thiết kế, đọc code/scene và tài liệu sau, rồi truy vết caller, signal, scene binding, input, dữ liệu và test liên quan trực tiếp. Code hiện tại là nguồn xác nhận cuối cùng nếu tài liệu cũ lệch; ghi rõ khác biệt trong báo cáo.

- `gameplay/inventory/inventory_ui.tscn`, `inventory_ui.gd`, `inventory_slot_ui.*`, `inventory.gd`, `inventory_slot.gd`, `base_item.gd`, `equipment_tab.*`, `equipment_slot.*`, `notes_tab.*`, `note_progress_store.gd`, `potion_component.gd`, `potion_quick_select.gd`.
- `gameplay/player/foxy.tscn`, `player.gd`, `gameplay/player/hud/` liên quan, `core/autoload/game_manager.gd`, `core/autoload/player_scene_state.gd`, cấu hình input/viewport trong `project.godot`.
- `gameplay/weapons/weapon_controller.gd`, `weapon_instance.gd`, `data/weapon/weapon_data.gd` và collection/forge; `gameplay/charms/socket/`, registry/data/progression liên quan; `data/notes/` và các đường mở note từ pickup/boss/chest.
- `docs/gameplay/economy/equipment_inventory.md`, `potion_capacity.md`, `charm_system.md`, `monster_notes.md`, `docs/gameplay/weapons/weapon_collection.md` và test liên quan trong `test/`, `gameplay/charms/`.

Những điểm đã khảo sát để định hướng, vẫn phải xác nhận lại trước khi sửa:

1. Inventory hiện là `CanvasLayer` được Foxy giữ reference; API `is_open()`, `open_inventory()`, `close_inventory(immediate)`, toggle, `GameManager` và chặn input gameplay có caller bên ngoài. Thiết kế lại bên trong nhưng giữ contract hoặc cập nhật toàn bộ caller có liên quan. Không tạo UI thứ hai chạy song song.
2. `Inventory` sở hữu slot, stack, sức chứa potion và API thay đổi; `PotionComponent` sở hữu hai assignment. Không sửa trực tiếp slot hoặc nhân đôi state nghiệp vụ trong UI. Item thường, note/diary, blueprint và charm pickup có luồng riêng; đừng ép tất cả vào inventory.
3. Weapon collection phân biệt weapon instance đang sở hữu với blueprint chế tạo. Equip thông qua controller thật; không tự grant weapon hay thay đổi forge. Charm có ownership, ba socket Q/Space/E, thứ tự mở Q → E → Space và điều kiện safe location. Chỉ manager quyết định equip/unequip hợp lệ.
4. `MonsterNote` và `NoteProgress` đã có catalog, unlock theo ID và file `user://monster_notes.save` độc lập. Scene transition có `PlayerSceneState`; không giả định đã có hệ thống disk save chung cho mọi equipment. Giữ nguyên các cơ chế persistence hiện có, không hứa persistence mới nếu chưa triển khai.

## Hành vi bắt buộc

### Khung chung

- Đưa bốn tab lên thanh trên cùng, có icon, tên, trạng thái active/hover/focus/disabled rõ ràng; mở/đóng theo input hiện có và nút Back/Esc. Input phải được consume đúng lúc, không kích hoạt tấn công, uống potion hay điều khiển phía sau UI.
- Duy trì đúng lifecycle `GameManager`, pause, mouse mode, tween và gameplay gate hiện tại; mở/đóng nhanh liên tục, đóng cưỡng bức khi chết/chuyển scene, focus loss và UI bị giải phóng không để kẹt pause hoặc chuột. Không tự ý unpause hệ thống khác. Đảm bảo UI hoạt động trong trạng thái pause theo contract hiện có.
- Lựa chọn, trang bị và trạng thái khóa phải phân biệt bằng hình và chữ, không chỉ bằng màu. Nút hành động chỉ hoạt động khi hợp lệ, có lý do dễ hiểu khi bị từ chối. Có trạng thái rỗng, thiếu icon và mô tả dài an toàn; không bịa dữ liệu hay để thông tin của lựa chọn trước bị lưu lại.
- Hỗ trợ chuột và điều hướng bàn phím/focus khả dụng; chuyển tab, chọn phần tử, action và Back nhất quán với Input Map hiện có. Không tự hứa hỗ trợ controller đầy đủ nếu chưa có và chưa xác minh. Tránh thêm action trùng hoặc phá binding.
- Bố cục gốc project là 1280×720, `canvas_items`/`expand`: dùng container, anchor và scale hợp lý; kiểm tra 1280×720, 1920×1080, 960×540, 1024×768. Không crop nút, tràn chữ, giãn sai tỉ lệ hay chặn click; danh sách/nội dung dài phải cuộn hoặc phân trang. Ưu tiên tính đọc và thao tác hơn sao chép pixel cứng từ ảnh 16:9.
- Kết nối signal một lần, ngắt/làm sạch đúng lifecycle; refresh khi dữ liệu thật thay đổi, không rebuild toàn bộ mỗi frame. Giữ selection hợp lệ khi lọc, đổi item, hết item, mở lại hoặc thay scene; không dùng index hiển thị đã lọc làm index slot thật.

### Inventory và potion loadout

- Bố cục theo ảnh: nhóm filter trái, grid giữa, thông tin item bên phải, hai slot Main/Secondary phía dưới. Hiện icon, tên, loại, mô tả, số lượng và sức chứa có ý nghĩa theo dữ liệu thật. Counter `XX/YY` chỉ hiển thị khi định nghĩa tử/mẫu có cơ sở; không nhầm số stack với potion capacity.
- Filter All, Consumable, Ammunition, Material, Quest Item khi có mapping hợp lệ với `GlobalConstants.ItemType`/data thật. Phân loại rõ, filter rỗng có thông báo; không thay loại item để vừa ảnh. Nếu một nhóm chưa có dữ liệu, vẫn hiển thị trạng thái rỗng hợp lý.
- Giữ drag/drop di chuyển, đổi chỗ và gộp stack hiện có qua `Inventory.move_item()`, bao gồm khi đang lọc: mapping về index gốc phải đúng; không làm mất/nhân item hoặc vượt stack. Hủy drag an toàn khi đổi tab, filter, đóng hoặc dữ liệu thay đổi. Nếu không thể bảo đảm mapping an toàn, vô hiệu drag trong filter có giải thích, vẫn giữ drag ở All.
- Cho phép chọn potion và gán rõ ràng vào Main hoặc Secondary, tháo và đổi vị trí qua `PotionComponent` API; phản ánh **đúng semantics thực tế** của từng hàm, kể cả khi gán Main đẩy potion cũ sang Secondary, gán potion từ ô đối diện dẫn đến swap, và tháo Main có thể đẩy Secondary lên. Không trừ hay giữ chỗ item khi gán, không trùng assignment. Potion đã gán nhưng hết số lượng vẫn hiển thị icon/count 0 như HUD; item không phải potion không được equip vào loadout.
- Đảm bảo HUD, F dùng Main, R tap swap/hold wheel, số lượng, sức chứa theo loại và pickup vẫn đồng bộ. Không đổi logic heal/stamina hoặc làm mất quick selection wheel.

### Weapon

- Theo ảnh: weapon đang trang bị bên trái, danh sách ở giữa, skill và chi tiết weapon được chọn ở giữa/phải. Selection độc lập equipped; nút Equip gọi controller, thể hiện kết quả thực tế. Empty/unowned/invalid state rõ ràng; chỉ liệt kê theo ownership contract, không cấp quyền sở hữu bằng UI.
- Dùng dữ liệu instance thực tế, bao gồm forge và các chỉ số mà hệ thống đã tính hoặc công khai; hiển thị tên, icon, mô tả, skill, cooldown và chỉ số khả dụng. Không ghi cứng các chỉ số trong mockup, không trình bày giá trị không có như giá trị thật. Xử lý nhiều instance cùng loại theo danh tính instance, không chỉ ID definition. Preserve semantics blueprint độc lập.

### Charms

- Theo ảnh: khu vực ba socket bên trái, danh sách/filter All, Active, Passive ở giữa, thông tin charm và nút hành động bên phải. Đọc catalog, ownership, loại, rarity, stats/effect từ dữ liệu có thật; thể hiện locked/unowned, equipped, selected và socket chưa mở. Không lộ prototype/disabled theo cách vượt luật hiện hành.
- Người chơi chọn socket đích và equip/unequip qua manager; tôn trọng safe location, socket trống/khóa, ownership, trùng charm và validation effect. Không tự mở socket, không ghi loadout/resource trực tiếp. Phản hồi lý do thất bại, không đổi hình thành công khi manager từ chối; kiểm tra modifier, effect và HUD thực sự cập nhật, không stack/gỡ nhầm.

### Journey

- Tab chỉ đọc thông tin enemy và boss theo `MonsterNote` hiện có: danh sách, chọn entry đã mở, portrait, tên, mô tả, thông tin hành vi/chiến thuật, story boss và các chỉ số có dữ liệu. Phân biệt enemy/boss bằng layout/filter hợp lý. Entry khóa không tiết lộ nội dung; danh sách rỗng hoặc toàn khóa vẫn dùng được.
- Bảo toàn ID, thứ tự catalog có chủ đích, trạng thái mặc định và `NoteProgress`/save đang có; pickup note/boss diary và chest vẫn mở đúng entry, kể cả túi đầy. Không tự tạo lore, chỉ số hay unlock conditions mới. Đừng ghi đè file save người dùng trong lúc kiểm thử: dùng đường dẫn tạm/cấu hình fixture và dọn tài nguyên test của chính mình.

## Triển khai và kiểm chứng

1. Xác nhận các scene/data/API thực tế và lập mapping asset → thành phần; chọn cấu trúc scene/component vừa đủ, tái sử dụng logic hiện hữu, tránh autoload hoặc hệ thống save mới nếu không cần. Giữ public contract, UID/resource reference và dữ liệu authored; cập nhật tài liệu khi contract hoặc cấu hình thay đổi.
2. Triển khai đầy đủ bốn tab và integration. Không để nút giả, data mẫu cố định hoặc placeholder thay cho hành vi cần có. Nếu thực sự thiếu asset/nội dung, hiển thị trạng thái trung thực và báo rõ; không tự thay đổi thiết kế gameplay chưa được quyết định.
3. Chạy lint/formatter check phù hợp theo `docs/project/testing.md`, Godot import/headless và các test hiện có liên quan (ít nhất kiểm tra tên và tính phù hợp của equipment inventory, potion, weapon collection, charm progression và chest/note). Không thêm test mới hoặc mở rộng CI trừ khi được yêu cầu bởi quy tắc repository; dùng test hiện hữu, fixture tạm hoặc kiểm thử thủ công. Báo command, exit code và lỗi baseline riêng với lỗi do thay đổi; không lọc lỗi engine. Không chỉnh/xóa test cũ chỉ để đạt kết quả.
4. Chạy game/scene thực tế, kiểm tra trực quan bốn tab và các kích thước nêu trên; lưu ảnh/video kiểm chứng nếu môi trường cho phép. Headless không chứng minh bố cục, tính dễ đọc hay tương tác. Nếu không thể chạy GUI hoặc thiếu engine/dependency, nêu rõ điều chưa kiểm chứng, không khẳng định đã hoàn thành việc kiểm thử đó.
5. Kiểm thử tương tác end-to-end: mở/đóng liên tục, Back/Esc, chuyển tab, filter rỗng và drag; chọn/gán/tháo/swap cả hai potion, dùng hết và nhặt lại, HUD/wheel; weapon ownership/equip/forge; charm equip và từ chối ở ngoài safe location/ô khóa/trùng; Journey khóa/mở bằng pickup và restart với save test cô lập; scene transition/death/pause và chuột. Xác minh không phát sinh lỗi script/resource và gameplay tiếp tục bình thường sau đóng.
6. Review `git diff` và `git status`, giữ thay đổi sẵn có của user, không đưa cấu hình plugin cục bộ hoặc file test tạm vào thay đổi. Báo cáo ngắn gọn các file/chức năng đã đổi, quyết định thiết kế, kiểm tra đã chạy và kết quả thực tế, rủi ro hoặc phần còn thiếu. Không tuyên bố không lỗi tuyệt đối.

## Tiêu chí hoàn thành

Màn hình thực tế có bốn tab hoạt động và bám asset/ảnh; đúng hai potion loadout; dữ liệu và action nối với hệ thống thật; các luật equipment/charm/note và input/pause được giữ; không có placeholder chức năng; kiểm tra phù hợp đã chạy, các giới hạn xác minh được nêu rõ. Khi cần quyết định gameplay chưa có căn cứ, giữ hành vi hiện tại và ghi lại thay vì tự tạo luật mới.
