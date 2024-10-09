/*-----------------------------------------------------------------------
								 \\\|///
							   \\  - -  //
								(  @ @  )
+-----------------------------oOOo-(_)-oOOo-----------------------------+
CONFIDENTIAL IN CONFIDENCE
This confidential and proprietary software may be only used as authorized
by a licensing agreement from CrazyBingo (Thereturnofbingo).
In the event of publication, the following notice is applicable:
Copyright (C) 2011-20xx CrazyBingo Corporation
The entire notice above must be reproduced on all authorized copies.
Author				:		CrazyBingo
Technology blogs 	: 		www.crazyfpga.com
Email Address 		: 		crazyfpga@vip.qq.com
Filename			:		VIP_Bit_Dilation_Detector.v
Date				:		2013-05-26
Description			:		Bit Image Process with Dilation after Erosion Detector.
							放弃处理图像的第1行和第2行边缘数据，以简化处理
							放弃每行的第1个和第2个像素点，以简化处理
Modification History	:
Date			By			Version			Change Description
=======================================================================
13/05/26		CrazyBingo	1.0				Original
14/03/20		CrazyBingo	2.0				Modification
-----------------------------------------------------------------------
*/

// 设置时间尺度
`timescale 1ns/1ns

module VIP_Bit_Dilation_Detector
#(
	parameter	[9:0]	IMG_HDISP = 10'd640,	// 水平图像分辨率 640像素
	parameter	[9:0]	IMG_VDISP = 10'd480		// 垂直图像分辨率 480像素
)
(
	// 全局时钟信号
	input				clk,  				// CMOS视频像素时钟
	input				rst_n,				// 全局复位信号，低电平有效

	// 准备处理的图像数据
	input				per_frame_vsync,	// 输入帧同步信号
	input				per_frame_href,		// 输入行同步信号
	input				per_frame_clken,	// 输入像素时钟使能信号
	input				per_img_Bit,		// 输入的图像位（1：有效，0：无效）

	// 处理后的图像数据
	output				post_frame_vsync,	// 输出帧同步信号
	output				post_frame_href,	// 输出行同步信号
	output				post_frame_clken,	// 输出像素时钟使能信号
	output				post_img_Bit		// 输出的图像位（1：有效，0：无效）
);

//----------------------------------------------------
// 生成3x3矩阵，用于图像处理
// 处理过的图像数据
wire			matrix_frame_vsync;	// 帧同步信号
wire			matrix_frame_href;	// 行同步信号
wire			matrix_frame_clken;	// 像素时钟使能信号
// 3x3矩阵输出，用于后续的图像处理
wire			matrix_p11, matrix_p12, matrix_p13;
wire			matrix_p21, matrix_p22, matrix_p23;
wire			matrix_p31, matrix_p32, matrix_p33;

// 实例化3x3矩阵生成模块
matrix_generate_3x3_1bit u_matrix_generate_3x3_1bit(
	// 全局时钟信号
	.clk					(clk),  				// CMOS视频像素时钟
	.rst_n					(rst_n),				// 全局复位信号

	// 准备处理的图像数据
	.per_frame_vsync		(per_frame_vsync),		// 输入帧同步信号
	.per_frame_href			(per_frame_href),		// 输入行同步信号
	.per_frame_clken		(per_frame_clken),		// 输入像素时钟使能信号
	.per_img_y    			(per_img_Bit),			// 输入的图像亮度位

	// 处理过的图像数据
	.matrix_frame_vsync		(matrix_frame_vsync),	// 帧同步信号
	.matrix_frame_href		(matrix_frame_href),	// 行同步信号
	.matrix_frame_clken		(matrix_frame_clken),	// 像素时钟使能信号
	.matrix_p11(matrix_p11),	.matrix_p12(matrix_p12), 	.matrix_p13(matrix_p13),	// 3x3矩阵输出
	.matrix_p21(matrix_p21), 	.matrix_p22(matrix_p22), 	.matrix_p23(matrix_p23),
	.matrix_p31(matrix_p31), 	.matrix_p32(matrix_p32), 	.matrix_p33(matrix_p33)
);

// 在这里添加你的算法
//----------------------------------------------------------------------------
//----------------------------------------------------------------------------
//----------------------------------------------------------------------------
// 膨胀操作的逻辑
// 膨胀操作将1扩展到周围的像素
// [   0  0   0  ]   [   1	1   1 ]     [   P1  P2   P3 ]
// [   0  1   0  ]   [   1  1   1 ]     [   P4  P5   P6 ]
// [   0  0   0  ]   [   1  1	1 ]     [   P7  P8   P9 ]
// P = P1 | P2 | P3 | P4 | P5 | P6 | P7 | P8 | P9;
//---------------------------------------
// 使用“或”运算进行膨胀，1表示白色，0表示黑色
// 步骤1
reg	post_img_Bit1,	post_img_Bit2,	post_img_Bit3;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
		post_img_Bit1 <= 1'b0;
		post_img_Bit2 <= 1'b0;
		post_img_Bit3 <= 1'b0;
		end
	else
		begin
		// 将3x3矩阵的每一行进行或运算，得到中间结果
		post_img_Bit1 <= matrix_p11 | matrix_p12 | matrix_p13;
		post_img_Bit2 <= matrix_p21 | matrix_p22 | matrix_p23;
		post_img_Bit3 <= matrix_p31 | matrix_p32 | matrix_p33;
		end
end

// 步骤2：将三行的结果再次进行或运算，得到最终的膨胀结果
reg	post_img_Bit4;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		post_img_Bit4 <= 1'b0;
	else
		post_img_Bit4 <= post_img_Bit1 | post_img_Bit2 | post_img_Bit3;
end

//------------------------------------------
// 同步信号延迟两个时钟周期
reg	[1:0]	per_frame_vsync_r;
reg	[1:0]	per_frame_href_r;	
reg	[1:0]	per_frame_clken_r;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
		// 复位时，所有同步信号清零
		per_frame_vsync_r <= 0;
		per_frame_href_r <= 0;
		per_frame_clken_r <= 0;
		end
	else
		begin
		// 将输入的帧同步信号、行同步信号和时钟使能信号延迟两个时钟周期，以保持与图像数据的同步
		per_frame_vsync_r 	<= 	{per_frame_vsync_r[0], 	matrix_frame_vsync};
		per_frame_href_r 	<= 	{per_frame_href_r[0], 	matrix_frame_href};
		per_frame_clken_r 	<= 	{per_frame_clken_r[0], 	matrix_frame_clken};
		end
end

// 将延迟后的同步信号分配给输出端口
assign	post_frame_vsync 	= 	per_frame_vsync_r[1];
assign	post_frame_href 	= 	per_frame_href_r[1];
assign	post_frame_clken 	= 	per_frame_clken_r[1];

// 如果行同步信号有效，则输出膨胀后的图像数据，否则输出0
assign	post_img_Bit		=	post_frame_href ? post_img_Bit4 : 1'b0;

endmodule
