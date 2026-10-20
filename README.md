# FPGA_Beginner · Verilog 入门实验

基于 **Cyclone IV E（EP4CE10F17C8）** 开发板的 Verilog HDL 入门实验，
使用 **Quartus II 13.0.1 SP1** 开发，每个工程独立可综合、可下载。

## 工程目录

| 目录 | 主题 | 标签 | 状态 |
|------|------|------|------|
| [1.1](./1.1) | 按键控制 LED — 组合逻辑 vs 时序逻辑 | `v1.1` | ✅ |
| [1.2](./1.2) | 0~9999 计数 + 四位数码管动态扫描 | `v1.2` | ✅ |
| [1.3](./1.3) | 信号生成与时序观测：分频 / 延迟线 / I²C 信号 / SOP-EOP / 片上探针 | `v1.3` | ✅ |

## 开发环境

| 项目 | 说明 |
|------|------|
| 开发板 | Cyclone IV E `EP4CE10F17C8`（FBGA-256，速度等级 8） |
| 系统时钟 | 50 MHz（`PIN_E1`） |
| 开发工具 | Quartus II 13.0.1 SP1（64-bit） |
| 下载器 | USB-Blaster（JTAG） |

## 目录约定

```
<工程名>/
├── rtl/            # Verilog 源码
├── sim/            # testbench
└── quartus_prj/    # Quartus 工程文件（.qpf / .qsf）
```

Quartus 编译产物（`db/`、`incremental_db/`、`output_files/`）已在 `.gitignore` 中排除，
克隆后重新编译即可复现 `.sof`。

目录按「章.节」编号，标签格式 `vN.N`，每节完成后打一个注释标签。

---

## 1.1 · 按键控制 LED

同一个「按住点亮、松开熄灭」的功能用两种方式实现，对比组合逻辑与时序逻辑：

| LED | 驱动方式 | 关键语法 | 端口类型 | 时钟 |
|-----|----------|----------|----------|------|
| `led_0` | 组合逻辑 | `assign` + 三目运算符 | `wire` | ❌ |
| `led_1` | 时序逻辑 | `always @(posedge clk)` | `reg` | ✅ |

### 引脚分配

| 信号 | 引脚 | 方向 | 说明 |
|------|------|------|------|
| `clk` | `PIN_E1` | in | 50 MHz 系统时钟 |
| `reset_l` | `PIN_D14` | in | 异步复位，低电平有效（KEY4） |
| `key_0` | `PIN_L12` | in | 按键，按下 = 低电平 |
| `key_1` | `PIN_L13` | in | 按键，按下 = 低电平 |
| `led_0` | `PIN_K15` | out | LED，低电平点亮（组合逻辑驱动） |
| `led_1` | `PIN_K16` | out | LED，低电平点亮（时序逻辑驱动） |

**电平约定**：按键按下读到 `0`，LED 输出 `0` 点亮 —— 都是低有效，
所以"按住点亮"就是把按键电平原样送到 LED。

### 学习要点

1. **`wire` vs `reg`**：`assign` 驱动的输出声明为 `wire`，`always` 块驱动的声明为 `reg`。
2. **`=` vs `<=`**：组合逻辑用阻塞 `=`，时序逻辑一律用非阻塞 `<=`。
3. **异步复位**：`negedge reset_l` 写进敏感列表，复位立即生效，不必等时钟沿。
4. **实际差异**：`led_0` 纳秒级响应但会把按键抖动原样传出；`led_1` 最多晚一个时钟周期
   （20 ns），肉眼无差别，但时钟采样为后续加消抖、状态机留下了接入点。

### 编译与下载

用 Quartus II 打开 `quartus_prj/hello_world.qpf` → 全编译（Ctrl+L）→
Programmer 中选 `output_files/hello_world.sof` → Start。

> `.sof` 下载到 SRAM，掉电即失效；掉电保存需转 `.pof` 烧到配置芯片。

### 仿真

`sim/hello_world_tb.v` 用 `task` 组织成两个用例：`test_reset`（复位后拉高）与
`test_key`（遍历 00/01/10/11 四种按键组合），`$display` 逐时刻打印 `led_0`/`led_1`，
对比组合逻辑（立即跟随）与时序逻辑（延迟一个时钟沿）。
在 `sim/` 目录下 `vsim -do sim.do`，或 Quartus 里 Tools → Run EDA Simulation Tool → RTL Simulation。

