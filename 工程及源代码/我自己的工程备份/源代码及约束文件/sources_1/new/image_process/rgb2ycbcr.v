//****************************************Copyright (c)***********************************//
//技术支持：www.openedv.com
//淘宝店铺：http://openedv.taobao.com
//关注微信公众平台微信号："正点原子"，免费获取FPGA & STM32资料。
//版权所有，盗版必究。
//Copyright(C) 正点原子 2018-2028
//All rights reserved
//----------------------------------------------------------------------------------------
// File name:           rgb2ycbcr
// Last modified Date:  2019/03/05 14:05:00
// Last Version:        V1.0
// Descriptions:        RGB转YCbCr
//----------------------------------------------------------------------------------------
// Created by:          正点原子
// Created date:        2019/03/05 14:05:34
// Version:             V1.0
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

//模块名: rgb2ycbcr
//功能: 将 RGB 图像转换为 YCbCr 图像格式
module rgb2ycbcr (
    // module clock
    input               clk             ,   // 时钟信号
    input               rst_n           ,   // 复位信号，低电平有效

    // 图像处理前的数据接口
    input               pre_frame_vsync ,   // 场同步信号 (Vsync)
    input               pre_frame_hsync ,   // 行同步信号 (Hsync)
    input               pre_frame_de    ,   // 数据有效信号 (Data Enable)
    input       [4:0]   img_red         ,   // 输入图像的 R 分量（5 位宽）
    input       [5:0]   img_green       ,   // 输入图像的 G 分量（6 位宽）
    input       [4:0]   img_blue        ,   // 输入图像的 B 分量（5 位宽）

    // 图像处理后的数据接口
    output              post_frame_vsync,   // 输出的场同步信号
    output              post_frame_hsync,   // 输出的行同步信号
    output              post_frame_de   ,   // 输出的数据有效信号
    output      [7:0]   img_y           ,   // 输出的 Y 分量（亮度）
    output      [7:0]   img_cb          ,   // 输出的 Cb 分量（色度）
    output      [7:0]   img_cr              // 输出的 Cr 分量（色度）
);

//-----------------------------------------------------------------------------
// 内部寄存器定义
reg  [15:0]   rgb_r_m0, rgb_r_m1, rgb_r_m2;  // R 分量的乘法结果
reg  [15:0]   rgb_g_m0, rgb_g_m1, rgb_g_m2;  // G 分量的乘法结果
reg  [15:0]   rgb_b_m0, rgb_b_m1, rgb_b_m2;  // B 分量的乘法结果
reg  [15:0]   img_y0;                         // Y 分量的临时存储
reg  [15:0]   img_cb0;                        // Cb 分量的临时存储
reg  [15:0]   img_cr0;                        // Cr 分量的临时存储
reg  [7:0]    img_y1;                         // 最终输出的 Y 分量
reg  [7:0]    img_cb1;                        // 最终输出的 Cb 分量
reg  [7:8]    img_cr1;                        // 最终输出的 Cr 分量
reg  [2:0]    pre_frame_vsync_d;              // 场同步信号延时寄存器
reg  [2:0]    pre_frame_hsync_d;              // 行同步信号延时寄存器
reg  [2:0]    pre_frame_de_d;                 // 数据有效信号延时寄存器

//-----------------------------------------------------------------------------
// 内部信号定义
wire [7:0]   rgb888_r;                         // 扩展后的 R 分量
wire [7:0]   rgb888_g;                         // 扩展后的 G 分量
wire [7:8]   rgb888_b;                         // 扩展后的 B 分量

//-----------------------------------------------------------------------------
// RGB565 转 RGB888
// 将 5 位的 R 分量扩展为 8 位，将 6 位的 G 分量扩展为 8 位，将 5 位的 B 分量扩展为 8 位
assign rgb888_r = {img_red, img_red[4:2]};     // R: 扩展为 8 位
assign rgb888_g = {img_green, img_green[5:4]}; // G: 扩展为 8 位
assign rgb888_b = {img_blue, img_blue[4:2]};   // B: 扩展为 8 位

//-----------------------------------------------------------------------------
// 同步输出数据接口信号
// 将输入的同步信号延时 3 拍，并作为输出
assign post_frame_vsync = pre_frame_vsync_d[2]; // 输出的场同步信号
assign post_frame_hsync = pre_frame_hsync_d[2]; // 输出的行同步信号
assign post_frame_de    = pre_frame_de_d[2];    // 输出的数据有效信号

