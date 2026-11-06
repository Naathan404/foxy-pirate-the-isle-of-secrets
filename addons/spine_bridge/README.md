# SpineBridge 插件

将整个 `spine_bridge` 文件夹复制到目标 Godot 工程的 `addons/` 下，最终路径为 `res://addons/spine_bridge/`。扩展声明的最低 Godot 版本为 4.7；当前原生库面向 Godot 4.7.2、Windows x86_64。请保留文件夹名称和内部结构；原生版本清单、动态库装载器和 GDScript 使用此路径。

Godot 扫描工程时会发现 `spine_bridge.gdextension`，按其中的 `[libraries]` 加载 Bridge DLL。Bridge 再读取 `providers.json`，从 `windows/` 加载所需 Spine 版本的 provider DLL。`bin/` 只是常见的目录名，并非 Godot 的指定加载目录。

如需检查器混合编辑与 2D 变换控点，请在 **项目 → 项目设置 → 插件** 中启用 `SpineBridge`。根插件会启用 `editor/preview` 与 `editor/transform` 两个子插件。

`SpineSprite`、`SpineSprite3D`、其他节点和渲染辅助脚本位于 `scripts/`；原生扩展会自动注册 Spine 资源和导入器。因此分发时须复制整个文件夹，不能只复制 DLL。

仓库 `SDK/csharp/` 下的专用 C# 封装属于可选 SDK，需要 Godot .NET 工程单独引用；本文件夹提供 GDExtension 与 GDScript 插件。

原生构建入口是仓库中的 `Runtime/native/spine_bridge/SConstruct`，产物直接写入此文件夹。发布包应包含 `spine_bridge.gdextension`、`plugin.cfg`、`plugin.gd`、`providers.json`、`scripts/`、`editor/`、`windows/` 下 Bridge 的三目标变体与 provider 的 editor/release 变体，以及许可证文件（provider 的 template_debug 变体不随插件包分发，debug 导出由运行时回退装载 release 变体）；`*.lib`、`*.exp`、`*.pdb` 是构建附属文件。目标平台导出前应实测编辑器加载和导出包启动；目前配置仅列出 Windows x86_64。

Spine Runtime 的再分发条款见 `SPINE-RUNTIMES-LICENSE.txt` 和 Spine Editor License Agreement；godot-cpp 的许可证见 `GODOT-CPP-LICENSE.md`。
