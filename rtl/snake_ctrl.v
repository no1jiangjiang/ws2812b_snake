module snake_ctrl (
    input                   sys_clk                 ,//系统时钟
    input                   sys_rst_n               ,//系统复位
    input                   tx_done_flag            ,//24bit的像素点发送完毕
    input        [2:0]      difficulty              ,//难度系数 
    input        [1:0]      key_flag                ,//按键标志信号

    output                  game_over               ,//游戏失败、跳出lose界面
    output                  game_win                ,//游戏失败、跳出win界面
    output  reg  [23:0]     RGB_data                ,//24位像素数据
    output                  tx_24x64_done            //一帧数据传输结束、需要复位
);

/*********************彩带显示**********************/
//8种颜色数据
parameter WHITE = 24'b00001111_00001111_00001111;  //白色
parameter RED   = 24'b00001111_00000000_00000000;  //红色
parameter GREEN = 24'b00000000_00001111_00000000;  //绿色
parameter BLUE  = 24'b00000000_00000000_00001111;  //蓝色_xy == 47 || snake_xy_r1 == 5xy == 40 || snake_xy_r1 == 48== 5 || snake_xy_r1 == 6 || se_xy == 61 || snake_xy_r1 ==
parameter YELLOW    = 24'b00000000_00001111_00001111;  //黄色
//状态
    parameter IDLE      = 7'b000_0001,
              Rright    = 7'b000_0010,    
              Left      = 7'b000_0100,
              Up        = 7'b000_1000,
              Down      = 7'b001_0000,
              Win       = 7'b010_0000,
              Lose      = 7'b100_0000;

    wire      IDLE2Rright ;       
    wire      Rright2Up   ;   
    wire      Rright2Down ;       
    wire      Rright2Win  ;   
    wire      Rright2Lose ;   
    wire      Left2Up     ;   
    wire      Left2Down   ;   
    wire      Left2Win    ;    
    wire      Left2Lose   ;   
    wire      Up2Rright   ;   
    wire      Up2Left     ;       
    wire      Up2Win      ;       
    wire      Up2Lose     ;   
    wire      Down2Rright ;           
    wire      Down2Left   ;       
    wire      Down2Win    ;       
    wire      Down2Lose   ;       
    wire      Win2IDLE    ;       
    wire      Lose2IDLE   ;   
    wire      right_b     ;
    wire      left_b      ;
    wire      up_b        ;
    wire      down_b      ;    

    reg [6:0] state_c,state_n;

    reg [6:0]  cnt_xy;
    reg [63:0] char_r= 64'b0000000000000000000000000000000000000000000001000000000000000000;//含障碍物的界面
    reg [63:0] char_r2 = 64'b0000000001000010000000000000000000000000000001100000011000000000;//有障碍
    reg [63:0] char_r3 = 64'd0;//无障碍
    reg [6:0] snake [9:0];//8个长度的蛇的位置
    reg [6:0] snake_xy;//蛇头的位置
    reg [6:0] snake_xy_r1;//慢两拍的蛇头的位置
    reg [6:0] snake_xy_r2;//慢两拍的蛇头的位置
    reg [6:0] snake_xy_r3;//慢两拍的蛇头的位置
    reg [6:0] snake_xy_r4;//慢两拍的蛇头的位置
    reg [6:0] apple_xy;//苹果的位置
    reg [4:0] snake_length = 5'd2;
    reg high_1s;

    reg [25:0] cnt_1s;
    integer k;
    wire tx_24x64_done_pos;
    reg [25:0] max_1s ;//= 20_000_000;//25000000 慢速   15_000_000 快速
    //wire game_over ;//游戏失败信号
    reg  game_over_r;//游戏失败寄存信号
    wire snake_flag;
    wire [6:0]snake_c;
    wire [6:0]snake_n;
    wire eat_apple;//吃苹果、苹果的位置与蛇头一样  这时蛇体应该加长、旧的苹果清掉、随机产生新苹果
    reg          [07:00]    cnt_apple          ; //Counter 
    wire                    add_cnt_apple      ; //Counter Enable
    wire                    end_cnt_apple      ; //Counter Reset 
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n)begin
            state_c <= IDLE;
        end
        else begin
            state_c <= state_n;
        end
    end

    always @(*) begin
        if(!sys_rst_n)begin
            state_n = IDLE;
        end
        else begin
            case(state_c)
            IDLE  : begin
                if(IDLE2Rright)begin
                    state_n = Rright;
                end
                else begin
                    state_n = IDLE;
                end
            end
            Rright: begin
                if(Rright2Win)begin//赢
                    state_n = Win;
                end
                else if(Rright2Lose)begin
                    state_n = Lose;
                end
                else if(Rright2Down)begin
                    state_n = Down;
                end
                else if(Rright2Up)begin
                    state_n = Up;
                end
                else begin
                    state_n = Rright;
                end 
            end
            Left  : begin
                if(Left2Win)begin//赢
                    state_n = Win;
                end
                else if(Left2Lose)begin
                    state_n = Lose;
                end
                else if(Left2Down)begin
                    state_n = Down;
                end
                else if(Left2Up)begin
                    state_n = Up;
                end
                else begin
                    state_n = Left;
                end 
            end
            Up    : begin
                if(Up2Win)begin//赢
                    state_n = Win;
                end
                else if(Up2Lose)begin
                    state_n = Lose;
                end
                else if(Up2Rright)begin
                    state_n = Rright;
                end
                else if(Up2Left)begin
                    state_n = Left;
                end
                else begin
                    state_n = Up;
                end 
            end
            Down  : begin
                if(Down2Win)begin//赢
                    state_n = Win;
                end
                else if(Down2Lose)begin
                    state_n = Lose;
                end
                else if(Down2Rright)begin
                    state_n = Rright;
                end
                else if(Down2Left)begin
                    state_n = Left;
                end
                else begin
                    state_n = Down;
                end 
            end
            Win   : begin
                state_n = IDLE;
            end
            Lose  : begin
                state_n = IDLE;
            end
            default : state_n = IDLE;
            endcase
        end
    end

    assign IDLE2Rright = state_c == IDLE       &&  (^difficulty);//key_flag[0];//空闲状态且按键1按下 模拟使能信号
    assign Rright2Up   = state_c == Rright     &&  key_flag[1];
    assign Rright2Down = state_c == Rright     &&  key_flag[0];
    assign Rright2Win  = state_c == Rright     &&  (snake_length > 5'd8);//长度大于8通关  吃了8个
    assign Rright2Lose = state_c == Rright     &&  (game_over);//撞到墙或者障碍物
    assign Left2Up     = state_c == Left       &&  key_flag[0];
    assign Left2Down   = state_c == Left       &&  key_flag[1];
    assign Left2Win    = state_c == Left       &&  (snake_length > 5'd8);//长度大于8通关 
    assign Left2Lose   = state_c == Left       &&  (game_over);//撞到墙或者障碍物
    assign Up2Rright   = state_c == Up         &&  key_flag[0]; 
    assign Up2Left     = state_c == Up         &&  key_flag[1]; 
    assign Up2Win      = state_c == Up         &&  (snake_length > 5'd8);//长度大于8通关  
    assign Up2Lose     = state_c == Up         &&  (game_over);//撞到墙或者障碍物 
    assign Down2Rright = state_c == Down       &&  key_flag[0];
    assign Down2Left   = state_c == Down       &&  key_flag[1];
    assign Down2Win    = state_c == Down       &&  (snake_length > 5'd8);//长度大于8通关 
    assign Down2Lose   = state_c == Down       &&  (game_over);//撞到墙或者障碍物
    assign Win2IDLE    = state_c == Win        &&  1'b1;
    assign Lose2IDLE   = state_c == Lose       &&  1'b1;        

    //只有在工作状态更新显示的数据最后处理

    //不同的工作状态蛇头移动的步长不同
    //帧切换时，一直加1模拟向右移动  蛇头模拟    应该是逻辑判断的优先级问题
    always @(posedge sys_clk or negedge sys_rst_n) begin//posedge sys_clk or negedge sys_rst_n
        if(!sys_rst_n)begin
            snake_xy <= 7'd19;
            game_over_r <= 1'b0;
        end
        else if(IDLE2Rright)begin//启动时清零
                snake_xy <= 7'd19;
				game_over_r <= 1'b0;
        end
        else if(Rright2Down)
                snake_xy <= snake_xy + 7'd7;
        else if(Rright2Up)//测试
                snake_xy <= snake_xy - 7'd9;
        else if(Left2Down)//这里有小问题、等会测试 再测下下面的情况 这里有问题
            snake_xy <= snake_xy + 7'd9;// + 7'd6;
        else if(Left2Up)
            snake_xy <= snake_xy - 7'd7;
        else if(Up2Rright)
            snake_xy <= snake_xy + 7'd9;// + 7'd1; 
        else if(Up2Left)
            snake_xy <= snake_xy + 7'd7;// - 7'd1;
        else if(Down2Rright)
            snake_xy <= snake_xy - 7'd7;
        else if(Down2Left)
            snake_xy <= snake_xy - 7'd9;//测试
        else if(state_c == Left)begin
            if(tx_24x64_done_pos)
                if(left_b)//处在左边界，下一帧还要走就结束游戏 不掉头才会死
                    game_over_r <= 1'b1;//游戏失败
                else
                    snake_xy <= snake_xy - 1'b1;
        end
        else if(state_c == Rright)begin
            if(tx_24x64_done_pos)
                if(right_b)//处在左边界，下一帧还要走就结束游戏
                    game_over_r <= 1'b1;//游戏失败
                else
                    snake_xy <= snake_xy + 1'b1;
        end
        else if(state_c == Up)begin
            if(tx_24x64_done_pos)
                if(up_b)//处在左边界，下一帧还要走就结束游戏
                    game_over_r <= 1'b1;//游戏失败
                else
                    snake_xy <= snake_xy - 7'd8;
        end
        else if(state_c == Down)begin
            if(tx_24x64_done_pos)
                if(down_b)
                    game_over_r <= 1'b1;//游戏失败
                else begin
                    snake_xy <= snake_xy + 7'd8;
                end
        end
        else begin
            game_over_r <= 1'b0;
            snake_xy  <= 7'd19;
        end
    end

    //慢两拍的蛇头
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n)begin
            snake_xy_r1 <= 7'd19;
            snake_xy_r2 <= 7'd19;
            snake_xy_r3 <= 7'd19;
        end
        else if(state_c == Up || state_c == Down || state_c == Left || state_c == Rright)begin//正常运行下，才寄存否则为初始化位置
            if(tx_24x64_done_pos)begin
                snake_xy_r1 <= snake_xy;
                snake_xy_r2 <= snake_xy_r1;
                snake_xy_r3 <= snake_xy_r2;
            end
        end
        else begin
            snake_xy_r1 <= 7'd19;
            snake_xy_r2 <= 7'd19;
            snake_xy_r3 <= 7'd19;
        end
    end

    assign right_b =   (snake_xy_r1 == 7 || snake_xy_r1 == 15 || snake_xy_r1 == 23 || snake_xy_r1 == 31 || snake_xy_r1 == 39 || snake_xy_r1 == 47 || snake_xy_r1 == 55 || snake_xy_r1 == 63)  ;//当前蛇头处于右边界
    assign left_b  =   (snake_xy_r1 == 0 || snake_xy_r1 == 8 || snake_xy_r1 == 16 || snake_xy_r1 == 24 || snake_xy_r1 == 32 || snake_xy_r1 == 40 || snake_xy_r1 == 48 || snake_xy_r1 == 56)  ;//当前蛇头处于左边界
    assign up_b     =  (snake_xy_r1 == 0 || snake_xy_r1 == 1 || snake_xy_r1 == 2 || snake_xy_r1 == 3 || snake_xy_r1 == 4 || snake_xy_r1 == 5 || snake_xy_r1 == 6 || snake_xy_r1 == 7)     ;//当前蛇头处于上边界
    assign down_b   =  (snake_xy_r1 == 56 || snake_xy_r1 == 57 || snake_xy_r1 == 58 || snake_xy_r1 == 59 || snake_xy_r1 == 60 || snake_xy_r1 == 61 || snake_xy_r1 == 62 || snake_xy_r1 == 63)  ;//当前蛇头处于下边界

    //打两拍抓tx_24x64_done的上升沿用于开始1s计数
    reg tx_24x64_done_r1,tx_24x64_done_r2;

    //计数苹果的位置，随机产生苹果
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n)begin
            cnt_apple <= 8'd0;
        end
        else if(add_cnt_apple)begin
            if(end_cnt_apple)begin
                cnt_apple <= 8'd0;
            end
            else begin
                cnt_apple <= cnt_apple + 1'b1;
            end
        end
        else begin
            cnt_apple <= 8'd0;
        end
    end
    assign add_cnt_apple = 1'b1;
    assign end_cnt_apple = add_cnt_apple && cnt_apple == 8'd63;

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n)begin
            apple_xy <= 7'd27;
        end
        else if(eat_apple)begin//吃的操作成功后对新苹果位置进行更新，还需对旧苹果位置进行清除、在数据处理模块进行即可
            if(char_r2[cnt_apple])begin//与障碍物重合
                apple_xy <= cnt_apple + 2;
            end
            else begin
                apple_xy <= cnt_apple;
            end
        end
    end
    
    //更新蛇的长度
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n)begin
            snake_length <= 5'd1;
        end
        else if(IDLE2Rright)begin
            snake_length <= 5'd1;
        end
        else if(eat_apple)begin//吃苹果后加1，其余保持不变
            snake_length <= snake_length + 1'b1;
        end
    end

    assign eat_apple = snake_xy_r1 == apple_xy;

    //对需要显示的数据赋值置1
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n)begin//复位时候是18、19蛇身位置、直接给亮18、19
            char_r <= 64'd0;
        end
        else if(state_c == IDLE || state_c == Win || state_c == Lose)
            char_r <= 64'd0;//1
        else if(IDLE2Rright)
            char_r <= 64'b0000000000000000000000000000000000001000000010000000000000000000;
        else if(tx_24x64_done_pos)begin//这时候已经蛇身的位置更新完毕 tx_24x64_done_pos(这时候char慢了)cnt_xy == 63
            char_r <= 64'd0;
            for(k=0;k<=7;k=k+1)begin//判断蛇身数组值不为100
                if(k < snake_length)begin
                    if(k==0)
                        char_r[snake_xy] <= 1'b1; 
    				else
                    char_r[snake[k-1]] <= 1'b1;
                end
            end
            char_r[apple_xy] = 1'b1;//苹果位置
        end
    end
    //更新蛇的标志
    assign snake_flag = cnt_1s == (max_1s>>2);
    assign snake_c = snake[1];
    assign snake_n = snake[0];

    // integer k;
    //初始化蛇身的位置、界面刷新就移动
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n)begin
            for(k=0;k<=7;k=k+1)
                if(k==0)
                    snake[k] <= 19;//测试 设为0 19
                else 
                    snake[k] <= 100;//位置为100表示不需要亮
        end
        else if(IDLE2Rright)begin
            for(k=0;k<=7;k=k+1)
                if(k==0)
                    snake[k] <= 19;
                else 
                    snake[k] <= 100;//位置为100表示不需要亮
        end
        else if(tx_24x64_done_pos)begin//其余情况下蛇身的位置对蛇头的位置进行打拍寄存  这里只是位置
                    snake[0] <= snake_xy;
                    snake[1] <= snake[0];
                    snake[2] <= snake[1];
                    snake[3] <= snake[2];
                    snake[4] <= snake[3];
                    snake[5] <= snake[4];
                    snake[6] <= snake[5];
        end
    end

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
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n)begin
            high_1s <= 1'b0;
        end
        else if(tx_24x64_done_pos || (cnt_1s == max_1s -1))begin
            high_1s <= ~high_1s;
        end
        else begin
            high_1s <= high_1s;
        end
    end

    //1s计数器，需要在24x64发送完后，计数1s再更新我们的cnt_xy进行写入新的界面
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n )begin
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

    //位置计数器
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n)begin
            cnt_xy <= 7'd0;
        end
        else if(IDLE2Rright || state_c == IDLE)begin
            cnt_xy <= 7'd0;
        end
        else if(high_1s && cnt_1s == max_1s -1)begin//超过64重新来、一秒切换
            cnt_xy <= 7'd0;
        end
        else if(high_1s)begin//超过64重新来 cnt_xy >63
            cnt_xy <= cnt_xy;
        end
        else if(tx_done_flag)begin//一组24位数据发送过后进行下一组
            cnt_xy <= cnt_xy + 1'b1;
        end
        else begin
            cnt_xy <= cnt_xy;
        end
    end

    //根据不同的状态显示不同的内容  //1代表障碍物 蓝色、2代表苹果 红色 、3代表蛇身 绿色 0表示无
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n)begin
            RGB_data <= 24'd0;
        end
        else if(state_c == IDLE)begin
            RGB_data <= 24'd0;
        end
        else if(IDLE2Rright)begin
           RGB_data <= 24'd0;
        end
        else if(cnt_xy == snake_xy_r1)begin//蛇头给黄色 测试
            RGB_data <= YELLOW;
        end
        else if(char_r2[cnt_xy]) begin
            RGB_data <= RED;
        end
        else if(char_r[cnt_xy] == 2'd1)begin//前面两行
            if(cnt_xy!=apple_xy)
                RGB_data <= BLUE;
            else
                RGB_data <= GREEN;
        end
        else begin
            RGB_data <= 24'd0;//灭
        end
    end

    assign tx_24x64_done = (cnt_xy > 63) || IDLE2Rright || eat_apple || (Rright2Down || Up2Left || Up2Rright || Rright2Up || Left2Down || Left2Up || Down2Left || Down2Rright);//( state_c != state_n);//|| flag || (!sys_rst_n);//在写入一页后需要更新界面需要复位，在吃到后需要复位
    assign game_over = game_over_r || (char_r2[snake_xy_r1]) || (tx_24x64_done_pos && ( snake_xy_r1 == snake[3] || snake_xy_r1 == snake[4] || snake_xy_r1 == snake[5] || snake_xy_r1 == snake[6]));////边界、障碍物、自身缠绕
    assign game_win  = snake_length > 5'd8;


     
    //速度切换代码
   // max_1s
    always @(posedge sys_clk or negedge sys_rst_n) begin//35000000 慢速   20_000_000 快速
        if(!sys_rst_n)begin
            max_1s <= 35_000_000;
        end
        else if(difficulty[0] || difficulty[2])begin
            max_1s <= 20_000_000;
        end
        else begin
            max_1s <= max_1s;
        end
    end

    //障碍
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n)begin//复位默认有障碍
            char_r2 <= 64'b0000000001000010000000000000000000000000000001100000011000000000;
        end
        else if(difficulty[0])begin//模式一无障碍
            char_r2 <= 64'd0;
        end
        else begin
            char_r2 <= char_r2;
        end
    end

endmodule