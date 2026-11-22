# Prompt cho Claude Code: làm lại shop Silas và Master Tortuga

> Gửi phần bên dưới cho Claude Code tại thư mục gốc của repository.

---

Bạn là senior Godot UI/gameplay engineer. Hãy **triển khai lại hoàn toàn giao diện** shop của Silas và giao diện shop rèn của Master Tortuga theo phong cách Inventory mới của người chơi, tích hợp đầy đủ vào gameplay và kiểm chứng trực tiếp trong game. Không chỉ lập kế hoạch, đổi màu, thay vài texture hoặc dựng mockup. Đây là hai màn hình riêng có nội dung và cá tính riêng, nhưng phải nhìn rõ là cùng một game và cùng hệ thiết kế với Inventory mới.

## Quy tắc làm việc

Trước khi sửa code đọc `AGENTS.md`, `docs/project/conventions.md`, `docs/project/testing.md`; kiểm tra `git status`, bảo toàn mọi thay đổi có sẵn của người dùng, kể cả file untracked, và chỉ đọc các file liên quan trực tiếp. Không sửa hàng loạt, xóa tài nguyên hoặc resave scene ngoài phạm vi. Nếu sửa contract chung, signal, autoload, Input Map, collision layer hoặc `project.godot`, rà tất cả caller, cập nhật tài liệu và báo rõ.

Ưu tiên thay đổi trong scene/script UI của `gameplay/merchant/`, `gameplay/forge/` và thành phần UI dùng chung thật sự cần thiết. Hạn chế sửa scene map/Hub/NPC đang dùng chung; có thể mở `world/hub/scenes/hub.tscn` để kiểm tra nhưng không resave hay chỉnh map chỉ để thử. Nếu cần scene thử, dùng harness độc lập không ghi đè scene gốc. Giữ nguyên các UID, scene binding và đường kết nối với NPC hoặc cập nhật chính xác mọi nơi sử dụng khi thật sự cần.

## Nguồn tham chiếu thiết kế

- **Chuẩn chính là Inventory mới đang thực sự chạy**, không phải ảnh mockup hoặc Inventory cũ: xem trực tiếp `gameplay/inventory/inventory_ui.tscn`, `inventory_ui.gd`, `gameplay/inventory/menu/`, theme, tab, slot, filter, detail, nút, animation và cách scale. Chạy và chụp màn hình nếu có GUI để quan sát thực tế trước khi thiết kế.
- Khảo sát `res://assets/ui/HUD_Fox/`, `gameplay/inventory/menu/inventory_menu_theme.tres` và ba ảnh tham chiếu trong `docs/plans/inventory_references/`. Các ảnh giúp hiểu phong cách gốc; ưu tiên cách Inventory mới hiện đã triển khai nếu có khác biệt.
- Font dự án đã chọn: chính `res://assets/fonts/ShadowsIntoLight-Regular.ttf`; phụ `res://assets/fonts/PatrickHand-Regular.ttf` và `res://assets/fonts/ReenieBeanie-Regular.ttf`. Xem cách Inventory đang sử dụng; ưu tiên nhất quán, dễ đọc, xử lý glyph/fallback cho ngôn ngữ thực tế. Không đổi font toàn project.
- Khảo sát asset hiện có, kể cả `assets/ui/silas_shop/`, trước khi chọn. Có thể dùng asset cũ nếu thực sự hòa hợp với phong cách Inventory mới; không để giao diện cũ chi phối kết quả. Không mặc định asset nào phù hợp chỉ vì tên file; xem texture, kích thước, alpha và trạng thái trước khi dùng. Không chỉnh asset artist gốc nếu không cần; không tự tải asset ngoài.

Hai shop nên thống nhất về màu nền tối, tông đỏ/kem, chất liệu thủ công, hierarchy chữ, khung slot, tab đang chọn, nút, hiệu ứng, khoảng cách và feedback theo Inventory thực tế. Silas có thể gợi cảm giác thương nhân/cửa hàng, Tortuga gợi xưởng rèn và chế tạo; các điểm nhấn phải vừa đủ, không làm mất sự thống nhất hoặc giảm khả năng đọc. Bố cục mới chủ động theo công việc mua/bán và craft/forge, không bê nguyên bốn tab Inventory hoặc giữ nguyên quyển sách cũ chỉ thay skin.

