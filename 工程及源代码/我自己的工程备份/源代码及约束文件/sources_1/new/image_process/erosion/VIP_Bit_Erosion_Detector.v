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
Filename			:		VIP_Bit_Erosion_Detector.v
Date				:		2013-05-26
Description			:		Bit Image Process with Erosion before Dilation Detector.
							Give up the 1st and 2nd row edge data for simple processing
							Give up the 1st and 2nd point of 1 line for simple processing
Modification History	:
Date			By			Version			Change Description
========================================================================= 
13/05/26		CrazyBingo	1.0				Original
14/03/20		CrazyBingo	2.0				Modification
------------------------------------------------------------------------- 
|                                     Oooo								|
+-------------------------------oooO--(   )-----------------------------+
                               (   )   ) /
                                \ (   (_/
                                 \_)
-----------------------------------------------------------------------*/ 

`timescale 1ns/1ns

module VIP_Bit_Erosion_Detector
#(
	parameter	[9:0]	IMG_HDISP = 10'd640,	// 图像水平分辨率，默认为640
	parameter	[9:0]	IMG_VDISP = 10'd480		// 图像垂直分辨率，默认为480
)
(
	//global clock
	input				clk,  				// cmos 图像像素时钟信号
	input				rst_n,				// 全局复位信号，低电平有效

	//Image data prepared to be processed
	input				per_frame_vsync,	// 输入帧同步信号
	input				per_frame_href,		// 输入行同步信号
	input				per_frame_clken,	// 数据时钟使能信号，图像数据有效性
	input				per_img_Bit,		// 输入的图像二值化数据（1表示白色像素，0表示黑色像素）
	
	//Image data has been processed
	output				post_frame_vsync,	// 输出帧同步信号
	output				post_frame_href,	// 输出行同步信号
	output				post_frame_clken,	// 输出数据时钟使能信号
	output				post_img_Bit		// 输出的处理后的图像二值化数据
);

// 生成 1 位 3x3 矩阵，用于图像处理的卷积操作
matrix_generate_3x3_1bit u_matrix_generate_3x3_1bit(
	//global clock
	.clk					(clk),  				// cmos 图像像素时钟信号
	.rst_n					(rst_n),				// 复位信号

	//Image data prepared to be processed
	.per_frame_vsync		(per_frame_vsync),		// 输入帧同步信号
	.per_frame_href			(per_frame_href),		// 输入行同步信号
	.per_frame_clken		(per_frame_clken),		// 数据时钟使能信号
	.per_img_y			    (per_img_Bit),			// 输入的二值化图像数据

	//Image data has been processed
	.matrix_frame_vsync		(matrix_frame_vsync),	// 处理后的帧同步信号
	.matrix_frame_href		(matrix_frame_href),	// 处理后的行同步信号
	.matrix_frame_clken		(matrix_frame_clken),	// 处理后的数据时钟使能信号
	.matrix_p11(matrix_p11),	.matrix_p12(matrix_p12), 	.matrix_p13(matrix_p13),	// 3x3 矩阵的输出像素
	.matrix_p21(matrix_p21), 	.matrix_p22(matrix_p22), 	.matrix_p23(matrix_p23),
	.matrix_p31(matrix_p31), 	.matrix_p32(matrix_p32), 	.matrix_p33(matrix_p33)
);

// 腐蚀操作：对每一行像素进行 "与" 操作，提取腐蚀后的图像
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
		// 对 3x3 矩阵的每一行进行 "与" 操作
		post_img_Bit1 <= matrix_p11 & matrix_p12 & matrix_p13; // 第一行
		post_img_Bit2 <= matrix_p21 & matrix_p22 & matrix_p23; // 第二行
		post_img_Bit3 <= matrix_p31 & matrix_p32 & matrix_p33; // 第三行
		end
end

// 最终腐蚀结果，合并所有行的结果
reg	post_img_Bit4;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		post_img_Bit4 <= 1'b0;
	else
		// 将三行结果进行“与”操作，得到最终的腐蚀像素结果
		post_img_Bit4 <= post_img_Bit1 & post_img_Bit2 & post_img_Bit3;
end

// 同步信号延时2拍，以确保信号与数据同步
reg	[1:0]	per_frame_vsync_r;
reg	[1:0]	per_frame_href_r;	
reg	[1:0]	per_frame_clken_r;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
		per_frame_vsync_r <= 0;
		per_frame_href_r <= 0;
		per_frame_clken_r <= 0;
		end
	else
		begin
		// 将输入信号延时2拍，确保输出与数据同步
		per_frame_vsync_r 	<= 	{per_frame_vsync_r[0], 	matrix_frame_vsync};
		per_frame_href_r 	<= 	{per_frame_href_r[0], 	matrix_frame_href};
		per_frame_clken_r 	<= 	{per_frame_clken_r[0], 	matrix_frame_clken};
		end
end

// 输出处理后的同步信号和腐蚀后的图像数据
assign	post_frame_vsync 	= 	per_frame_vsync_r[1]; // 延时后的场同步信号
assign	post_frame_href 	= 	per_frame_href_r[1];  // 延时后的行同步信号
assign	post_frame_clken 	= 	per_frame_clken_r[1]; // 延时后的数据使能信号
assign	post_img_Bit		=	post_frame_href ? post_img_Bit4 : 1'b0; // 处理后的二值化图像
endmodule
