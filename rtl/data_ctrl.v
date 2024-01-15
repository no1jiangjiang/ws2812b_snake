/*************************************************

模块名           : data_ctrl.v
***************模块功能描述**********************
这里我们通过扫描我们的所处位置，对不同的位置我们给不同的RGB值

这个模块主要实现对整个系统界面的控制 ：开始界面、模式选择界面、难度系数选择界面、结束界面、
我们通过寄存在rom中的点阵数据，通过帧计数器，每次平移对应的帧数达到滚动的效果，在达到末尾界面时，跳回初始的位置重新滚动
难点：
1、滚动界面时 对界面进行切换时对其余数据的操作及时序把控
2、滚动界面时对坐标的处理
3、我们需要在显示新的一帧或者状态跳转界面时需要用到reset_flag对我们的复位有一定操作(需要思考)
再者就是字模的选取比较繁琐，用到c语言对数据进行处理、剩余8秒结束界面尚未处理
*************************************************/
module data_ctrl (
    input                   sys_clk          ,//系统时钟
    input                   sys_rst_n        ,//系统复位
    input                   tx_done_flag     ,//24addr发送结束标志，此时需要我们移动位置
    input        [2:0]      key_in           ,//消抖后的按键信号
    input                   g_over           ,//游戏失败、跳出lose界面
    input                   g_win            ,//游戏失败、跳出win界面

    output  reg  [23:0]      RGB_data        ,//不同位置给出不同的RGB数值
    output  reg              tx_24x64_done   ,//在显示单个页面时为标志信号(此时只是复位了300us)、动态显示时为持续信号(此时复位了300us+ T)需要大于33.3ms  
    output       [2:0]       difficulty      //难度系数的选择    
);
/*********************彩带显示**********************/
//8种颜色数据
parameter WHITE     = 24'b00001111_00001111_00001111;  //白色
parameter RED       = 24'b00001111_00000000_00000000;  //红色
parameter GREEN     = 24'b00000000_00001111_00000000;  //绿色
parameter BLUE      = 24'b00000000_00000000_00001111;  //蓝色
parameter YELLOW    = 24'b00000000_00001111_00001111;  //黄色
//0111110000010000000100000001000000010000000100000001000001111100
/*0 :   0000100000001000000010000000100000001000000010000000100000001000;
1   :   0000000001111110000000100000010000011000001000000111111000000000;
2   :   0011111000000010000000100000111000000100000000100011111000000000;
3	:	0000100000010100001000100011111000100010001000100010001000000000;
4	:	0110000001010000010010000100100001001000010010000101000001100000;
5	:	0111110001000000010000000111110001000000010000000100000001111100;
6	:	0111110000010000000100000001000000010000000100000001000001111100;
7	:	0100000001000000010000000100000001000000010000000111111000000000;
8	:	1000000111000011101001011001100110000001100000011000000100000000;
9	:	1000001011000010101000101001001010001010100001101000001000000000;
10	:	0111100010000100100001001000010010000100100001000111100000000000;
11	:	1111100010001000100010001111100011000000101000001001000010001000;
12	:	0011110001000000010000000100000000111110000000100000001001111110;
13	:	0111110000010000000100000001000000010000000100000001000000000000;
14	:	1000000110000001100000011001000110101001110001011000001110000001;
0011110001000000010000000100000000111110000000100000001001111110;*/

//变量

wire  [8:0]   address            ;
reg   [8:0]   address_r          ;
reg           rden               ;
reg           start_rden         ;
reg           model_rden         ;
reg           lose_rden          ;
reg           win_rden           ;
reg           q_r                ;
wire          start_q            ;
wire          model_q            ;
wire          lose_q             ;
wire          win_q              ;

