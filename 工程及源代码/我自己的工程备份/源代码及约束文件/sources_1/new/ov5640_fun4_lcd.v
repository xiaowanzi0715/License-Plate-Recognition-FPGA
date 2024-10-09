module ov5640_fun4_lcd(    	
    input                 sys_clk      ,  // 系统时钟
    input                 sys_rst_n    ,  // 系统复位信号，低电平有效
    // 摄像头接口 
    input                 cam_pclk     ,  // CMOS数据像素时钟
    input                 cam_vsync    ,  // CMOS场同步信号
    input                 cam_href     ,  // CMOS行同步信号
    input   [7:0]         cam_data     ,  // CMOS数据
    output                cam_rst_n    ,  // CMOS复位信号，低电平有效
    output                cam_pwdn ,      // 电源休眠模式选择，0: 正常模式，1: 电源休眠模式
    output                cam_scl      ,  // CMOS的SCCB时钟线
    inout                 cam_sda      ,  // CMOS的SCCB数据线      
    // DDR3接口 
    inout   [31:0]        ddr3_dq      ,  // DDR3数据
    inout   [3:0]         ddr3_dqs_n   ,  // DDR3 DQS负信号
    inout   [3:0]         ddr3_dqs_p   ,  // DDR3 DQS正信号
    output  [13:0]        ddr3_addr    ,  // DDR3地址总线
    output  [2:0]         ddr3_ba      ,  // DDR3 bank选择
    output                ddr3_ras_n   ,  // DDR3行选信号
    output                ddr3_cas_n   ,  // DDR3列选信号
    output                ddr3_we_n    ,  // DDR3写使能
    output                ddr3_reset_n ,  // DDR3复位信号
    output  [0:0]         ddr3_ck_p    ,  // DDR3时钟正
    output  [0:0]         ddr3_ck_n    ,  // DDR3时钟负
    output  [0:0]         ddr3_cke     ,  // DDR3时钟使能
    output  [0:0]         ddr3_cs_n    ,  // DDR3片选信号
    output  [3:0]         ddr3_dm      ,  // DDR3数据掩码
    output  [0:0]         ddr3_odt     ,  // DDR3终端匹配信号
    // LCD接口
    output                lcd_hs       ,  // LCD行同步信号
    output                lcd_vs       ,  // LCD场同步信号
    output                lcd_de       ,  // LCD数据输入使能
    inout       [23:0]    lcd_rgb      ,  // LCD颜色数据
    output                lcd_bl       ,  // LCD背光控制信号
    output                lcd_rst      ,  // LCD复位信号
    output                lcd_pclk        // LCD采样时钟	
    );                                
									   							   
// wire信号定义
wire         clk_50m                   ;  // 50MHz时钟，提供给LCD驱动
wire         locked                    ;  // 时钟锁定信号
wire         rst_n                     ;  // 全局复位信号
wire         wr_en                     ;  // DDR3控制模块写使能
wire  [15:0] wr_data                   ;  // DDR3控制模块写数据
wire         rdata_req                 ;  // DDR3控制模块读使能
wire  [15:0] rd_data                   ;  // DDR3控制模块读数据
wire         cmos_frame_valid          ;  // 数据有效使能信号
wire         init_calib_complete       ;  // DDR3初始化完成信号
wire         sys_init_done             ;  // 系统初始化完成（包括DDR和摄像头）
wire         clk_200m                  ;  // DDR3参考时钟
wire         cmos_frame_vsync          ;  // 输出帧同步信号
wire         cmos_frame_href           ;  // 输出行同步信号 
wire  [12:0] h_disp                    ;  // LCD水平分辨率
wire  [12:0] v_disp                    ;  // LCD垂直分辨率
wire  [10:0] h_pixel                   ;  // 存入DDR3的水平分辨率        
wire  [10:0] v_pixel                   ;  // 存入DDR3的垂直分辨率
wire  [27:0] ddr3_addr_max             ;  // 存入DDR3的最大读写地址
wire  [12:0] total_h_pixel             ;  // 水平总像素大小
wire  [12:0] total_v_pixel             ;  // 垂直总像素大小
wire  [10:0] pixel_xpos_w              ;  // 当前像素的水平位置
wire  [10:0] pixel_ypos_w              ;  // 当前像素的垂直位置
wire         post_frame_vsync          ;  // 处理后帧同步信号
wire         post_frame_hsync          ;  // 处理后行同步信号
wire         post_frame_de             ;  // 处理后数据输入使能
wire  [15:0] post_rgb                  ;  // 处理后的RGB数据
wire  [15:0] lcd_id                    ;  // LCD的ID号