### 现象

- 按住 `key_0` → `led_0` 亮，松开 → 灭
- 按住 `key_1` → `led_1` 亮，松开 → 灭
- 按住 `reset_l`（KEY4）→ `led_1` 强制熄灭，`led_0` 不受影响

> 工程文件仍名为 `hello_world.qpf` / `.qsf`，顶层实体 `hello_world`，未随目录改名。

---

## 1.2 · 计数器 + 数码管动态扫描

0~9999 循环计数（每 0.1 秒 +1），四位数码管动态扫描显示。
第一个**层次化设计**：顶层只做例化和连线，功能拆在三个子模块里。

```
clk 50MHz ─→ clk_gen ── clk_200hz ─→ dyn_seg    扫描，每位刷新 50Hz
data[13:0] ────────────────────────→ dyn_seg    待显示数据（仿真注入）

（当前 dyn_seg 接 data 便于仿真验证；counter_9999 输出暂悬空，见「已知问题」）
```

| 文件 | 作用 |
|------|------|
| `counter_seg.v` | 顶层，例化并连接三个子模块 |
| `clk_gen.v` | 50MHz 分频出 200Hz / 10Hz |
| `counter_9999.v` | 0~9999 循环计数器 |
| `dyn_seg.v` | 动态扫描 + 七段译码 |

### 分频计算

计数器数满 N 个输入时钟翻转一次输出，翻转一次是半个周期，所以 `f_out = f_in / 2N`：

- **200Hz**：N = 125000 → 50 000 000 / (2 × 125000) = 200 Hz
- **10Hz**：以 200Hz 为时钟，N = 10 → 200 / (2 × 10) = 10 Hz

扫描时钟 200Hz 分给 4 位数码管，每位刷新率 200 / 4 = 50 Hz，刚好不闪。

### 引脚分配

| 信号 | 引脚 | 方向 | 说明 |
|------|------|------|------|
| `clk` | `PIN_E1` | in | 50 MHz 系统时钟 |
| `reset_l` | `PIN_L12` | in | 异步复位，低电平有效 |
| `seg_s[0]`~`seg_s[3]` | `PIN_L1` / `PIN_P3` / `PIN_T4` / `PIN_R5` | out | 位选，低有效（0 选通） |
| `seg[0]`~`seg[7]` | `PIN_L3` / `PIN_R6` / `PIN_R1` / `PIN_L2` / `PIN_J2` / `PIN_P1` / `PIN_T3` / `PIN_N2` | out | 段选 {a,b,c,d,e,f,g,dp}，共阴（1 点亮） |

**电平约定**：位选 `seg_s` 低有效（输出 0 选通该位），段选 `seg` 共阴（输出 1 点亮）。

### 学习要点

1. **层次化设计**：顶层是"接线板"，自己不写逻辑，只例化子模块 + `wire` 互连。
   例化一律用具名连接 `.port(signal)`，端口一多按位置连接极易接错。
2. **动态扫描**：四位数码管段选并联、只有位选分开，同一时刻只能亮一位。
   靠 > 50Hz 的轮流点亮 + 视觉暂留，看起来才是四位同时显示。
3. **循环计数要显式归零**：`counter == 9999` 就回 0。靠 14 位自然溢出的话，
   要数到 16383 才回绕，显示会跑出 9999。
4. **`timescale` 与位宽**：9999 需要 14 位（2¹³ = 8192 不够）。

### 仿真

`sim/counter_seg_tb.v` 用 `task` 组织成 `test_reset`（复位）与 `test_scan`（注入
1234/9876/0000 验证七段译码），`$display` 打印 `seg`/`seg_s`。
在 `sim/` 目录下 `vsim -do sim.do`，或 Quartus 里 Tools → Run EDA Simulation Tool。
顶层 `data` 端口就是为这个注入加的（见「已知问题」）。

### 现象

四位数码管从 0000 开始，每 0.1 秒加 1，到 9999 后回 0 循环。

### 已知问题

- `clk_10hz` 由 `clk_200hz` 这个寄存器输出当时钟驱动，属于**衍生时钟**。
  入门够用，工程上应改成「时钟使能」写法：全部寄存器统一挂 50MHz，用 en 脉冲控制更新。
