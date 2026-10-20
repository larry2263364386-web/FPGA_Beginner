// **************************** Declaration ****************************
// File name:        source_probe.v
// Author:           Larry
// Date:             2026-10-20
// Version Number:   1.0
// Abstract:         Quartus 生成的 altsource_probe IP 封装
//                   SignalTap II In-System Sources and Probes（片上源与探针）
// Board:            Cyclone IV E  EP4CE10F17C8
// Clock:            50 MHz (PIN_E1)
//
// Modification history:(including time, version, author and abstract)
// 2026-10-20   version 1.0   Larry
// Abstract: Initial
// **************************** end ****************************
//
// 说明：本文件由 Quartus II MegaWizard 自动生成，封装 altsource_probe 原语。
//   probe  : 36 位输入  —— 把片内信号接到 JTAG，供 SignalTap / 探针观察
//   source : 66 位输出  —— 从 JTAG 向片内注入激励（In-System Source）
//   一般不要手动修改，重生成 IP 时会被覆盖。

// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on

module source_probe (
    probe,
    source);

    input  [35:0] probe;
    output [65:0] source;

    wire [65:0] sub_wire0;
    wire [65:0] source = sub_wire0[65:0];

    altsource_probe altsource_probe_component (
                .probe  (probe),
                .source (sub_wire0)
                // synopsys translate_off
                ,
                .clrn (),
                .ena  (),
                .ir_in (),
                .ir_out (),
                .jtag_state_cdr (),
                .jtag_state_cir (),
                .jtag_state_e1dr (),
                .jtag_state_sdr (),
                .jtag_state_tlr (),
                .jtag_state_udr (),
                .jtag_state_uir (),
                .raw_tck (),
                .source_clk (),
                .source_ena (),
                .tdi (),
                .tdo (),
                .usr1 ()
                // synopsys translate_on
                );

    defparam
        altsource_probe_component.enable_metastability   = "NO",
        altsource_probe_component.instance_id            = "NONE",
        altsource_probe_component.probe_width            = 36,
        altsource_probe_component.sld_auto_instance_index = "YES",
        altsource_probe_component.sld_instance_index     = 0,
        altsource_probe_component.source_initial_value   = " 0",
        altsource_probe_component.source_width           = 66;

endmodule
