# 外设
组织如下：
```bash
/sources_1/new/devices
├── onboard : 板载外设
├── uart    : 直连串口txd/rxd
└── vga     : DVI显示
```

## UART串口

实现功能如下：
- 支持任意数据宽度
- 支持动态调整收发数量
- 托管传输

数据格式约定：
- 校验位为NONE
- 数据位8位
- 停止位1位

#### 示例
时钟频率50 MHz、波特率9600 Hz，接收`dip_sw[12:9]`个ASCII字符后，将前`dip_sw[3:0]`个ASCII字符发送出去

```verilog
/* thinpad_top.sv */

parameter DATAWIDTH = 8; // ASCII的数据宽度为 8 bit
parameter BUFLEN = 20; // 缓冲区大小为100
parameter CLK_FREQ = 50_000_000; // 主频为 50 MHz（板载时钟）
parameter BAUD = 9600; // 波特率 9600 baud

wire [DATAWIDTH-1:0] data [BUFLEN];

wire recv_clr, recv_done;
integer recv_count = dip_sw[9 +: 4];
uart_din #(
    .DATAWIDTH(DATAWIDTH), .BUFLEN(BUFLEN), 
    .CLK_FREQ(CLK_FREQ), .BAUD(BAUD)
    ) recv (
    .clk(clk_50M), .rst(reset_btn), .clr(recv_clr), 
    .select(1), .done(recv_done),
    .rxd(rxd), .count(recv_count), .din(data)
);

wire send_clr, send_done;
integer send_count = dip_sw[0 +: 4];
uart_dout #(
    .DATAWIDTH(DATAWIDTH), .BUFLEN(BUFLEN), 
    .CLK_FREQ(CLK_FREQ), .BAUD(BAUD)
    ) send (
    .clk(clk_50M), .rst(reset_btn), .clr(recv_clr), 
    .select(recv_done), .done(send_done),
    .txd(txd), .count(send_count), .dout(data)
);

assign recv_clr = send_done; // 发送完毕后清空接收缓冲区
assign send_clr = send_done; // 发送完毕后复位发送缓冲区
```

TODO：
- [ ] 搭建`pyserial`通信脚本