reg   [7:0]   cnt_xy             ;
reg   [63:0]  data               ;
//寄存难度系数界面
reg   [63:0] data_r1 = 64'b0000100000001000000010000000100000001000000010000000100000001000;
reg   [63:0] data_r2 = 64'b0000000001111110000000100000010000011000001000000111111000000000;
reg   [63:0] data_r3 = 64'b0011111001000000010000000011000000001000000100000010000001111110;


parameter  max = 64;

reg        high_1s;
parameter  max_1s = 50_000_000;
reg [25:0] cnt_1s;

wire       tx_24x64_done_pos;

    reg  [7:0] a;
    reg  [8:0] b;
    reg          [07:00]    cnt              ; //Counter 
    wire                    add_cnt          ; //Counter Enable
    wire                    end_cnt          ; //Counter Reset 
    reg          [08:00]    cnt_addr         ; //Counter 
    wire                    add_cnt_addr     ; //Counter Enable
    wire                    end_cnt_addr     ; //Counter Reset 
    reg          [05:00]    cnt_much         ; //Counter 
    wire                    add_cnt_much     ; //Counter Enable
    wire                    end_cnt_much     ; //Counter Reset 
    //状态空间定义
    parameter start             = 8'b0000_0001,
              model             = 8'b0000_0010,
              difficulty_one    = 8'b0000_0100,
              difficulty_two    = 8'b0000_1000,
              difficulty_thr    = 8'b0001_0000,
              play              = 8'b0010_0000,    
              game_win          = 8'b0100_0000,
              game_lose         = 8'b1000_0000;

    reg [7:0] state_c,state_n;

    wire      start2model                    ;  
    wire      model2difficulty_one           ;  
    wire      difficulty_one2difficulty_two  ;
    wire      difficulty_one2play            ; 
    wire      difficulty_two2difficulty_thr  ;
    wire      difficulty_two2play            ; 
    wire      difficulty_thr2difficulty_one  ;
    wire      difficulty_thr2play            ;  
    wire      play2game_win                  ;  
    wire      play2game_lose                 ; 
    wire      game_win2start                 ; 
    wire      game_lose2start                ; 

    reg       flag = 1'b1;
    reg [5:0] line_dis ;//跨行数
    reg [5:0] max_much ; 

    wire      reset_flag;//用于对切换界面的相关数据进行清零|| play2game_win ||play2game_lose
assign reset_flag = (start2model || model2difficulty_one || game_win2start || game_lose2start || play2game_win ||play2game_lose
                    || model2difficulty_one || difficulty_one2difficulty_two
                    || difficulty_two2difficulty_thr || difficulty_thr2difficulty_one);

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)begin
        state_c <= start;
    end
    else begin
        state_c <= state_n;
    end
end

always @(*) begin
    if(!sys_rst_n)begin
        state_n = start;
    end
    else begin
        case(state_c)
        start         : begin
            if(start2model)begin
                state_n = model;
            end
            else begin
                state_n = start;
            end
        end
        model         : begin
            if(model2difficulty_one)begin
                state_n = difficulty_one;
            end
            else begin
                state_n = model;
            end
        end
        difficulty_one: begin
            if(difficulty_one2difficulty_two)begin
                state_n = difficulty_two;
            end
            else if(difficulty_one2play)begin
                state_n = play;//测试 play
            end
            else begin
                state_n = difficulty_one;
            end
        end
        difficulty_two: begin
            if(difficulty_two2difficulty_thr)begin
                state_n = difficulty_thr;
            end
            else if(difficulty_two2play)begin
                state_n = play;//测试 play
            end
            else begin
                state_n = difficulty_two;
            end
        end
        difficulty_thr: begin
            if(difficulty_thr2difficulty_one)begin
                state_n = difficulty_one;
            end
            else if(difficulty_thr2play)begin
                state_n = play;//测试 play
            end
            else begin
                state_n = difficulty_thr;
            end
        end
        play          : begin
            if(play2game_win)begin
                state_n = game_win;
            end
            else if(play2game_lose)begin
                state_n = game_lose;
            end
            else begin
                state_n = play;
            end
        end
        game_win     : begin
            if(game_win2start)begin
                state_n = start;
            end
            else begin
                state_n = game_win;
            end
        end
        game_lose     : begin
            if(game_lose2start)begin
                state_n = start;
            end
            else begin
                state_n = game_lose;
            end
        end
        default: state_n = start;
        endcase
    end
