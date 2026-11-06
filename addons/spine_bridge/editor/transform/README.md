# Spine 变换（Spine Transform）

在 Godot 2D 编辑器中启用工具栏的 **Spine 变换** 按钮，操作 `SpineSprite`：

- 点击模型包围框内部选中，拖动内部移动。
- 四角自由缩放，按住 Shift 等比缩放；拖动中可以切换 Shift。
- 四边（包括整段边线）单轴缩放，Shift 不改变这个行为。
- 缩放时固定对侧角或边；到达对侧后停在最小尺寸，不自动翻转。
- Esc 或右键恢复本次拖动前的变换，不产生撤销记录。
- 松开左键提交一次 Undo / Redo；单击或回到原位不提交。
- 切换场景、改变选择、关闭模式或窗口失焦会取消当前操作。

包围框使用 `SpineSprite.get_bounds()` 的本地坐标；未加载模型时使用占位框。
锁定节点、分组内部节点和场景内 SubViewport 的节点不参与操作。
按住 Space 可使用编辑器画布平移；关闭按钮即可使用原生编辑工具。

`plugin.gd` 负责输入捕获、选取、绘制和 Undo / Redo。
`transform_math.gd` 仅根据按下时的变换、边界、鼠标位移计算缩放，避免累计误差。

`tests/runner.gd` 是定向编辑器测试：在临时 Godot 项目中复制本插件，
将临时 `plugin.cfg` 的 `script` 指向 `tests/runner.gd`，启用该插件，
运行 `godot --headless --editor --path <临时项目>`。测试自动退出并报告 PASS 或失败项。
不要在工作项目中启用测试入口，它会打开测试场景并退出编辑器。