//*****************************************************
//**                    主体代码
//*****************************************************
// 在时钟锁定后产生复位信号
assign  rst_n = sys_rst_n & locked;

// 系统初始化完成：DDR3初始化完成
assign  sys_init_done = init_calib_complete;

// 摄像头图像分辨率设置模块
picture_size u_picture_size (
    .rst_n              (rst_n),
    .clk                (clk_50m),    
    .ID_lcd             (lcd_id),           // LCD屏幕ID
    .cmos_h_pixel       (h_disp),           // 摄像头水平分辨率
    .cmos_v_pixel       (v_disp),           // 摄像头垂直分辨率  
    .total_h_pixel      (total_h_pixel),    // 水平总像素
    .total_v_pixel      (total_v_pixel),    // 垂直总像素
    .sdram_max_addr     (ddr3_addr_max)     // DDR3最大读写地址
);

// OV5640摄像头驱动模块
ov5640_dri u_ov5640_dri(
    .clk               (clk_50m),
    .rst_n             (rst_n),
    .cam_pclk          (cam_pclk),
    .cam_vsync         (cam_vsync),
    .cam_href          (cam_href),
    .cam_data          (cam_data),
    .cam_rst_n         (cam_rst_n),
    .cam_pwdn          (cam_pwdn),
    .cam_scl           (cam_scl),
    .cam_sda           (cam_sda),
    .capture_start     (init_calib_complete),  // 开始捕捉图像
    .cmos_h_pixel      (h_disp),
    .cmos_v_pixel      (v_disp),
    .total_h_pixel     (total_h_pixel),
    .total_v_pixel     (total_v_pixel),
    .cmos_frame_vsync  (cmos_frame_vsync),
    .cmos_frame_href   (cmos_frame_href),
    .cmos_frame_valid  (cmos_frame_valid),
    .cmos_frame_data   (wr_data)             // 写入的数据
);

// 图像处理模块
image_process u_image_process(
    .clk              (cam_pclk),             // 时钟信号
    .rst_n            (rst_n),                // 复位信号（低有效）
    // 图像处理前的数据接口
    .pre_frame_vsync  (cmos_frame_vsync),
    .pre_frame_hsync  (cmos_frame_href),
    .pre_frame_de     (cmos_frame_valid),
    .pre_rgb          (wr_data),
    .xpos             (pixel_xpos_w),         // 当前像素的水平位置
    .ypos             (pixel_ypos_w),         // 当前像素的垂直位置
    // 图像处理后的数据接口
    .post_frame_vsync (post_frame_vsync),     // 处理后场同步信号
    .post_frame_hsync (post_frame_href),      // 处理后行同步信号
    .post_frame_de    (post_frame_de),        // 处理后数据输入使能
    .post_rgb         (post_rgb)              // 处理后RGB数据
);