end

wire end_cnt_8s;

assign start2model                   = state_c == start          && (^key_in);//开始状态下任意按键按下，跳转到模式选择界面
assign model2difficulty_one          = state_c == model          && (^key_in);//任意按键进入难度选择界面  测试进入win
assign difficulty_one2difficulty_two = state_c == difficulty_one && key_in[0];//静态显示1
assign difficulty_two2difficulty_thr = state_c == difficulty_two && key_in[0];//静态显示2
assign difficulty_thr2difficulty_one = state_c == difficulty_thr && key_in[0];//静态显示3
assign difficulty_one2play           = state_c == difficulty_one && key_in[1];//加速后的贪吃蛇
assign difficulty_two2play           = state_c == difficulty_two && key_in[1];// 添加路障后的贪吃蛇
assign difficulty_thr2play           = state_c == difficulty_thr && key_in[1];//加速、添加完路障后的游戏
assign play2game_win                 = state_c == play           && g_win;//游戏通关
assign play2game_lose                = state_c == play           && g_over ;//游戏失败
assign game_win2start                = state_c == game_win       && (^key_in);//end_cnt_8s;//结束界面维持八秒
assign game_lose2start               = state_c == game_lose      && (^key_in);//end_cnt_8s;//

//不同状态下的跨行距离
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)begin
        line_dis <= 6'd40;
    end
    else if(state_c == start || state_c == model)begin
        line_dis <= 6'd40;
    end
    else if(state_c == game_lose)begin//以失败结束游戏
        line_dis <= 6'd32;
    end
    else if(state_c == game_win)begin
        line_dis <= 6'd24;
    end
end

//不同状态下的可移动帧数
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)begin
        max_much <= 6'd33;
    end
    else if(state_c == start || state_c == model)begin
        max_much <= 6'd33;
    end
    else if(state_c == game_lose)begin//以失败结束游戏
        max_much <= 6'd25;
    end
    else if(state_c == game_win)begin
        max_much <= 6'd17;
    end
end

//不同状态下使能不同的rom信息
always @(*) begin
    if(!sys_rst_n)begin
        start_rden = 1'b1;
        model_rden = 1'b0;
        lose_rden  = 1'b0;
        win_rden   = 1'b0;
    end
    else if(state_c == start )begin
        start_rden = rden;
        model_rden = 1'b0;
        lose_rden  = 1'b0;
        win_rden   = 1'b0;
    end
    else if(state_c == model )begin
        model_rden = rden;
        start_rden = 1'b0;
        lose_rden  = 1'b0;
        win_rden   = 1'b0;
    end
    else if(state_c == game_lose )begin
        lose_rden = rden;
        start_rden = 1'b0;
        model_rden = 1'b0;
        win_rden   = 1'b0;
    end
    else if(state_c == game_win)begin
        win_rden = rden;
        start_rden = 1'b0;
        model_rden = 1'b0;
        lose_rden  = 1'b0;
    end
end



start start_inst(
	.address (address),
	.clock   (sys_clk),
	.rden    (start_rden),
	.q       (start_q)
);

win win_inst(
	.address    (address),
	.clock      (sys_clk),
	.rden       (win_rden),
	.q          (win_q)
);

lose lose_inst(
	.address (address),
	.clock   (sys_clk),
	.rden    (lose_rden),
	.q       (lose_q)
);
model model_inst(
	.address    (address),
	.clock      (sys_clk),
	.rden       (model_rden),
	.q          (model_q)
);
	
	
	
