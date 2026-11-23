# Prompt cho Claude Code: tái cấu trúc Hub

> Thực hiện tại thư mục gốc repository. Tài liệu này mô tả bố cục Hub được yêu cầu và là nguồn ưu tiên khi bố cục cũ khác với yêu cầu bên dưới.

Bạn là senior Godot level designer và gameplay engineer. Hãy tái cấu trúc Hub thành một không gian có cảm giác liên kết, dễ định hướng và có bốn đường thẳng dẫn ra bốn biome. Triển khai scene và các kết nối thực tế, không chỉ viết kế hoạch hoặc dựng sơ đồ. Bảo toàn các hệ thống gameplay hiện có; không tự tạo luật progression chưa được xác nhận.

## Quy tắc làm việc

- Trước mỗi công việc viết hoặc sửa code, đọc `AGENTS.md`, `docs/project/conventions.md` và `docs/project/testing.md`. Kiểm tra `git status`, giữ nguyên thay đổi có sẵn của người dùng, kể cả file bị xóa hoặc untracked. Chỉ khảo sát và chỉnh file liên quan trực tiếp.
- Clean code, không magic number/string có ý nghĩa gameplay hoặc cần cân chỉnh, không spaghetti code. Tái sử dụng scene/component và API hiện có; một nguồn trạng thái chính, các tham số thiết kế có tên và đơn vị, không tạo framework hoặc autoload mới nếu không cần.
- Khảo sát `world/biomes/hub/`, các map biome liên quan, `GameManager`, scene transition, player state, safe location, NPC, shop/forge, training dummy, checkpoint và các tài liệu trực tiếp liên quan trước khi thay đổi. Tài liệu cũ có thể không khớp source; xác minh lại.
- Không xóa scene, asset, test hoặc logic cũ chỉ vì bố cục thay đổi. Nếu thay đường dẫn scene, trigger ID, autoload, Input Map, `project.godot`, hợp đồng save hoặc API chung, rà soát caller, migration cần thiết, cập nhật tài liệu và báo rõ.

## Bố cục đã chốt

- Bốn đường **thẳng theo bốn hướng Bắc, Nam, Đông, Tây**; không có đường hoặc nhánh chéo. Bốn hướng là hướng trong sơ đồ thiết kế, cần ánh xạ nhất quán với trục world/camera và xác minh trực quan.
- **Bắc: Lava/lửa. Nam: Ice/băng. Đông: Coral Valley/nước. Tây: Swamp/cỏ.** Các biome và lối đi hiện chưa tồn tại hoặc chưa hoàn thiện phải được thể hiện đúng trạng thái thực tế; không tạo đường chuyển scene giả hoặc báo đã kết nối khi chưa có scene đích.
- Một **scene Hub trung tâm duy nhất** chứa cả: quảng trường, Thạch bàn bốn chìa, điểm tele Hub, bảng nhiệm vụ, lửa trại và khu luyện tập dummy. Các phần đất trong scene này được nối bằng cầu/đường thẳng, người chơi đi giữa chúng không chuyển scene. Scene có thể instance các scene con để tái sử dụng; không hiểu yêu cầu này là gom toàn bộ node vào một file khổng lồ.
- Không có khu NPC chung. Có khu riêng cho **Madam Croak**; không tự đặt chức năng hoặc gameplay mới cho NPC nếu dự án chưa định nghĩa.
- Khu của **Silas là scene riêng**. Người chơi vào và quay lại bằng lối nằm cạnh tuyến đường thẳng, không tạo tuyến chéo. Chỉ tạo transition tại ranh giới scene; không chia nhỏ quảng trường và sân tập thành nhiều scene chuyển cảnh.

```text
                               BẮC: LAVA
                            Cổng sang Lava
                                  │
                            Trụ đá lửa
                                  │
                  [SCENE HUB TRUNG TÂM]
                  Khu luyện tập dummy
                                  │
TÂY: SWAMP                        │                       ĐÔNG: CORAL
Cổng Swamp ─ Trụ đá cỏ ─ Khu Silas ─ QUẢNG TRƯỜNG ─ Nhà rèn ─ Trụ đá nước ─ Cổng Coral
                    scene riêng     Thạch bàn
                                    Tele Hub
                                    Bảng nhiệm vụ
                                    Lửa trại
                                  │
                         Khu Madam Croak
                                  │
                             Trụ đá gió
                                  │
                            Cổng sang Ice
                               NAM: ICE
```

Sơ đồ là quan hệ và thứ tự theo đường đi, không phải kích thước hay tỷ lệ. Trên một tuyến, công trình có thể nằm sát mép đường và có lối vào vuông góc ngắn; không bố trí đường chéo. Chừa không gian để di chuyển, chiến đấu thử và tương tác mà không che lối chính.

