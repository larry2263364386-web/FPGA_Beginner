# FPGA_Beginner · Verilog 入门实验

基于 **Altera Cyclone IV E（EP4CE10F17C8）** 开发板的 Verilog HDL 入门系列实验，
使用 **Quartus II 13.0.1 SP1** 开发。代码按「工程」组织，每个工程独立可综合、可下载。

> 姊妹仓库：[STM32-L2](https://github.com/larry2263364386-web/STM32-L2)（FreeRTOS 进阶实验）

---

## 工程目录

| 目录 | 主题 | 标签 | 状态 |
|------|------|------|------|
| [hello_world](./hello_world) | 按键控制 LED — 组合逻辑 vs 时序逻辑对比 | `p01-hello_world` | ✅ |

---

## 开发环境

| 项目 | 说明 |
|------|------|
| 开发板 | Cyclone IV E `EP4CE10F17C8`（FBGA-256，速度等级 8） |
| 系统时钟 | 50 MHz（`PIN_E1`） |
| 开发工具 | Quartus II 13.0.1 Build 232 SP1（64-bit） |
| 硬件描述语言 | Verilog-2001 |
| 下载器 | USB-Blaster（JTAG 模式） |
| 核心电压 | 1.2 V，I/O 标准 2.5 V |

---

## 目录约定

每个工程统一采用三级目录，源码与工程文件分离：

```
<工程名>/
├── rtl/            # Verilog 源码（唯一的"真相来源"）
├── sim/            # 仿真用 testbench
└── quartus_prj/    # Quartus 工程文件（.qpf / .qsf）
```

> Quartus 编译产生的 `db/`、`incremental_db/`、`output_files/` 均为构建产物，
> 已在 `.gitignore` 中排除 —— 克隆后重新编译即可完全复现，包括 `.sof` 位流文件。

---

## p01 · hello_world — 按键控制 LED

### 实验目标

同一个「按住点亮、松开熄灭」的功能，用两种截然不同的方式实现，
直观体会 Verilog 中**组合逻辑**与**时序逻辑**的区别：

| LED | 驱动方式 | 关键语法 | 端口类型 | 是否需要时钟 |
|-----|----------|----------|----------|--------------|
| `led_0` | 组合逻辑 | `assign` + 三目运算符 | `wire` | ❌ 不需要 |
| `led_1` | 时序逻辑 | `always @(posedge clk)` | `reg` | ✅ 需要 |

### 引脚分配

| 信号 | 引脚 | 方向 | 说明 |
|------|------|------|------|
| `clk` | `PIN_E1` | in | 50 MHz 系统时钟 |
| `rst_n` | `PIN_D14` | in | 异步复位，低电平有效（KEY4） |
| `key_0` | `PIN_L12` | in | 按键，按下 = 低电平 |
| `key_1` | `PIN_L13` | in | 按键，按下 = 低电平 |
| `led_0` | `PIN_K15` | out | LED，低电平点亮（组合逻辑驱动） |
| `led_1` | `PIN_K16` | out | LED，低电平点亮（时序逻辑驱动） |

### 电平约定（务必与原理图一致）

- **按键**：一端接地、一端上拉 → 按下读到 `0`，松开读到 `1`
- **LED**：阳极接 VCC、阴极接 FPGA 引脚 → 输出 `0` 点亮，输出 `1` 熄灭

两者都是「低有效」，所以"按住点亮"本质上就是把按键的低电平原样送到 LED 上。

### 核心代码

组合逻辑 —— 描述的是一根"导线"，右边一变左边立刻跟着变，没有存储：

```verilog
assign led_0 = (key_0 == 1'b0) ? 1'b0 : 1'b1;
```

时序逻辑 —— 描述的是一个"寄存器"，只在时钟上升沿更新，带异步复位：

```verilog
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0)          led_1 <= 1'b1;   //复位，灯灭
    else if(key_1==1'b0)     led_1 <= 1'b0;   //按下，灯亮
    else if(key_1==1'b1)     led_1 <= 1'b1;   //松开，灯灭
end
```

### 学习要点

1. **`wire` vs `reg`**：被 `assign` 驱动的输出声明为 `wire`，被 `always` 块驱动的声明为 `reg`。
   `reg` 只是语法上的"可在过程块中赋值"，并不等于一定综合成寄存器。
2. **阻塞 `=` vs 非阻塞 `<=`**：组合逻辑用 `=`，时序逻辑一律用 `<=`，
   保证同一时钟沿上所有寄存器"同时"更新，避免仿真与综合结果不一致。
3. **异步复位**：`negedge rst_n` 写进敏感列表，复位一拉低立即生效，不必等时钟沿。
   时序逻辑必须带复位，否则上电后寄存器状态不确定。
4. **两者的实际差异**：`led_0` 纳秒级响应但会把按键机械抖动原样传出去；
   `led_1` 最多晚一个时钟周期（20 ns）才响应 —— 肉眼完全看不出区别，
   但时钟采样为后续加消抖、状态机留下了接入点。
5. **`timescale`** 只影响仿真，不影响综合出来的硬件。

### 编译与下载

```bash
# 1. 用 Quartus II 打开工程
quartus_prj/hello_world.qpf

# 2. 全编译    Processing → Start Compilation   (Ctrl+L)
# 3. 连接 USB-Blaster，打开 Programmer          (Tools → Programmer)
# 4. 选择 output_files/hello_world.sof，勾选 Program/Configure，点 Start
```

> `.sof` 下载到 SRAM，掉电即失效；如需掉电保存需转换为 `.pof` 烧写到配置芯片。

### 现象

- 按住 `key_0`（PIN_L12）→ `led_0` 点亮，松开 → 熄灭
- 按住 `key_1`（PIN_L13）→ `led_1` 点亮，松开 → 熄灭
- 按住 `rst_n`（KEY4）→ `led_1` 强制熄灭（异步复位），`led_0` 不受影响

---

## 标签约定

每个工程完成后打一个注释标签，格式 `pNN-<工程名>`（如 `p01-hello_world`），
方便按顺序回溯每个阶段的完整代码。

```bash
git tag -a p01-hello_world -m "p01: hello_world — 按键控制 LED"
```
