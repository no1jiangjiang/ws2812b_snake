/*************************************************

模块名           : HL_ctrl.v
***************模块功能描述**********************
此模块根据我们的RGB数值，判断0/1来输出不同的码型
这里我们的频率是1秒发送800kbit,那么发送一个bit的需要62次晶振，周期为1240ns
传输0码时要求我们的低电平维持时间长于高电平：我们设为940  300  47 15
传输1码时要求我们的高电平维持时间长于低电平：我们设为620  620  15 47 
我们需要根据data_ctrl模块输入进来的24x64结束的标志来开始我们的复位

我们需要给出我们向WS2812B模块的0/1数据方波信号
此外还有发送完24bit即一个灯的结束信号

即使是只显示一个界面也需要复位信号，否则你需要在下载sof下载两次也有复位效果、其次就是按下系统的复位按键

在我们动态切换界面时，由于我们的WS2812B是8x8 的64个级联的RGB灯，我们不满足1024点，所以我们的刷新速率不能超过30帧/s(33.3ms)
即我们在切换不同界面的内容时，不能快于33.3ms，否则可能出现重叠
*************************************************/
module HL_ctrl (
    input           sys_clk         ,//系统时钟
    input           sys_rst_n       ,//系统复位
    input [23:0]    rgb_data        ,//需要发送的24位RGB数据
    input           tx_24x64_done   ,//24x64发送结束，需要复位刷新

    output          send_clk        ,//发送到WS2812B模块的方波
    output          tx_done         //24bit发送结束
);

//300us复位
parameter T_300us = 15_000;

reg [13:0] cnt_300us ;//300us复位

//62的周期计数
reg [5:0] cnt_period;
always @(posedge sys_clk or negedge sys_rst_n)begin
    if(!sys_rst_n)begin
        cnt_period <= 6'd0;
    end
    else if(cnt_period == 61)begin //1bit发完
        cnt_period <= 6'd0;
    end
    else if(cnt_300us == T_300us)begin
        cnt_period <= cnt_period + 1'b1;
    end
    else begin
        cnt_period <= 6'd0;
    end
end

//0码
reg LOW;
always @(posedge sys_clk or negedge sys_rst_n)begin
    if(!sys_rst_n)begin
        LOW <= 1'b1;
    end
    else if(cnt_period < 15)begin
        LOW <= 1'b1;
    end
    else begin
        LOW <= 1'b0;
    end
end

//1码
reg High;
always @(posedge sys_clk or negedge sys_rst_n)begin
    if(!sys_rst_n)begin
        High <= 1'b1;
    end
    else if(cnt_period < 47)begin
        High <= 1'b1;
    end
    else begin
        High <= 1'b0;
    end
end

//24位bit计数器
reg [4:0] cnt_data;
always @(posedge sys_clk or negedge sys_rst_n)begin
    if(!sys_rst_n)begin
        cnt_data <= 5'd23;//从高位开始
    end
    else if(cnt_period == 61 && cnt_data ==0)begin//1bit发完并且是最后一个bit时、重新开始第二个24位数据的计数
        cnt_data <= 5'd23;
    end
    else if(cnt_period == 61)begin//1bit发完开始下一位
        cnt_data <= cnt_data - 1'b1;
    end
    else begin//没发完继续保持发送状态的电平
        cnt_data <= cnt_data;
    end
end


assign tx_done = (cnt_period == 61) && (cnt_data == 0);//一组24bit数据发送结束，从高位开始


// reg [13:0] cnt_300us ;
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)begin
        cnt_300us <= 14'd0;
    end
    else if(tx_24x64_done)begin//一个页面发完需要给一段复位信号、在动态显示时是持续信号、单个页面为标志信号
        cnt_300us <= 14'd0;
    end
    else if(cnt_300us >= T_300us )begin
        cnt_300us <= T_300us;
    end
    else begin
        cnt_300us <= cnt_300us + 1'b1;
    end
end

assign reset_done = cnt_300us >= T_300us;
//复位信号无效时如果该数据为高时，表示要发1码
assign send_clk = (cnt_300us < T_300us) ? 1'b0 : rgb_data[cnt_data] ? High : LOW;
endmodule   