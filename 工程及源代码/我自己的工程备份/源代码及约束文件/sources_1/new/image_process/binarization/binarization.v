module binarization(
    input               clk            ,   // 时钟信号
    input               rst_n          ,   // 复位信号，低电平有效
    
	input				per_frame_vsync,   // 输入帧同步信号，用于指示帧的开始
	input				per_frame_href ,   // 输入行同步信号，用于指示行的有效区域
	input				per_frame_clken,   // 输入像素时钟使能信号，用于指示当前像素数据是否有效
	input		[7:0]	per_img_Y  ,      // 输入的像素灰度值（8位），用于二值化处理

	output	reg 		post_frame_vsync,  // 输出帧同步信号，保持与输入帧同步信号一致
	output	reg 		post_frame_href ,  // 输出行同步信号，保持与输入行同步信号一致
	output	reg 		post_frame_clken,  // 输出像素时钟使能信号，保持与输入像素时钟使能信号一致
	output	reg 		post_img_Bit  ,    // 输出二值化后的图像像素值（1位），1为白色，0为黑色

	input		[7:0]	Binary_Threshold   // 二值化的阈值，用于决定灰度值转化为黑或白
);

//二值化处理逻辑：比较灰度值和阈值
// 如果当前像素的灰度值大于阈值，则输出二值化像素为1（白色）；否则输出0（黑色）
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) // 当复位信号有效时，重置输出为0
        post_img_Bit <= 1'b0; // 输出二值图像像素位清零
    else begin
		// 比较输入的灰度值与阈值
		if(per_img_Y > Binary_Threshold)  // 如果灰度值大于阈值
			post_img_Bit <= 1'b1;          // 设置二值化输出为1（白色）
		else
			post_img_Bit <= 1'b0;          // 否则设置二值化输出为0（黑色）
	end
end

// 同步信号传递：将输入的帧同步信号、行同步信号和时钟使能信号直接传递到输出
// 确保二值化后图像的同步信号和输入信号保持一致
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin // 当复位信号有效时，所有输出信号置为0
        post_frame_vsync <= 1'd0;  // 重置帧同步信号为0
        post_frame_href  <= 1'd0;  // 重置行同步信号为0
        post_frame_clken <= 1'd0;  // 重置时钟使能信号为0
    end
    else begin
        // 保持输出同步信号与输入信号一致
        post_frame_vsync <= per_frame_vsync;  // 将输入的帧同步信号传递给输出
        post_frame_href  <= per_frame_href ;  // 将输入的行同步信号传递给输出
        post_frame_clken <= per_frame_clken;  // 将输入的时钟使能信号传递给输出
    end
end

endmodule