## Mỹ thuật nền đất và cây cỏ

- Dùng ba ảnh tham chiếu người dùng cung cấp trong cuộc trò chuyện: mặt đất cỏ, mặt đất lát đá/gạch cũ và cách phân bố thảm thực vật trong *Cult of the Lamb*. Nếu Claude Code không nhìn thấy các ảnh đó, yêu cầu người dùng cung cấp lại trước khi chốt tạo hình. Chỉ lấy cảm hứng từ chất liệu vẽ tay, màu sắc, độ tương phản và góc nhìn; tạo asset gốc phù hợp thế giới cướp biển của dự án, không sao chép trực tiếp hình ảnh, biểu tượng hoặc thiết kế đặc trưng của game tham chiếu.
- Tạo các **ảnh nền đất cỏ** và **ảnh nền lát đá/gạch** riêng cho Hub: nền cỏ cho các khu đất tự nhiên và sân tập; nền đá/gạch cho quảng trường, khu Thạch bàn và các đoạn đường phù hợp. Đất có thể có biến thiên màu và bề mặt, gạch có thể có mạch ghép hoặc vết nứt nhẹ; giữ bề mặt đủ yên để nhân vật, vật phẩm và đường đi dễ nhận biết. Kết hợp hai loại nền tự nhiên và nhất quán với camera/góc nhìn thực tế của game.
- **Không vẽ dính bất kỳ cây, bụi cỏ, hoa, lá hoặc thực vật có thể phá hủy nào vào ảnh nền.** Tạo các ảnh cây cỏ thành asset riêng biệt, nền trong suốt, không kèm mảng đất hoặc bóng đổ cố định lên nền. Bao gồm các biến thể phù hợp như cụm cỏ, bụi cây và cây nhỏ; mỗi đối tượng phải có thể đặt, di chuyển và xóa độc lập. Không đóng cây cỏ vào texture, mesh hay ảnh tổng của mặt đất.
- Dùng các asset cây cỏ riêng làm **destructible object**, ưu tiên component/scene phá hủy đã có của dự án. Khi bị phá hủy, vật thể biến mất hoặc chuyển trạng thái theo hệ thống thực tế và nền bên dưới vẫn nguyên vẹn. Không tự bịa luật máu, vật phẩm rơi, respawn hoặc lưu trạng thái; dùng cấu hình/contract hiện có và báo phần chưa được xác định. Không đặt vật thể cản lối, che NPC hoặc làm ảnh hưởng khu dummy.
- Khảo sát asset và cách render nền hiện có trước khi tạo; chọn texture/tile phù hợp scale và phối cảnh thực tế, có thể ghép hoặc lặp không lộ đường nối, có biến thể hợp lý và không gây lặp dễ thấy. Giữ file nguồn và output riêng cho nền và từng đối tượng; dùng định dạng, độ phân giải, import/filter và transparency phù hợp Godot. Không xóa asset hiện có hoặc đưa ảnh tham chiếu có sẵn vào game làm asset.
- Nếu môi trường Claude Code có công cụ tạo ảnh, dùng công cụ đó để tạo asset gốc rồi kiểm tra và tích hợp vào scene; nếu không có khả năng tạo ảnh, báo rõ asset nào chưa tạo được, mô tả thông số cần thiết và không tuyên bố đã hoàn thành phần mỹ thuật. Không thay thế yêu cầu tạo ảnh bằng nền màu phẳng mà không nêu rõ giới hạn.

## Vị trí và chức năng các khu

### Scene Hub trung tâm

1. **Quảng trường:** là giao điểm của bốn tuyến, có thể gồm nhiều mảnh đất nối nhau. Đảm bảo cảnh quan và đường đi giúp người chơi thấy Hub là một địa điểm thống nhất.
2. **Thạch bàn:** ở trung tâm quảng trường, là landmark chính; có bốn vị trí cho bốn chìa. Người chơi có thể nhìn thấy từ đầu. Bảo toàn quy tắc mở khóa và tương tác đang được triển khai; không tự mặc định chức năng đặt chìa hoặc nội dung sau bàn đã hoàn thành.
3. **Điểm tele Hub:** trên quảng trường, có chỗ đứng và nhận diện rõ; dùng làm đầu mối đến checkpoint khi hệ thống tele cho phép.
4. **Bảng nhiệm vụ:** trên quảng trường, cạnh khu sinh hoạt/lửa trại, dễ nhìn thấy từ trục chính.
5. **Lửa trại Hub:** trên quảng trường, gần vị trí xuất hiện, có thể tiếp cận an toàn; giữ hoặc kết nối chức năng hồi máu hiện có nếu đã tồn tại.
6. **Khu luyện tập:** trong cùng scene, nằm về phía Bắc của quảng trường, cạnh trục Bắc; đủ không gian cho nhiều training dummy, thử vũ khí, kỹ năng, charm và di chuyển mà không cản đường. Dùng training dummy hiện có và giữ hành vi của nó.