## Khảo sát hợp đồng trước khi sửa

Đọc `docs/gameplay/npcs/silas_merchant.md`, `docs/gameplay/npcs/master_tortuga.md`, các scene/script UI và service của `gameplay/merchant/`, `gameplay/forge/`, NPC Silas/Tortuga, catalog/resource trong `data/merchants/`, `data/forge/`, `GoldWallet`, Inventory, `WeaponController`, `GameManager` và các caller trực tiếp. Xác nhận bằng source vì tài liệu có thể cũ.

Các điểm định hướng đã khảo sát, phải kiểm tra lại:

- `SilasShopPanel` có `open_for(player, catalog)`, `close_shop()`, signal `shop_closed`, `stock_reroll_requested`, kết nối NPC, inventory, wallet, toast và vòng đời menu. Shop có Buy/Sell, số lượng, item/weapon, giá, stock theo phiên và debug reroll. `MerchantTransactionService`/catalog là nguồn luật giao dịch; UI không tự sửa inventory hoặc wallet để giao dịch.
- `TortugaPanel` có `open_for(player)`, `close_panel(force)`, `panel_closed`, Craft/Forge, catalog, inventory, wallet, weapon controller, chi tiết và popup lựa chọn Forge. `TortugaService` chịu trách nhiệm giao dịch/cost/roll. Blueprint và weapon owned là hai trạng thái độc lập.
- Popup Forge đưa ra hai lựa chọn sau khi đã trả phí; theo contract hiện tại người chơi phải chọn một trước khi đóng/switch tab trong luồng bình thường. Xem đầy đủ cả đường force close, teardown và lỗi trước khi sửa để tránh mất phí hoặc bỏ dở giao dịch sai luật.
- `gameplay/merchant/silas_merchant_test.gd` và `test/silas_panel_autowire_test.gd` có trong checkout khi viết prompt. Tài liệu có thể nhắc test khác đã không còn, như `test/tortuga_test.gd`: kiểm tra tồn tại trước khi chạy, không khôi phục test đã chủ ý xóa.

## Yêu cầu chung cho giao diện mới

1. Thiết kế cả hai màn hình hoàn chỉnh với tiêu đề/NPC rõ ràng, tab theo chức năng thật, danh sách item hoặc weapon, trạng thái selected, khu chi tiết, số vàng, chi phí, action và Back. Có hierarchy và khoảng trống hợp lý; ưu tiên người chơi nhận ra mình đang xem gì và sắp trả/nhận gì.
2. Dùng đúng dữ liệu runtime; phân biệt selected/equipped/owned/unavailable bằng chữ hoặc biểu tượng cùng màu sắc. Empty state, thiếu icon, tên dài, mô tả dài, cost nhiều loại và số lớn phải hiển thị an toàn; wrap, scroll hoặc tooltip hợp lý. Không hiển thị giá trị giả, action giả hay thông tin của selection cũ. 
3. Thiết kế trạng thái normal/hover/pressed/focus/disabled, lý do từ chối giao dịch dễ hiểu và phản hồi thành công/thất bại rõ ràng. Animation, âm thanh nếu có và feedback phải nhất quán với Inventory nhưng ngắn, mượt, không chặn thao tác hoặc gây nháy; tôn trọng pause/time scale và cleanup tween/signal. Không cần tạo âm thanh nếu không có asset phù hợp.
4. Chuột và điều hướng bàn phím/focus có thể sử dụng được: chọn tab, item, số lượng, action, popup và Back/Esc. Không tạo binding mới nếu input hiện tại đáp ứng được; consume input đúng để không tấn công hay điều khiển nhân vật phía sau.
5. Sử dụng anchor/container/scale phù hợp `project.godot`, kiểm tra 1280×720, 1920×1080, 960×540 và 1024×768. Không crop nút/cost/feedback, không kéo méo texture, không chặn click bởi lớp trang trí; nội dung dài có scroll. Hạn chế dùng kích thước cứng phụ thuộc riêng 16:9.
6. Tái sử dụng theme/component Inventory khi contract phù hợp và thực sự giảm lặp; không sửa component chung làm hỏng Inventory, không thêm abstraction/autoload chỉ để hai shop giống nhau. Không nhân đôi nguồn trạng thái nghiệp vụ ở UI. Kết nối signal đúng lifecycle, refresh có giới hạn khi dữ liệu thay đổi, không rebuild mỗi frame.
7. Giữ tương thích mở/đóng với `GameManager`, NPC/dialogue, input gate, mouse mode, pause, animation, close nhanh, force close, scene transition, player mất hiệu lực và cleanup; không tự unpause một hệ thống khác. Không để shop hoặc popup mắc kẹt, giao dịch chạy hai lần khi bấm nhanh hoặc mất kết nối khi mở lại.
8. Shop của Silas tạo cảm giác Chợ đen buôn bán các món hàng cấm. Shop của Master Tortuga tạo cảm giác là đang giao dịch với 1 lò rèn. Có thể tạo các thành phần UI, VFX cần thiết nếu thiếu.

