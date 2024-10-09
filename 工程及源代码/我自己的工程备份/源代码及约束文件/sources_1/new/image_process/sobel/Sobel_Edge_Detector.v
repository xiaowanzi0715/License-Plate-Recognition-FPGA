module Sobel_Edge_Detector #(
    parameter  SOBEL_THRESHOLD = 250 // Sobel 算子的阈值，用于确定是否存在边缘
)(
    input       clk,             // CMOS 图像像素时钟
    input       rst_n,           // 复位信号，低电平有效
    // 图像处理前的输入信号
    input       per_frame_vsync, // 帧同步信号
    input       per_frame_href,  // 行同步信号
    input       per_frame_clken, // 数据时钟使能信号，指示数据有效
    input [7:0] per_img_y,       // 输入图像的灰度数据 (Y 分量)
    // 图像处理后的输出信号
    output      post_frame_vsync, // 输出的帧同步信号
    output      post_frame_href,  // 输出的行同步信号
    output      post_frame_clken, // 输出的时钟使能信号
    output      post_img_bit      // Sobel 边缘检测的结果，1 表示检测到边缘，0 表示非边缘
);

// 注册器定义，用于存储中间计算结果
reg [9:0]  gx_temp2; // 存储 Sobel 算子的 x 方向第三列值
reg [9:0]  gx_temp1; // 存储 Sobel 算子的 x 方向第一列值
reg [9:0]  gx_data;  // Sobel 算子的 x 方向的偏导数
reg [9:0]  gy_temp1; // 存储 Sobel 算子的 y 方向第一行值
reg [9:0]  gy_temp2; // 存储 Sobel 算子的 y 方向第三行值
reg [9:0]  gy_data;  // Sobel 算子的 y 方向的偏导数
reg [20:0] gxy_square; // x 和 y 方向偏导数平方和
reg [15:0] per_frame_vsync_r; // 延迟后的帧同步信号
reg [15:0] per_frame_href_r;  // 延迟后的行同步信号
reg [15:0] per_frame_clken_r; // 延迟后的时钟使能信号

// 信号定义
wire        matrix_frame_vsync;  // 3x3 矩阵的帧同步信号
wire        matrix_frame_href;   // 3x3 矩阵的行同步信号
wire        matrix_frame_clken;  // 3x3 矩阵的时钟使能信号
wire [10:0] dim;                 // 计算出的梯度模长
// 输出的 3x3 矩阵中的每个像素点
wire [7:0]  matrix_p11; 
wire [7:0]  matrix_p12; 
wire [7:0]  matrix_p13; 
wire [7:0]  matrix_p21; 
wire [7:0]  matrix_p22; 
wire [7:0]  matrix_p23;
wire [7:0]  matrix_p31; 
wire [7:0]  matrix_p32; 
wire [7:0]  matrix_p33;

//*****************************************************
//**                    主代码
//*****************************************************

// 分别为帧同步、行同步和时钟使能信号引入 10 拍延时，使信号与处理数据保持同步
assign post_frame_vsync = per_frame_vsync_r[10];
assign post_frame_href  = per_frame_href_r[10];
assign post_frame_clken = per_frame_clken_r[10];
assign post_img_bit     = post_frame_href ? post_img_bit_r : 1'b0; // 若行同步有效，输出边缘检测结果，否则输出 0

// 生成 3x3 矩阵
matrix_generate_3x3_8bit u_matrix_generate_3x3_8bit(
    .clk                 (clk),    // 像素时钟信号
    .rst_n               (rst_n),  // 复位信号
    // 输入的图像数据
    .per_frame_vsync     (per_frame_vsync),  // 帧同步信号
    .per_frame_href      (per_frame_href),   // 行同步信号
    .per_frame_clken     (per_frame_clken),  // 时钟使能信号
    .per_img_y           (per_img_y),        // 输入的灰度图像数据 (Y 分量)
    
    // 输出的 3x3 矩阵数据
    .matrix_frame_vsync  (matrix_frame_vsync), // 帧同步信号
    .matrix_frame_href   (matrix_frame_href),  // 行同步信号
    .matrix_frame_clken  (matrix_frame_clken), // 时钟使能信号
    .matrix_p11          (matrix_p11), // 矩阵左上角的像素点
    .matrix_p12          (matrix_p12), // 矩阵正中的上边像素点
    .matrix_p13          (matrix_p13), // 矩阵右上角的像素点
    .matrix_p21          (matrix_p21), // 矩阵左中的像素点
    .matrix_p22          (matrix_p22), // 矩阵正中的像素点
    .matrix_p23          (matrix_p23), // 矩阵右中的像素点
    .matrix_p31          (matrix_p31), // 矩阵左下角的像素点
    .matrix_p32          (matrix_p32), // 矩阵正下边的像素点
    .matrix_p33          (matrix_p33)  // 矩阵右下角的像素点
);