### Bắc — Lava

Từ quảng trường đi thẳng qua khu luyện tập, tiếp đến **trụ đá lửa**, cuối đường là **lối sang Lava**. Trụ có vị trí dành cho trạng thái chưa xây/đã xây theo hệ thống thực tế.

### Nam — Ice

Từ quảng trường đi thẳng về phía Nam, đến **khu Madam Croak**, tiếp đến **trụ đá gió**, cuối đường là **lối sang Ice**. Khu Madam Croak có thể là khu riêng dọc trục Nam; quyết định ranh giới scene theo source và nhu cầu thực tế, nhưng không tách những thành phần bắt buộc của scene trung tâm. Dùng NPC/asset sẵn có nếu tìm thấy; nếu chưa có, đặt vị trí dự kiến rõ ràng và báo chưa hoàn thiện, không tạo NPC giả có chức năng không tồn tại.

### Đông — Coral Valley

Từ quảng trường đi thẳng về phía Đông: **nhà thợ rèn và Master Tortuga** nằm cạnh đường, tiếp đến **trụ đá nước**, cuối đường là **lối sang Coral Valley**. Trụ nước có sẵn theo bảng yêu cầu. Bảo toàn luồng tương tác, shop/forge và chiều đi/về giữa Hub–Coral.

### Tây — Swamp

Từ quảng trường đi thẳng về phía Tây: lối vào **scene riêng của Silas** nằm cạnh đường; **lều thương nhân** nằm trong scene Silas. Tiếp tục trên trục Tây là **trụ đá cỏ**, cuối đường là **lối sang Swamp**. Đường trở lại từ Silas phải đưa nhân vật về đúng vị trí lối vào và không tạo đường chéo.

### Checkpoint bên ngoài Hub

Mỗi biome có vị trí **điểm tele checkpoint** và **lửa trại checkpoint** tại checkpoint của chính biome đó. Chúng không nằm trong scene Hub trung tâm. Chỉ sửa biome/checkpoint khi cần để bảo đảm kết nối và khi hệ thống tương ứng đã rõ; không tự đưa bốn checkpoint vào Hub.

## Bảng công trình và kinh tế được cung cấp

Đây là yêu cầu thiết kế để bố trí và đối chiếu với hệ thống thực tế, **không mặc định mọi cơ chế đã tồn tại hoặc bắt buộc phải tự tạo trong đợt dựng layout**:

| Công trình | Quy tắc được cung cấp | Nguyên liệu được cung cấp |
| --- | --- | --- |
| Trụ đá lửa | Phải có trụ tương ứng để đánh boss vùng đó. | 10 lửa của song sinh, 10 càng cua biển, 10 đạn thuốc súng, 20 xương skeleton, 20 đá đen, 20 đá đỏ, 3 đá bị nguyền rủa. |
| Trụ đá gió | Cùng quy tắc trụ. | 10 đuôi đom đóm, 10 dây leo, 10 đầu nấm, 20 xương skeleton, 20 băng vĩnh cửu, 20 hoa tuyết, 3 đá bị nguyền rủa. |
| Trụ đá nước | Cùng quy tắc trụ. | Có sẵn. |
| Trụ đá cỏ | Cùng quy tắc trụ. | 10 đuôi đom đóm, 10 dây leo, 10 đầu nấm, 20 xương skeleton, 20 gỗ cây, 20 cỏ dại, 3 đá bị nguyền rủa. |
| Nhà thợ rèn | Xây xong giảm chi phí thợ rèn 10%. | 10 nguyên liệu mỗi loại từ cây cối của cả bốn map; không gồm nguyên liệu quái. |
| Lều thương nhân | Xây xong giảm 10% giá mọi sản phẩm. | Tầng 1: 10 nguyên liệu mỗi loại từ cây cối của cả bốn map; không gồm nguyên liệu quái. |
| Tele checkpoint Coral | Xây lại ở checkpoint, sau đó có thể về Hub. | 5 lõi sao biển, 5 càng cua biển, 5 thùng thuốc súng, 10 xương skeleton, 12 băng vĩnh cửu, 12 hoa tuyết. |
| Tele checkpoint Swamp | Như trên. | 5 đuôi đom đóm, 5 dây leo, 5 đầu nấm, 10 xương skeleton, 12 gỗ cây, 12 cỏ dại. |
| Tele checkpoint Lava | Như trên. | 5 lửa của song sinh, 5 càng cua biển, 5 đạn thuốc súng, 10 xương skeleton, 12 đá đen, 12 đá đỏ. |
| Tele checkpoint Ice | Như trên. | 5 đuôi đom đóm, 5 dây leo, 5 đầu nấm, 10 xương skeleton, 12 băng vĩnh cửu, 12 hoa tuyết. |
| Tele Hub | Xây lại để đến checkpoint đã chọn. | 200 vàng. |
| Lửa trại Hub/checkpoint | Hồi máu. | Bảng không ghi chi phí. |
| Bảng nhiệm vụ | Xây lại; hoàn thành nhiệm vụ nhận vàng và nguyên liệu tương ứng. | 100 vàng và 5 đá bị nguyền rủa. |