## Shop Silas: Buy và Sell

- Tạo bố cục theo phong cách Inventory mới cho **Buy** và **Sell**, có danh sách phù hợp từng tab, detail item/weapon, icon, tên, mô tả/hiệu ứng, số lượng giao dịch, đơn giá/tổng giá, vàng hiện có và nút Buy/Sell rõ ràng. Cách hiển thị đơn vị giao dịch phải bám `trade_amount` thực tế: phân biệt số gói với số item nhận/trả nếu service dùng gói; không gây hiểu sai.
- Lấy stock đúng catalog runtime: hàng được đảm bảo, random một lần mỗi phiên, hàng ẩn không mua được, stock hiển thị và debug reroll theo contract. Không roll lại chỉ vì chuyển tab/mở shop; không vô tình thay source resource. Debug control chỉ hiển thị đúng điều kiện hiện tại, không chen vào luồng người chơi bình thường.
- Bán đúng item đang sở hữu và offer hợp lệ, không nhầm index khi danh sách lọc hoặc inventory thay đổi. Xử lý stack, số lượng tối thiểu/tối đa, inventory đầy, potion capacity, không đủ vàng/hàng, item không bán được và weapon mua một lần theo service thật. Không đổi giá, stock, tỉ lệ, quy tắc economy hoặc persistence.
- Sau giao dịch cập nhật đồng bộ wallet, inventory, HUD, số lượng và thông báo. Giao dịch lỗi phải phản ánh kết quả service, không trừ tiền hay mất/nhân item; kiểm tra nhiều lần bấm liên tiếp và selection không còn hợp lệ.
- Giữ luồng NPC mở animation → dialogue → shop → farewell → đóng animation, signal và khả năng tương tác lại. Không reset hoặc xóa `user://silas_progress.save`; kiểm thử state/save bằng fixture hoặc đường dẫn cô lập phù hợp.

## Master Tortuga: Craft, Forge và popup

