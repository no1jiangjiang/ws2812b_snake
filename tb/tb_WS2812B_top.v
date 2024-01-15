`timescale 1ns/1ns
module tb_WS2812B_top();

reg sys_clk;
reg sys_rst_n;
reg [2:0]key_in;

wire data_pwm;

parameter T = 20;

always # (T/2) sys_clk = ~sys_clk;

defparam WS2812B_top_inst.data_ctrl_inst.max_1s = 50;
defparam WS2812B_top_inst.key_filter_inst1.CNT_MAX = 30;
defparam WS2812B_top_inst.key_filter_inst2.CNT_MAX = 30;
defparam WS2812B_top_inst.key_filter_inst3.CNT_MAX = 30;
defparam WS2812B_top_inst.HL_ctrl_inst.T_300us  = 15;

WS2812B_top WS2812B_top_inst(
    /*input*/       .sys_clk     (sys_clk  ),
    /*input*/       .sys_rst_n   (sys_rst_n),
                    .key_in      (key_in),

    /*output*/      .data_pwm    (data_pwm)    
);
initial begin
    sys_clk <= 1'b0;
    sys_rst_n <= 1'b0;
    key_in    <= 3'b111;
    #(T*3 + 3)
    sys_rst_n <= 1'b1;
    #(3000*100)
    key_press1;//进入模式选择界面

    #(3000*100)
    key_press1;//进入难度选择界面

    #(3000*100)
    key_press2;//默认选择难度1

    #(3000*100)
    key_press1;//向下转向

    #(3000*100)
    key_press3;//向左转向

    //初始化向右，等待撞墙
    // #(30*100);
    // key_press1;
    // $stop;
end

task key_press1; // 任务名
    integer i;
    begin
        repeat(10)begin
            i = {$random} % 30;
            #i key_in[0] = ~key_in[0];
        end
        // 保持稳定
        key_in[0] = 1'b0;
        #(80 * T);
        // 释放抖动阶段
        repeat(13)begin
            i = {$random} % 30;
            #i key_in[0] = ~key_in[0];
        end
        key_in[0] = 1'b1;
        #(15 * T);
    end 
endtask 

task key_press2; // 任务名
    integer i;
    begin
        repeat(10)begin
            i = {$random} % 30;
            #i key_in[1] = ~key_in[1];
        end
        // 保持稳定
        key_in[1] = 1'b0;
        #(80 * T);
        // 释放抖动阶段
        repeat(13)begin
            i = {$random} % 30;
            #i key_in[1] = ~key_in[1];
        end
        key_in[1] = 1'b1;
        #(15 * T);
    end 
endtask 

task key_press3; // 任务名
    integer i;
    begin
        repeat(10)begin
            i = {$random} % 30;
            #i key_in[2] = ~key_in[2];
        end
        // 保持稳定
        key_in[2] = 1'b0;
        #(80 * T);
        // 释放抖动阶段
        repeat(13)begin
            i = {$random} % 30;
            #i key_in[2] = ~key_in[2];
        end
        key_in[2] = 1'b1;
        #(15 * T);
    end 
endtask 

endmodule