//先读取64
//读使能信号 reset_done
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)begin
        rden <= 1'b1;//上电就读
    end
    else if(state_c == play)begin
        rden <= 1'b0;
    end
    else if(reset_flag)begin//在界面切换时，先复位
        rden <= 1'b0;
    end
    else if(((cnt_1s == max_1s - 1)&&rden==1'b0) || (end_cnt && rden==1'b1))begin//复位结束开始读下一帧、读完一帧拉低等待复位&&rden==1'b0  && rden==1'b1
        rden <= ~rden;
    end
end


always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)begin
        cnt <= 8'd0;
    end
    // else if(reset_flag || high_1s)begin
        // cnt <= 8'd0;
    // end
    else if(add_cnt)begin//清零信号、一帧显示结束
        if(end_cnt)begin
            cnt <= 8'd0;
        end
        else begin
            cnt <= cnt + 1'b1;
        end
    end
    else begin
        cnt <= 8'd0;
    end
end
assign add_cnt = rden && (state_c == start || state_c == model || state_c == game_win || state_c == game_lose);
assign end_cnt = add_cnt && cnt == max -1 ;

//地址计数器
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)begin
        menu_address(0,0,0) ;
    end
    else if(rden)begin//读有效 给对应地址
        if(cnt<8)
            menu_address(0,cnt_much,cnt) ;
            // address <= cnt;
        else if(cnt>=8 && cnt <16)
            menu_address(1,cnt_much,cnt) ;
            // address <= (cnt - 8) + 40;
        else if(cnt >= 16 && cnt <24)
            menu_address(2,cnt_much,cnt) ;
            // address <= (cnt - 16) + 80;
        else if(cnt>=24 && cnt <32)
            menu_address(3,cnt_much,cnt) ;
            // address <= (cnt - 24) + 120;
        else if(cnt >= 32 && cnt <40)
            menu_address(4,cnt_much,cnt) ;
            // address <= (cnt - 32) + 160;
        else if(cnt >= 40 && cnt <48)
            menu_address(5,cnt_much,cnt) ;
            // address <= (cnt - 40) + 200;
        else if(cnt>=48 && cnt <56)
            menu_address(6,cnt_much,cnt) ;
            // address <= (cnt - 48) + 240;
        else if(cnt >= 56 && cnt <64)
            menu_address(7,cnt_much,cnt) ;
            // address <= (cnt - 56) + 280;
    end
    else begin
            menu_address(0,0,0) ;
    end
end

//task 地址计算
    task menu_address;   
        input       [3:0]       line         ;//所属行数
        input       [5:0]       much         ;//第几帧
        input       [7:0]       cnt          ;//位置     
        begin 
            a = line*8;
            b = line*line_dis;//跨行数
            address_r =  ((cnt - a) + b) + much; 
        end 
    endtask   
assign address = address_r;

//显示帧数计数器
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)begin
        cnt_much <= 6'd0;
    end
    else if(reset_flag)begin//在不同界面切换时，帧计数器应该清零
        cnt_much <= 6'd0;
    end
    else if(add_cnt_much)begin//清零信号、一帧显示结束
        if(end_cnt_much)begin
            cnt_much <= 6'd0;
        end
        else begin
            cnt_much <= cnt_much + 1'b1;
        end
    end
    else begin
        cnt_much <= cnt_much;
    end
end
assign add_cnt_much = end_cnt && (state_c == start || state_c == model || state_c == game_win || state_c == game_lose);
assign end_cnt_much = add_cnt_much && cnt_much == max_much - 1;

//assign reset_flag = (start2model || model2difficulty_one || play2game_win ||play2game_lose || game_win2start || game_lose2start);

always @(*) begin
    if(!sys_rst_n)begin
        q_r = 1'b0;
    end
    else if(state_c == start)begin
        q_r = start_q;
    end
    else if(state_c == model)begin
        q_r = model_q;
    end
    else if(state_c == game_lose)begin
        q_r = lose_q;
    end
    else if(state_c == game_win)begin
        q_r = win_q;
    end
    else begin
        q_r = 1'b0;
    end