// 如果行同步有效，则输出 YCbCr 数据，否则输出 0
assign img_y  = post_frame_hsync ? img_y1 : 8'd0;   // 输出 Y 分量
assign img_cb = post_frame_hsync ? img_cb1 : 8'd0;  // 输出 Cb 分量
assign img_cr = post_frame_hsync ? img_cr1 : 8'd0;  // 输出 Cr 分量

//-----------------------------------------------------------------------------
// RGB888 转 YCbCr 的计算公式：
// Y  = 0.299 * R + 0.587 * G + 0.114 * B
// Cb = -0.172 * R - 0.339 * G + 0.511 * B + 128
// Cr = 0.511 * R - 0.428 * G - 0.083 * B + 128
//
// 整数化简为：
// Y  = (77 * R + 150 * G + 29 * B) >> 8
// Cb = (-43 * R - 85 * G + 128 * B + 32768) >> 8
// Cr = (128 * R - 107 * G - 21 * B + 32768) >> 8

//-----------------------------------------------------------------------------
// 第一步：乘法计算
// 对 R、G 和 B 分量分别与各系数相乘，并存储在寄存器中
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rgb_r_m0 <= 16'd0;
        rgb_r_m1 <= 16'd0;
        rgb_r_m2 <= 16'd0;
        rgb_g_m0 <= 16'd0;
        rgb_g_m1 <= 16'd0;
        rgb_g_m2 <= 16'd0;
        rgb_b_m0 <= 16'd0;
        rgb_b_m1 <= 16'd0;
        rgb_b_m2 <= 16'd0;
    end else begin
        rgb_r_m0 <= rgb888_r * 8'd77;  // 计算 Y 的 R 部分
        rgb_r_m1 <= rgb888_r * 8'd43;  // 计算 Cb 的 R 部分
        rgb_r_m2 <= rgb888_r << 3'd7;  // 计算 Cr 的 R 部分
        rgb_g_m0 <= rgb888_g * 8'd150; // 计算 Y 的 G 部分
        rgb_g_m1 <= rgb888_g * 8'd85;  // 计算 Cb 的 G 部分
        rgb_g_m2 <= rgb888_g * 8'd107; // 计算 Cr 的 G 部分
        rgb_b_m0 <= rgb888_b * 8'd29;  // 计算 Y 的 B 部分
        rgb_b_m1 <= rgb888_b << 3'd7;  // 计算 Cb 的 B 部分
        rgb_b_m2 <= rgb888_b * 8'd21;  // 计算 Cr 的 B 部分
    end
end

//-----------------------------------------------------------------------------
// 第二步：加法计算
// 将乘法结果相加，得到最终的 Y、Cb、Cr 分量（加上偏移量）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        img_y0  <= 16'd0;
        img_cb0 <= 16'd0;
        img_cr0 <= 16'd0;
    end else begin
        img_y0  <= rgb_r_m0 + rgb_g_m0 + rgb_b_m0;                  // 计算 Y 分量
        img_cb0 <= rgb_b_m1 - rgb_r_m1 - rgb_g_m1 + 16'd32768;      // 计算 Cb 分量
        img_cr0 <= rgb_r_m2 - rgb_g_m2 - rgb_b_m2 + 16'd32768;      // 计算 Cr 分量
    end
end

//
// 第三步：将 16 位结果缩减为 8 位（取高 8 位）
// 将上一步得到的 Y、Cb、Cr 分量右移 8 位并输出
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        img_y1  <= 8'd0;
        img_cb1 <= 8'd0;
        img_cr1 <= 8'd0;
    end else begin
        img_y1  <= img_y0[15:8];   // Y 分量的高 8 位作为最终输出
        img_cb1 <= img_cb0[15:8];  // Cb 分量的高 8 位作为最终输出
        img_cr1 <= img_cr0[15:8];  // Cr 分量的高 8 位作为最终输出
    end
end

//-----------------------------------------------------------------------------
// 延时三拍以同步数据信号
// 场同步信号 (pre_frame_vsync)、行同步信号 (pre_frame_hsync) 和数据有效信号 (pre_frame_de) 各自延时 3 拍
// 用于确保处理后信号和数据对齐
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pre_frame_vsync_d <= 3'd0;
        pre_frame_hsync_d <= 3'd0;
        pre_frame_de_d    <= 3'd0;
    end else begin
        pre_frame_vsync_d <= {pre_frame_vsync_d[1:0], pre_frame_vsync}; // 延时 3 拍的场同步信号
        pre_frame_hsync_d <= {pre_frame_hsync_d[1:0], pre_frame_hsync}; // 延时 3 拍的行同步信号
        pre_frame_de_d    <= {pre_frame_de_d[1:0], pre_frame_de};       // 延时 3 拍的数据有效信号
    end
end

endmodule