// DDR3控制模块
ddr3_top u_ddr3_top (
    .clk_200m              (clk_200m),            // 系统时钟
    .sys_rst_n             (rst_n),               // 复位，低有效
    .sys_init_done         (sys_init_done),       // 系统初始化完成
    .init_calib_complete   (init_calib_complete), // DDR3初始化完成
    // DDR3接口信号
    .app_addr_rd_min       (28'd0),                 // 读DDR3的起始地址
    .app_addr_rd_max       (ddr3_addr_max[27:1]),   // 读DDR3的结束地址
    .rd_bust_len           (h_disp[10:4]),          // 从DDR3中读数据时的突发长度
    .app_addr_wr_min       (28'd0),                 // 写DDR3的起始地址
    .app_addr_wr_max       (ddr3_addr_max[27:1]),   // 写DDR3的结束地址
    .wr_bust_len           (h_disp[10:4]),          // 从DDR3中写数据时的突发长度
    // DDR3 IO接口
    .ddr3_dq               (ddr3_dq),               // DDR3数据
    .ddr3_dqs_n            (ddr3_dqs_n),            // DDR3 DQS负信号
    .ddr3_dqs_p            (ddr3_dqs_p),            // DDR3 DQS正信号
    .ddr3_addr             (ddr3_addr),             // DDR3地址总线
    .ddr3_ba               (ddr3_ba),               // DDR3 bank选择
    .ddr3_ras_n            (ddr3_ras_n),            // DDR3行选信号
    .ddr3_cas_n            (ddr3_cas_n),            // DDR3列选信号
    .ddr3_we_n             (ddr3_we_n),             // DDR3写使能信号
    .ddr3_reset_n          (ddr3_reset_n),          // DDR3复位信号
    .ddr3_ck_p             (ddr3_ck_p),             // DDR3时钟正信号
    .ddr3_ck_n             (ddr3_ck_n),             // DDR3时钟负信号
    .ddr3_cke              (ddr3_cke),              // DDR3时钟使能信号
    .ddr3_cs_n             (ddr3_cs_n),             // DDR3片选信号
    .ddr3_dm               (ddr3_dm),               // DDR3数据掩码
    .ddr3_odt              (ddr3_odt),              // DDR3终端匹配信号
    // 用户接口
    .ddr3_read_valid       (1'b1),                  // DDR3读使能
    .ddr3_pingpang_en      (1'b1),                  // DDR3乒乓操作使能
    .wr_clk                (cam_pclk),              // 写时钟（与摄像头像素时钟同步）
    .wr_load               (post_frame_vsync),      // 写入源更新信号
    .datain_valid          (post_frame_de),         // 数据有效使能信号
    .datain                (post_rgb),              // 写入的数据
    .rd_clk                (lcd_clk),               // 读时钟（与LCD时钟同步）
    .rd_load               (rd_vsync),              // 输出源更新信号
    .dataout               (rd_data),               // DDR3读出的数据
    .rdata_req             (rdata_req)              // 请求数据输入信号
);  

// 时钟管理模块：生成50MHz和200MHz时钟
clk_wiz_0 u_clk_wiz_0 (
    // Clock out ports
    .clk_out1              (clk_200m),     // 200MHz时钟输出
    .clk_out2              (clk_50m),      // 50MHz时钟输出
    // Status and control signals
    .reset                 (1'b0),         // 复位信号
    .locked                (locked),       // 时钟锁定信号
    // Clock in ports
    .clk_in1               (sys_clk)       // 输入时钟
);     

// LCD驱动显示模块
lcd_rgb_top  u_lcd_rgb_top (
    .sys_clk               (clk_50m),            // 系统时钟
    .sys_rst_n             (rst_n),              // 系统复位信号
    .sys_init_done         (sys_init_done),      // 系统初始化完成
    // LCD接口信号
    .lcd_id                (lcd_id),             // LCD屏的ID号
    .lcd_hs                (lcd_hs),             // LCD行同步信号
    .lcd_vs                (lcd_vs),             // LCD场同步信号
    .lcd_de                (lcd_de),             // LCD数据输入使能
    .lcd_rgb               (lcd_rgb),            // LCD RGB颜色数据
    .lcd_bl                (lcd_bl),             // LCD背光控制信号
    .lcd_rst               (lcd_rst),            // LCD复位信号
    .lcd_pclk              (lcd_pclk),           // LCD采样时钟
    .lcd_clk               (lcd_clk),            // LCD驱动时钟
    // 用户接口信号
    .out_vsync             (rd_vsync),           // LCD场同步信号
    .h_disp                (),                   // 水平分辨率（未连接）
    .v_disp                (),                   // 垂直分辨率（未连接）
    .pixel_xpos            (pixel_xpos_w),       // 当前像素的水平位置
    .pixel_ypos            (pixel_ypos_w),       // 当前像素的垂直位置
    .data_in               (rd_data),            // DDR3读取的数据
    .data_req              (rdata_req)           // 请求数据输入信号
);   

endmodule
