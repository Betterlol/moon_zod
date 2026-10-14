# core 审查与修复记录

基线：`8f72dc5`。本次以 Zod 4 的缺失、null、默认值和安全整数语义为目标，
保留项目的 JSON 输入、MoonBit API 和 `parse() -> Result` 约定。

| 问题 | 影响 | 修复方式 |
| --- | --- | --- |
| 部分容器和 wrapper 直接返回内部解析结果，跳过自身 rules | object/union/intersection/optional 等类型上的 refine 可以被绕过 | 统一解析协议，每个节点解析后执行自身规则；保留不可继续状态 |
| 数组、tuple、Strict/Passthrough 对象使用原始子值 | 子节点的 default、transform、Strip 清洗结果丢失 | 重建所有容器并写入子节点解析结果 |
| intersection 修改原输入，浅合并覆盖冲突 | 分支互相影响，返回不可同时满足双方契约的数据 | 分支隔离，递归合并对象/数组，冲突返回带路径的错误 |
| optional/default 把 null 当作缺失 | 接受应拒绝的显式 null；缺失默认字段没有出现在输出 | 私有缺失协议；新增 nullable、nullish、prefault、parse_missing |
| 整数检查依赖 Int32 转换，数值边界只接受整数 | 大安全整数误判，小数边界损失，multipleOf 容易误判 | 有限数与安全整数判断，支持 Double 边界，十进制 multipleOf |
| 邮箱、datetime、IPv6 与 URI 检查过宽或不完整 | 错误数据通过校验 | 完整结构和边界检查；datetime 参数显式化 |
| 内建转换与自定义转换只用一个 Bool 区分 | 源码导出无法还原 trim/lower/upper；自定义闭包被伪装为恒等转换 | TransformKind 与 Constraint 元数据；不支持的源码导出明确失败 |
| 导出约束依赖错误消息和单个 annotation | 排他边界、负数边界、多条 pattern/multiple 丢失 | 结构化约束及约束集合，强边界合并，重复约束用 allOf 保留 |
| 遍历未覆盖 tuple/pipe/lazy，按名称去重混淆身份 | 依赖遗漏、递归导出失控、冲突名称静默覆盖 | 独立节点身份、统一子节点遍历、checked 图错误与命名引用 |
| 构造器保存外部可变 Map/Array/Json | 调用者修改参数后，既有 Schema 行为改变 | 构造器复制集合、literal/default 复制 JSON、lazy 缓存解析 |
| object 形状修改保留依赖旧字段的 refine | 回调访问已删除或类型改变的字段 | 拒绝对已 refine 对象做形状修改；先组合后 refine |
| discriminator 没有在分支形状中声明 | Strip 删除 tag，Strict 拒绝 tag | 注入与分支 key 一致的 literal，保留分支规则 |
| 路径用点号直接拼接，union 只保留首条消息 | 无法区分点号字段与嵌套字段，丢失分支诊断 | 转义路径与 PathSegment，完整嵌套 RawIssue |
| 显式消息与解析时错误映射的优先级不一致 | 自定义消息被覆盖，空字符串被错误忽略 | 显式消息来源优先；None 才表示委托默认消息 |
| 导出混淆效果前的输入与效果后的输出 | Schema 与实际解析阶段不符 | checked InputView/OutputView，未知投影返回 Err |
| 递归 struct 源码引用未生成的辅助函数 | 导出看似成功，实际无法编译 | 生成递归辅助函数；CI 编译并执行实际生成源码 |

设计上的主要重构是三个共同协议：解析结果协议、Schema 子节点遍历协议、
可检查的约束和转换元数据。公开解析 helper 保留签名，内部不再维护多套互相
不一致的解析流程。不同输出目标继续放在 exporters，core 不引入异步运行时。

本次没有声称与 TypeScript Zod 的全部能力等价。JSON 回调没有 undefined 值；
brand 是导出元数据；bigint 仍受 JSON Double 限制；URL 不做 WHATWG 规范化；
JSON Schema 导入器不是完整 draft-07 引擎。对于无法忠实表达的 checked 导出，
返回明确错误。具体兼容性变化、替代用法和边界见 [迁移说明](CORE_MIGRATION.md)。

解析正确性修复增加了输入复制与容器重建成本，旧基准不能作为当前速度依据。
后续性能优化应在这些回归测试约束下测量，避免重新引入分支共享和原值返回。

验证包括 core 与跨包回归、Wasm GC / JS 全量测试、格式/接口/无警告检查、
Wasm 构建，以及直接编译并运行导出源码。独立复查中的问题与最终验证结果
记在 [实施记录](superpowers/plans/2026-10-14-core-correctness-plan.md)。

## PR 反馈中的六个组合问题

六条反馈均已复现并逐项修复。checked 输出交集现在递归合并结构；大整数
边界源码保留 Double 类型；pipeline 输出默认值不会被 optional/partial 吞掉；
tuple 中间缺失返回位置错误；可空类型在所有嵌套层保留；URI 所有分支检查
字符与百分号编码。

第 5 条建议中的 `String?` 仍不足以解码实际数据：MoonBit 标准 Option 在
数组中采用 `[值] | null`。因此生成类型使用 `JsonNullable[String]`，同时保留
字段缺失的外层 Option。实际编译测试覆盖 null、普通值、多层数组、nullish
字段和默认字段，并检查 FromJson/ToJson 往返结果。

新增独立 JSON Schema 校验器测试对解析成功的对象、数组、tuple 交集输出做
验证，也用缺少合并必填属性的负例防止契约变成无条件接受。性能数字已在
README 与生成它们的文档片段中同步标为历史数据。
