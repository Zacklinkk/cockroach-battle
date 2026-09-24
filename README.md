# 蟑螂大作战

手机优先的 Godot 3D 肉鸽游戏：缩小的人类在杂物间里寻找虫母、消灭蟑螂。

本工程由原站线上 v7 的运行文件恢复，并合入已完成的更新：

- 修复桌面画布被裁切；随容器大小和屏幕像素密度同步。
- 首关周边 3 只分批唤醒，远处 18 只，前 25 秒禁止突进；后续逐关增强。
- 固定拖鞋开局，其他武器进入升级奖励；新增厚底重拍、裂甲连击、霜雷共振。
- 首次开局播放故事动画，可跳过/重播；五关结束后回到现实。
- 保留 v7 美术、骨骼动作、部位破坏与掉落、爆浆淡出、音乐和音效。
- 触须三节错相扫动；蓄力展翅、突击拍翼、结束收拢。冻结停住全身动作，断翅保留掉落与禁飞。
- 前后翅的命中范围跟随骨骼姿态，展开的翅膀可以在实际位置被打掉。

## 试玩与修改

从 GitHub 克隆后，先运行 `python scripts/restore-github-chunks.py`。仓库将 12 个较大的
`dist/game.*.part*` 文件拆成 `.ghchunk0`、`.ghchunk1` 两段；脚本按
`docs/github-chunk-manifest.json` 还原，并逐项核对原文件的大小和 SHA-256。
还原后运行 `npm run build` 检查网页包。GitHub 上的分段文件和还原结果字节一致。

`dist/` 是完整可托管的网页运行版本。通过 HTTP 服务打开，不能直接双击 HTML。
运行 `npm run build` 检查脚本、资源、分块哈希和静态页面链接。

`godot/` 保留可编辑的游戏逻辑、入口和项目配置。使用 Godot **4.7.2**。
模型与贴图的运行数据完整保存在 `dist/game.pck.part*` 中，避免重复提交大文件。
编辑器用的 glTF/PNG 及缓存是派生文件；首次使用可运行：

```bash
python scripts/restore-editor-assets.py /absolute/path/to/gdre_tools.x86_64
```

工具：[GDRE Tools v2.6.4](https://github.com/GDRETools/gdsdecomp/releases/tag/v2.6.4)。
恢复不会覆盖当前游戏脚本。原始制作仓库中未打包的 Blender、雕刻层和
高模源文件无法从运行包恢复；本备份不将派生的可编辑资源冒充这些原始文件。
其中 41 项资源经过有损运行格式逆转换；运行站点仍使用原压缩资源字节。

## 本次打包

采用 GDRE 的 `--compile --bytecode=ebc36a7` 编译 main.gd、balance.gd、anatomy.gd，
再通过 `--pck-patch` 更新对应字节码。本次动作更新相对已发布的新站只改变
main.gdc、anatomy.gdc；163 项资源中，其余 161 项逐文件 SHA-256 一致。
**没有重新导入或重新压缩运行美术，也没有提高突击速度或首关难度。**

后续脚本修改可运行 `python scripts/rebuild-pack.py /absolute/path/to/gdre_tools.x86_64`，再执行验证。

原发布文件与当前更新的来源记录见 `release-recovery.json`；校验摘要在 `docs/`。
原站 Git 服务的读取异常不会改变本工程已有的运行资源。

## 验证

- Godot 4.7.2 运行最终 PCK：启动成功，25 项故事/成长测试和 26 项战斗测试通过。
- 前端：10 项画布尺寸检查、11 项故事/UI 检查、13 项加载异常检查通过。
- WASM 与 PCK 分块均按清单校验；生产 WASM 实际编译通过。
- 未宣称完成真实浏览器视觉验收。
- 动作更新：最终 PCK 的 16 项动作/蒙皮/命中检查和 26 项战斗回归通过。
- 从 Godot 运行包导出实际蒙皮后的待机、蓄力、拍翼和断翅姿态，以 EGL/Mesa
  渲染对照确认触须移动及翅尖抬落；这属于模型姿态检查，不冒充浏览器截图。

新站使用独立的 Sites 身份，原站保留。