end
//接收数据
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)begin
        data <= 64'd0;
    end
    else if(state_c == difficulty_one)begin
        data <= data_r1;
    end
    else if(state_c == difficulty_two)begin
        data <= data_r2;
    end
    else if(state_c == difficulty_thr)begin
        data <= data_r3;
    end
    else if(reset_flag)begin
        data <= 64'd0;
    end
    else if(rden)begin
        data[cnt-2] <= q_r;
    end
    else begin
        data <= data;
    end
end

//位置计数器
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)begin
        cnt_xy <= 8'd0;
    end
    else if(state_c == play)begin
        cnt_xy <= 8'd0;
    end
    // else if(reset_flag)begin
        // cnt_xy <= 8'd0;
    // end
    else if(cnt_1s == max_1s -1)begin//超过64重新来//cnt_xy >63 && 
        cnt_xy <= 8'd0;
    end
    else if(cnt_xy == 64)begin
        cnt_xy <= cnt_xy;
    end
    else if(tx_done_flag)begin//一组24位数据发送过后进行下一组
        cnt_xy <= cnt_xy + 1'b1;
    end
    else begin
        cnt_xy <= cnt_xy;
    end
end

// assign tx_24x64_done = ((cnt_xy > 63) || reset_flag) ? 1'b1 : ;

always @(*) begin
    if(!sys_rst_n)begin
        tx_24x64_done = 1'b0;
    end
    else if(cnt_1s == max_1s -1)begin
        tx_24x64_done = 1'b0;
    end
    else if((cnt_xy > 63) || reset_flag)begin
        tx_24x64_done = 1'b1;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)begin
        RGB_data <= 24'd0;
    end
    else if(state_c == play)begin
        RGB_data <= 24'd0;
    end
    else if(data[cnt_xy])begin//前面两行
        RGB_data <= GREEN;
    end
    else begin
        RGB_data <= 24'd0;//灭
    end
end


//计数器1s
//打两拍抓tx_24x64_done的上升沿用于开始1s计数
reg tx_24x64_done_r1,tx_24x64_done_r2;

//打拍
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)begin
        tx_24x64_done_r1 <= 1'b0;
        tx_24x64_done_r2 <= 1'b0;
    end
    else begin
        tx_24x64_done_r1 <= tx_24x64_done;
        tx_24x64_done_r2 <= tx_24x64_done_r1;
    end
end

assign tx_24x64_done_pos = ~tx_24x64_done_r2 && tx_24x64_done_r1; 

//根据tx_24x64_done的上升沿或1s的脉冲信号产生持续信号，用于计数
always @(*) begin
    if(!sys_rst_n)begin
        high_1s = 1'b0;
    end
    // else if(reset_flag)begin//加上后不滚动
        // high_1s = 1'b1;
    // end
    else if(tx_24x64_done_pos )begin
        high_1s = 1;
    end
    else if((cnt_1s == max_1s -1))begin
        high_1s = 0;
    end
    else begin
        high_1s = high_1s;
    end
end

//1s计数器，需要在24x64发送完后，计数1s再更新我们的cnt_xy进行写入新的界面
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)begin
        cnt_1s <= 26'd0;
    end
    else if(cnt_1s == max_1s - 1)begin
        cnt_1s <= 26'd0;
    end
    else if(high_1s)begin
        cnt_1s <= cnt_1s + 1'b1;
    end
    else begin
        cnt_1s <= 26'd0;
    end
end

assign difficulty = {difficulty_thr2play,difficulty_two2play,difficulty_one2play};//难度等级赋值
assign en_snake   = (difficulty_one2play || difficulty_two2play || difficulty_thr2play);//跳转到游戏界面使能模块工作

endmodule