- **顶层 `data` 端口（仿真注入用）**：为验证段码译码，`dyn_seg` 的 `.data` 现接顶层
  `data` 而非 `counter`，`counter_9999` 输出悬空；且 `data[13:0]` 在 `.qsf` 未绑引脚。
  故本版偏仿真验证，板上不会显示计数——恢复计数显示把 `counter_seg.v` 里
  `.data(data)` 改回 `.data(counter)`（或加一个选择端做 mux）即可。

---

## 1.3 · 信号生成与时序观测基础模块

本节不做「外设点亮」类实验，而是 5 个**信号生成 / 时序处理**基础模块，全部
**无引脚绑定**，主要靠 ModelSim 仿真 + SignalTap II 片上观测验证（`source_probe`
就是 SignalTap 的 In-System Source & Probe IP）。目录比 1.1/1.2 多嵌套一层：
`1.3/<工程名>/{rtl,sim,quartus_prj}`。

| 子工程 | 顶层实体 | 功能 |
|--------|----------|------|
| [clock_frequency_divider](./1.3/clock_frequency_divider) | `clock_frequency_divider` | 分数分频器（相位累加器），`f_out = f_in × div_N / (2×div_M)` |
| [fix_delay](./1.3/fix_delay) | `dynamic_delay` | 数字延迟线：固定(`fix_delay`)与动态(`dynamic_delay`)两种，双口 RAM 环形缓冲 |
| [signal](./1.3/signal) | `signal` | I²C 读/写请求锁存 + 脉宽扩展（单拍 exec → 约 131 周期 flag / I2C_start） |
| [sop_eop_gen](./1.3/sop_eop_gen) | `sop_eop_gen` | 数据包 SOP/EOP 指示：对 i_en 打拍 + 边沿检测 |
| [source_probe](./1.3/source_probe) | `source_probe` | SignalTap II In-System Source & Probe（`altsource_probe` IP） |

> `fix_delay` 工程同时含 `fix_delay`（延迟值编译期固定）与 `dynamic_delay`（延迟值
> 运行时可变）两个模块，共享 `simple_dual_port_ram.v`；Quartus 顶层设为 `dynamic_delay`。

### 学习要点

1. **分数分频 vs 整数分频**：整数分频（÷N）占空比不一定 50%；分数分频用相位累加器
   每次累加 `div_N`、到 `div_M` 就翻转并减去 `div_M`，平均分频比 `div_M/div_N`。
2. **数字延迟线**：环形缓冲 + 读写指针错位。`simple_dual_port_ram` 顶层用 `generate`
   按 `ram_type` 选寄存器 / M9K 实现，`syn_ramstyle` 属性强制综合方式。
3. **边沿检测**：`o_sop = i_en & ~i_en_d0`、`o_eop = ~i_en & i_en_d0`——把使能打一拍再
   与当前拍取反相与，得到刚好 1 拍的起始/结束脉冲，类似 AXI-Stream 的 valid/tlast。
4. **单拍 → 长脉冲（脉宽扩展）**：`signal` 里 exec 单拍触发后，计数器数到 130 再清零，
   把标志展宽约 131 个周期，用于 I²C 时钟展宽这类慢外设时序。
5. **衍生时钟警示**：`clk_out`、`clk_200hz` 这类寄存器输出若再拿去当时钟源会形成
   衍生时钟（1.2 已有「已知问题」）。这里统一用 `clk_en` 时钟使能来冻结/更新。

### 仿真

每个子工程在 `sim/` 下自带 testbench：`clock_frequency_divider` / `fix_delay` /
`dynamic_delay` 用 ModelSim 脚本（`.do`）或 `iverilog` 编译运行；`signal` /
`sop_eop_gen` 的 tb 是自校验式，覆盖复位/空闲/读写/单拍多拍包/`clk_en` 冻结等用例，
跑完打印 `ALL TESTS PASSED`。`source_probe` 无 tb，需配合 SignalTap II 上板观察。

### 说明（无板上现象）

这些模块的 `.qsf` 里都**没有引脚分配**（无 `set_location_assignment`），能综合、
能仿真，但下载到板上不会有 LED/数码管现象——它们是供仿真与 SignalTap 观测的信号源
和时序处理单元，不是外设驱动实验。