- Làm lại **Craft** và **Forge** cùng popup Forge theo hệ thị giác mới, không để popup hoặc các chip/chi tiết dùng style cũ lạc lõng. Hiển thị danh sách, trạng thái blueprint/owned, tên, art, mô tả, chỉ số weapon/Forge, skill, chi phí vàng/nguyên liệu hiện có/cần và hành động tương ứng. Dùng số liệu thật từ weapon instance/definition và service; không mặc định mọi weapon có cùng thông tin.
- Craft chỉ liệt kê/cho phép theo contract blueprint và ownership; trang bị sở hữu rồi không thể craft lại nếu service từ chối. Khi đủ điều kiện, trừ đúng nguyên liệu/vàng và grant weapon **không tự equip**; khi grant thất bại tôn trọng rollback. Không tự thay công thức, giá hoặc mở blueprint.
- Forge chỉ áp dụng cho weapon hợp lệ đang sở hữu. Khi roll thành công, hiển thị **hai lựa chọn khác nhau** với mô tả và so sánh chỉ số hiện tại/dự kiến; thể hiện tăng/giảm có lợi đúng chiều từng stat và có nhãn, không chỉ dùng màu. Đảm bảo văn bản dài cuộn được và hai nút chọn đều rõ, nhận input được.
- Giữ đúng thời điểm thanh toán, luật roll, việc thay một Forge hiện có, đồng bộ collection/equipment và quy tắc modal bắt buộc chọn; đóng/switch tab thông thường không được làm mất lựa chọn đã trả phí. Tôn trọng contract force-close và xác minh teardown thực tế; nếu phát hiện lỗ hổng có nguy cơ mất dữ liệu/tiền, sửa trong phạm vi cần thiết, giải thích rõ và không tự ý thay economy.
- Debug Supplies chỉ dùng theo điều kiện debug hiện có; không cấp đồ hay tiền ngoài giao dịch thật khi chơi bình thường. Giữ flow tương tác và dialogue của NPC.

## Kiểm chứng và bàn giao

1. Ghi nhận baseline bằng cách mở Inventory và hai shop trong game hoặc harness phù hợp, xem luồng giao dịch và ảnh chụp. Sau khi triển khai, chụp so sánh Inventory mới với Buy, Sell, Craft, Forge, popup hai lựa chọn; có ảnh trạng thái thiếu tiền/nguyên liệu và empty/disabled. Không nhận đã quan sát nếu môi trường thiếu GUI.
2. Chơi end-to-end trong Hub hoặc scene thử: mở/đóng/tương tác lại cả hai NPC, đổi tab và chọn item, chỉnh quantity, mua/bán thành công và thất bại, stack/capacity, weapon mua một lần, stock khi mở lại; craft đủ/thiếu nguyên liệu và owned/locked; forge đủ/thiếu, so sánh hai lựa chọn, cố đóng modal rồi chọn một, kiểm tra chi phí và weapon đã cập nhật. Dùng dữ liệu test cô lập, không ghi đè save thật của người dùng.
3. Kiểm tra responsive, keyboard/focus, overlap với HUD/dialogue, pause/input, đóng nhanh, teardown và mở lại. Xác nhận Inventory mới vẫn hoạt động sau khi tái sử dụng hoặc chỉnh thành phần chung. Kiểm tra log không có lỗi script/resource/signal.
4. Theo `docs/project/testing.md`, chạy lint/formatter check thích hợp, import Godot, test hiện hữu có liên quan và visual smoke trong game. Kiểm tra test có tồn tại trước khi chạy; không thêm test mới hoặc thay đổi CI trừ khi người dùng yêu cầu, không xóa/nới lỏng test để qua kiểm tra. Báo lệnh, kết quả thực tế và baseline failures nếu có.
5. Review diff/status, giữ file người dùng và tránh thay đổi map không cần thiết. Cập nhật tài liệu NPC nếu đổi contract/cách cấu hình. Báo các file đã đổi, hành vi giao dịch được giữ, các quyết định thiết kế, bằng chứng trực quan, kiểm tra đã chạy và phần chưa xác minh. Nếu thiếu GUI, engine hoặc asset, nêu giới hạn cụ thể; headless không chứng minh giao diện đẹp hoặc thao tác mượt, và không tuyên bố không có lỗi tuyệt đối.

## Tiêu chí hoàn thành

Cả Silas và Tortuga có giao diện mới hoàn chỉnh, nhất quán với Inventory mới nhưng phù hợp chức năng từng NPC; toàn bộ Buy/Sell/Craft/Forge và popup dùng dữ liệu cùng service thật; lifecycle, giao dịch và tương tác NPC được bảo toàn; không có placeholder chức năng và không thay map ngoài phạm vi. Kiểm tra được thực hiện trung thực và báo rõ giới hạn.
