/*************************************************

模块名           : WS2812B_top.v
***************模块功能描述**********************
这是WS2812B的顶层模块，我们计划在8x8实现每一行显示的颜色不同，后续再修改数据显示名字

*************************************************/
module WS2812B_top(
    input       sys_clk     ,//系统时钟
    input       sys_rst_n   ,//系统复位
    input [2:0] key_in      ,//按键信号 未消抖

    output      data_pwm     //0/1码的方波信号
);

    wire [23:0] RGB_data_r;
    wire tx_done_r;
    wire tx_24x64_done;
    wire reset_done;
    wire game_rsult;
    //按键消抖信号寄存
    wire [2:0] key_r;
    wire [2:0]difficulty;
    wire en_snake  ;
    wire [1:0] key_flag;
    assign key_flag = {key_r[2],key_r[0]};
    wire game_over;
    wire game_win ;
    wire tx_24x64_done_r1;
    wire tx_24x64_done_r2;
    wire [23:00]RGB_data_r1;
    wire [23:00]RGB_data_r2;

    assign RGB_data_r = RGB_data_r1 | RGB_data_r2;
    assign tx_24x64_done = tx_24x64_done_r1 || tx_24x64_done_r2;
/*********************RGB色彩数据处理**********************/
data_ctrl data_ctrl_inst(
    /*input*/               .sys_clk         (sys_clk  ),
    /*input*/               .sys_rst_n       (sys_rst_n),
                            .tx_done_flag    (tx_done_r),
    /*input        [2:0]*/  .key_in          (key_r     ),//消抖后的按键信号
    /*input             */  .g_over          (game_over),//游戏失败、跳出lose界面
                            .g_win           (game_win ),//游戏失败、跳出win界面

    /*output reg [23:0]*/   .RGB_data        (RGB_data_r1),
                            .tx_24x64_done   (tx_24x64_done_r1),
                            .difficulty      (difficulty)//难度系数的选择   
);
/*********************贪吃蛇的控制模块**********************/
snake_ctrl snake_ctrl_inst(
    /*input             */      .sys_clk                 (sys_clk  ),
    /*input             */      .sys_rst_n               (sys_rst_n),
    /*input             */      .tx_done_flag            (tx_done_r),
    /*input        [2:0]*/      .difficulty              (difficulty),//难度系数 
    /*input        [1:0]*/      .key_flag                (key_flag),

    /*output             */     .game_over               (game_over),//游戏失败、跳出lose界面
    /*output             */     .game_win                (game_win ),//游戏失败、跳出win界面
    /*output  reg  [23:0]*/     .RGB_data                (RGB_data_r2),
    /*output             */     .tx_24x64_done           (tx_24x64_done_r2) 
);

/*********************高低电平信号编码处理**********************/
HL_ctrl HL_ctrl_inst(
    /*input       */    .sys_clk             (sys_clk  ),
    /*input       */    .sys_rst_n           (sys_rst_n),
    /*input [23:0]*/    .rgb_data            (RGB_data_r),
                        .tx_24x64_done       (tx_24x64_done),

    /*output  */        .send_clk            (data_pwm),
                        .tx_done             (tx_done_r) 
);

//按键1
key_filter key_filter_inst1(
    /*input wire*/ .sys_clk     (sys_clk  ),
    /*input wire*/ .sys_rst_n   (sys_rst_n),
    /*input wire*/ .key_in      (key_in[0]),

    /*output reg*/ .key_flag    (key_r[0])//传回单个脉冲标志
);

//按键2
key_filter key_filter_inst2(
    /*input wire*/ .sys_clk     (sys_clk  ),
    /*input wire*/ .sys_rst_n   (sys_rst_n),
    /*input wire*/ .key_in      (key_in[1]),

    /*output reg*/ .key_flag    (key_r[1])//传回单个脉冲标志
);

//按键3
key_filter key_filter_inst3(
    /*input wire*/ .sys_clk     (sys_clk  ),
    /*input wire*/ .sys_rst_n   (sys_rst_n),
    /*input wire*/ .key_in      (key_in[2]),

    /*output reg*/ .key_flag    (key_r[2])//传回单个脉冲标志
);
endmodule