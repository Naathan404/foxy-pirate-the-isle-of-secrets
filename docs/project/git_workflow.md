# Git Workflow

## Bước 1: Nhận và chuẩn bị task

- Task cần có mục tiêu, tiêu chí hoàn thành và phạm vi file/module dự kiến sửa.
- Trước khi chạm vào core, data, scene/asset dùng chung hoặc project.godot, thông báo trong task/nhóm để tránh hai người sửa cùng chỗ.
- Tạo nhánh từ dev mới nhất. Không làm trực tiếp trên dev hoặc main.
- Một nhánh chỉ phục vụ một task. Bắt đầu task khi working tree sạch; commit, stash hoặc bỏ các thay đổi cũ trước khi đổi task.

~~~powershell
git switch dev
git pull origin dev
git switch -c <type>/<task-id>-<mo-ta-ngan>
~~~

Loại nhánh: **feat**, **fix**, **refactor**, **test**, **docs**, **chore**. Ví dụ: feat/42-player-dash.

## Bước 2: Làm việc trên local

- Chỉ sửa phần thuộc task; tách refactor lớn hoặc format hàng loạt thành task/PR khác.
- Commit nhỏ, mỗi commit giải quyết một thay đổi logic rõ ràng.
- Không sửa công việc đang dở của thành viên khác. Nếu bắt buộc chạm vào phần dùng chung, thống nhất người tích hợp trước.
- Khi bị chặn bởi dependency, conflict hoặc thiếu quyết định, báo sớm kèm: vấn đề, ảnh hưởng và điều cần nhóm quyết định.

## Bước 3: Stage và commit

~~~powershell
git status # Kiểm tra trước commit
git add .
git commit -m "..."
~~~
- Nếu git status có thay đổi của task khác, **không dùng `git add .`**. Hãy tách task sang nhánh/working tree khác, hoặc stage theo phạm vi: **`git add gameplay/player/ data/`**.

Dùng Conventional Commits: **type(scope): mô tả ngắn**.

~~~text
feat(player): thêm kỹ năng lướt
fix(ui): chặn mở pause menu khi game over
refactor(combat): tách logic tính sát thương
docs: cập nhật code convention
~~~

- Không dùng commit mơ hồ như update, fix bug hoặc wip trên nhánh chuẩn bị merge.
- Không commit cache Godot, file build, log, secret hoặc thay đổi không liên quan.

## Bước 4: Tự kiểm tra, đồng bộ và push

Trước khi push, đảm bảo working tree sạch, đồng bộ với dev rồi chạy lint, kiểm tra định dạng và game/test liên quan.

~~~powershell
git status
git pull --rebase origin dev
python -m gdtoolkit.linter core data gameplay test ui world
python -m gdtoolkit.formatter --check core data gameplay test ui world
# Chạy game hoặc test liên quan

git push origin <branch-name>
~~~

- Nếu còn thay đổi chưa commit, quay lại Bước 3; không rebase khi chưa biết rõ các thay đổi đó thuộc task nào.
- Tự giải quyết conflict trên nhánh cá nhân. Với conflict ở scene, resource hoặc project.godot, phải mở lại Godot để kiểm tra tham chiếu.
- Không force-push lên dev hoặc main. Chỉ dùng force-with-lease trên nhánh cá nhân khi thật sự cần.

## Bước 5: Pull request và merge

PR luôn nhắm vào **dev** và phải có:

- Mục tiêu/thay đổi chính và task liên quan.
- Cách kiểm thử cùng kết quả; ảnh hoặc video nếu thay đổi UI/gameplay.
- Những thay đổi tới contract, cấu hình hoặc file dùng chung.
- Rủi ro, giới hạn hoặc việc còn lại nếu có.

Tác giả tự review diff trước. Reviewer kiểm tra hành vi, regression, dependency, khả năng bảo trì và test. Chỉ merge khi conflict đã được xử lý, review bắt buộc đã xong và project vẫn chạy được. Main chỉ nhận thay đổi phát hành từ dev theo quyết định của nhóm.

## Checklist trước PR

- [ ] Nhánh tạo từ dev và đã rebase với dev mới nhất.
- [ ] Code đúng định dạng, tên và thứ tự script trong [conventions.md](conventions.md).
- [ ] Lint và formatter đạt với `gdtoolkit==4.5.0`; đã review các quy tắc công cụ không kiểm tra.
- [ ] Đã chạy game/test liên quan; không có lỗi hoặc warning mới.
- [ ] Đã xem git diff và git diff --staged; không có cache, build, secret hoặc file không liên quan.
- [ ] Đã thông báo thay đổi ảnh hưởng code/scene/data/cấu hình dùng chung.
- [ ] PR mô tả rõ thay đổi, cách test và ảnh hưởng.

## Ngoại lệ

Ngoại lệ cần có lý do kỹ thuật và ghi trong PR. Nếu lặp lại, cập nhật tài liệu tương ứng để toàn nhóm cùng áp dụng.