// Sobel 算子用于计算图像梯度
// gx 和 gy 为 Sobel 算子的两个核，用于计算图像的 x 方向和 y 方向的梯度

// Step 1 计算 y 方向的偏导数
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        gy_temp1 <= 10'd0;
        gy_temp2 <= 10'd0;
        gy_data <= 10'd0;
    end else begin
        // 计算 Sobel 算子的 y 方向值：gy_temp1 是第三列加权和，gy_temp2 是第一列加权和
        gy_temp1 <= matrix_p13 + (matrix_p23 << 1) + matrix_p33; 
        gy_temp2 <= matrix_p11 + (matrix_p21 << 1) + matrix_p31; 
        // 计算 y 方向偏导数 gy_data，取绝对值
        gy_data <= (gy_temp1 >= gy_temp2) ? gy_temp1 - gy_temp2 : gy_temp2 - gy_temp1;
    end
end

// Step 2 计算 x 方向的偏导数
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        gx_temp1 <= 10'd0;
        gx_temp2 <= 10'd0;
        gx_data <= 10'd0;
    end else begin
        // 计算 Sobel 算子的 x 方向值：gx_temp1 是第一行加权和，gx_temp2 是第三行加权和
        gx_temp1 <= matrix_p11 + (matrix_p12 << 1) + matrix_p13; 
        gx_temp2 <= matrix_p31 + (matrix_p32 << 1) + matrix_p33; 
        // 计算 x 方向偏导数 gx_data，取绝对值
        gx_data <= (gx_temp1 >= gx_temp2) ? gx_temp1 - gx_temp2 : gx_temp2 - gx_temp1;
    end
end

// Step 3 计算 x 和 y 方向偏导数的平方和
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        gxy_square <= 21'd0;
    else
        // 计算 gx 和 gy 的平方和
        gxy_square <= gx_data * gx_data + gy_data * gy_data;
end

// Step 4 计算平方根（梯度向量的模长）
cordic u_cordic(
    .aclk                   (clk),                 // 时钟信号
    .s_axis_cartesian_tvalid (1'b1),               // 输入有效信号
    .s_axis_cartesian_tdata  (gxy_square),         // 输入平方和数据
    .m_axis_dout_tvalid      (),                   // 输出有效信号（未使用）
    .m_axis_dout_tdata       (dim)                 // 输出平方根值，即梯度的模长
);

// Step 5 将梯度模长与预设阈值进行比较，确定是否为边缘
reg post_img_bit_r;
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        post_img_bit_r <= 1'b0; // 初始值
    else if(dim >= SOBEL_THRESHOLD)
        post_img_bit_r <= 1'b1; // 梯度模长大于阈值，认为是边缘
    else
        post_img_bit_r <= 1'b0; // 梯度模长小于阈值，认为不是边缘
end

// 延迟 5 个时钟周期同步输入信号
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        per_frame_vsync_r <= 0; // 初始化帧同步信号寄存器
        per_frame_href_r  <= 0; // 初始化行同步信号寄存器
        per_frame_clken_r <= 0; // 初始化时钟使能信号寄存器
    end
    else begin
        // 向右移动信号位，延迟 5 个周期，确保信号与处理后的数据同步
        per_frame_vsync_r  <= {per_frame_vsync_r[14:0], matrix_frame_vsync};
        per_frame_href_r   <= {per_frame_href_r[14:0], matrix_frame_href};
        per_frame_clken_r  <= {per_frame_clken_r[14:0], matrix_frame_clken};
    end
end

endmodule