Không tự thêm nguồn nhận, giá, hiệu ứng, công thức, persistence hay điều kiện mở khi chưa có contract. Đặc biệt, công thức tele Coral liệt kê nguyên liệu băng/tuyết dù ghi dùng nguyên liệu của chính map; giữ nguyên thông tin và báo đây là điểm cần xác nhận, không tự sửa. Kiểm tra nguy cơ vòng lặp tiến trình: nguyên liệu cần để xây trụ phải có thể lấy trước khi trụ chặn boss. Nếu chưa thể xác định, ghi rõ thay vì tự quyết.

## Tích hợp và phạm vi

- Kiểm tra tiến trình hiện tại: tài liệu mô tả Coral đầu tiên, sau đó mở ba vùng còn lại, rồi thu thập bốn chìa. Hub mới có thể cho thấy Thạch bàn từ đầu nhưng không tự bỏ khóa progression. Nếu chưa có hệ thống khóa/đặt chìa, chỉ bố trí vị trí và báo rõ.
- Bảo toàn safe location cho toàn bộ Hub, tương tác NPC, training dummy, player state, camera, va chạm, ánh sáng và chiều đi/về. Khi gộp nhiều phần đất phải kiểm tra vị trí spawn, không rơi khỏi map hoặc bị kẹt tại ranh giới; không instance trùng player, camera, môi trường hoặc autoload.
- Với các hệ thống xây dựng, tele, nhiệm vụ hoặc khu biome chưa triển khai, ưu tiên kết nối và dùng chức năng thật đã tồn tại; để lại vị trí dự kiến phân biệt rõ khi chưa có. Không làm nút tương tác giả, không tự tạo save system hoặc báo chức năng hoàn chỉnh nếu chưa hoạt động.
- Tận dụng địa hình, cầu, asset và scene sẵn có; hình thức nhất quán với Hub. Có thể giữ các scene nhỏ làm module kỹ thuật ngay cả khi người chơi không chuyển cảnh giữa chúng. Tránh sửa hoặc xóa nội dung đang dùng ở các map khác.

## Kiểm tra và bàn giao

1. Kiểm tra trực quan từ trên xuống và trong game: bốn tuyến thẳng, Lava phía Bắc, Ice phía Nam; các công trình đúng vị trí; người chơi đi liên tục giữa quảng trường và sân dummy trong cùng scene.
   Kiểm tra nền cỏ/nền đá ở tỷ lệ camera thực tế, đường nối và độ rõ của nhân vật; phá thử cây cỏ và xác nhận nền bên dưới không còn hình thực vật bị vẽ dính.
2. Đi thử bốn hướng tới giới hạn thực tế; kiểm tra từng chuyển cảnh đã có theo cả hai chiều, đặc biệt Hub–Silas và Hub–Coral, điểm spawn, va chạm, camera, lửa trại, dummy, NPC, shop/forge và safe location. Kiểm tra lại sau reload/transition để tránh mất state.
3. Chạy lint, Godot import/headless và test hiện có phù hợp theo `docs/project/testing.md`. Kiểm tra scene/test còn tồn tại trước khi chạy; không tạo test mới hoặc mở rộng CI nếu người dùng không yêu cầu. Báo nguyên lệnh, mã thoát, lỗi và giới hạn môi trường; không khẳng định gameplay hoặc đồ họa đã được xác minh nếu chưa chạy.
4. Cập nhật tài liệu Hub và chuyển cảnh khi bố cục thực tế thay đổi. Báo cụ thể scene/kết nối đã làm, chức năng thực sự hoạt động, các vị trí mới chỉ dành chỗ, điểm chưa thể kết nối và những quyết định cần người dùng xác nhận.