# FPGA_Beginner · Verilog 入门实验

基于 **Cyclone IV E（EP4CE10F17C8）** 开发板的 Verilog HDL 入门实验，
使用 **Quartus II 13.0.1 SP1** 开发，每个工程独立可综合、可下载。

## 工程目录

| 目录 | 主题 | 标签 | 状态 |
|------|------|------|------|
| [hello_world](./hello_world) | 按键控制 LED — 组合逻辑 vs 时序逻辑 | `p01-hello_world` | ✅ |

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

标签格式 `pNN-<工程名>`，每个工程完成后打一个注释标签。

---

## p01 · hello_world

同一个「按住点亮、松开熄灭」的功能用两种方式实现，对比组合逻辑与时序逻辑：

| LED | 驱动方式 | 关键语法 | 端口类型 | 时钟 |
|-----|----------|----------|----------|------|
| `led_0` | 组合逻辑 | `assign` + 三目运算符 | `wire` | ❌ |
| `led_1` | 时序逻辑 | `always @(posedge clk)` | `reg` | ✅ |

### 引脚分配

| 信号 | 引脚 | 方向 | 说明 |
|------|------|------|------|
| `clk` | `PIN_E1` | in | 50 MHz 系统时钟 |
| `rst_n` | `PIN_D14` | in | 异步复位，低电平有效（KEY4） |
| `key_0` | `PIN_L12` | in | 按键，按下 = 低电平 |
| `key_1` | `PIN_L13` | in | 按键，按下 = 低电平 |
| `led_0` | `PIN_K15` | out | LED，低电平点亮（组合逻辑驱动） |
| `led_1` | `PIN_K16` | out | LED，低电平点亮（时序逻辑驱动） |

**电平约定**：按键按下读到 `0`，LED 输出 `0` 点亮 —— 都是低有效，
所以"按住点亮"就是把按键电平原样送到 LED。

### 学习要点

1. **`wire` vs `reg`**：`assign` 驱动的输出声明为 `wire`，`always` 块驱动的声明为 `reg`。
2. **`=` vs `<=`**：组合逻辑用阻塞 `=`，时序逻辑一律用非阻塞 `<=`。
3. **异步复位**：`negedge rst_n` 写进敏感列表，复位立即生效，不必等时钟沿。
4. **实际差异**：`led_0` 纳秒级响应但会把按键抖动原样传出；`led_1` 最多晚一个时钟周期
   （20 ns），肉眼无差别，但时钟采样为后续加消抖、状态机留下了接入点。

### 编译与下载

用 Quartus II 打开 `quartus_prj/hello_world.qpf` → 全编译（Ctrl+L）→
Programmer 中选 `output_files/hello_world.sof` → Start。

> `.sof` 下载到 SRAM，掉电即失效；掉电保存需转 `.pof` 烧到配置芯片。

### 现象

- 按住 `key_0` → `led_0` 亮，松开 → 灭
- 按住 `key_1` → `led_1` 亮，松开 → 灭
- 按住 `rst_n`（KEY4）→ `led_1` 强制熄灭，`led_0` 不受影响
