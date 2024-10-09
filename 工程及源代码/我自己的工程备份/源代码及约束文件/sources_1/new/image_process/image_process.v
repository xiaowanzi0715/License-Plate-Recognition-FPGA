module image_process(
    // 输入时钟和复位信号
    input           clk            ,   // 时钟信号
    input           rst_n          ,   // 复位信号（低有效）

    // 图像处理前的数据接口
    input           pre_frame_vsync,  // 场同步信号
    input           pre_frame_hsync,  // 行同步信号
    input           pre_frame_de   ,  // 数据输入使能信号
    input    [15:0] pre_rgb        ,  // 输入的RGB565格式图像数据
    input    [10:0] xpos           ,  // 当前像素的水平位置
    input    [10:0] ypos           ,  // 当前像素的垂直位置

    // 图像处理后的数据接口
    output          post_frame_vsync,  // 输出的场同步信号
    output          post_frame_hsync,  // 输出的行同步信号
    output          post_frame_de   ,  // 输出的数据输入使能信号
    output   [15:0] post_rgb           // 输出的RGB565格式图像数据
);

//---------------------- 第一部分：车牌区域检测 ----------------------
// 1.1 RGB 转 YCbCr
// 将输入的RGB图像转换为YCbCr格式，方便后续处理。
// Y: 亮度；Cb: 蓝色色度；Cr: 红色色度
rgb2ycbcr u1_rgb2ycbcr(
    .clk             (clk),               // 时钟信号
    .rst_n           (rst_n),             // 复位信号
    .pre_frame_vsync (pre_frame_vsync),   // 输入的场同步信号
    .pre_frame_hsync (pre_frame_hsync),   // 输入的行同步信号
    .pre_frame_de    (pre_frame_de),      // 数据输入使能信号
    .img_red         (pre_rgb[15:11]),    // 输入的红色分量
    .img_green       (pre_rgb[10:5]),     // 输入的绿色分量
    .img_blue        (pre_rgb[4:0]),      // 输入的蓝色分量

    .post_frame_vsync(ycbcr_vsync),       // 输出的场同步信号
    .post_frame_hsync(ycbcr_hsync),       // 输出的行同步信号
    .post_frame_de   (ycbcr_de),          // 输出的数据使能信号
    .img_y           (img_y),             // 输出的Y分量（亮度）
    .img_cb          (img_cb),            // 输出的Cb分量（蓝色色度）
    .img_cr          (img_cr)             // 输出的Cr分量（红色色度）
);

// 1.2 二值化
// 使用蓝色色度Cb进行二值化，提取蓝色区域作为车牌的候选区域。
binarization u1_binarization(
    .clk     (clk),                     // 时钟信号
    .rst_n   (rst_n),                   // 复位信号
    .per_frame_vsync   (ycbcr_vsync),   // YCbCr转换后的场同步信号
    .per_frame_href    (ycbcr_hsync),   // YCbCr转换后的行同步信号
    .per_frame_clken   (ycbcr_de),      // YCbCr转换后的数据使能信号
    .per_img_Y         (img_cb),        // 使用蓝色色度Cb分量作为输入
    
    .post_frame_vsync  (binarization_vsync), // 输出的场同步信号
    .post_frame_href   (binarization_hsync), // 输出的行同步信号
    .post_frame_clken  (binarization_de),    // 输出的数据使能信号
    .post_img_Bit      (binarization_bit),   // 输出的二值化结果
    .Binary_Threshold  (8'd150)             // 二值化阈值
);

// 1.3 腐蚀
// 腐蚀操作去除小噪点，保留较大的连通区域（如车牌区域）。
VIP_Bit_Erosion_Detector # (
    .IMG_HDISP (10'd640),    // 图像的水平分辨率为640
    .IMG_VDISP (10'd480)     // 图像的垂直分辨率为480
) u1_VIP_Bit_Erosion_Detector (
    .clk               (clk),              // 时钟信号
    .rst_n             (rst_n),            // 复位信号
    .per_frame_vsync   (binarization_vsync), // 输入的场同步信号
    .per_frame_href    (binarization_hsync), // 输入的行同步信号
    .per_frame_clken   (binarization_de),    // 输入的数据使能信号
    .per_img_Bit       (binarization_bit),   // 输入的二值化图像
    .post_frame_vsync  (erosion_vsync),      // 输出的场同步信号
    .post_frame_href   (erosion_hsync),      // 输出的行同步信号
    .post_frame_clken  (erosion_de),         // 输出的数据使能信号
    .post_img_Bit      (erosion_bit)         // 输出的腐蚀处理结果
);

// 1.4 Sobel边缘检测
// 使用Sobel算子进行边缘检测，提取图像中的边缘信息。
Sobel_Edge_Detector # (
    .SOBEL_THRESHOLD   (8'd128) // Sobel边缘检测的阈值
) u1_Sobel_Edge_Detector (
    .clk               (clk),              // 时钟信号
    .rst_n             (rst_n),            // 复位信号
    .per_frame_vsync   (erosion_vsync),    // 腐蚀处理后的场同步信号
    .per_frame_href    (erosion_hsync),    // 腐蚀处理后的行同步信号
    .per_frame_clken   (erosion_de),       // 腐蚀处理后的数据使能信号
    .per_img_y         ({8{erosion_bit}}), // 输入的亮度数据（腐蚀后的二值化图像）
    .post_frame_vsync  (sobel_vsync),      // 输出的场同步信号
    .post_frame_href   (sobel_hsync),      // 输出的行同步信号
    .post_frame_clken  (sobel_de),         // 输出的数据使能信号
    .post_img_bit      (sobel_bit)         // 输出的边缘检测结果
);

// 1.5 膨胀
// 膨胀操作增强车牌区域，填补边缘的空白部分。
VIP_Bit_Dilation_Detector # (
    .IMG_HDISP(10'd640),    // 图像的水平分辨率为640
    .IMG_VDISP(10'd480)     // 图像的垂直分辨率为480
) u1_VIP_Bit_Dilation_Detector (
    .clk               (clk),              // 时钟信号
    .rst_n             (rst_n),            // 复位信号
    .per_frame_vsync   (sobel_vsync),      // Sobel边缘检测后的场同步信号
    .per_frame_href    (sobel_hsync),      // Sobel边缘检测后的行同步信号
    .per_frame_clken   (sobel_de),         // Sobel边缘检测后的数据使能信号
    .per_img_Bit       (sobel_bit),        // 输入的边缘检测图像
    .post_frame_vsync  (dilation_vsync),   // 输出的场同步信号
    .post_frame_href   (dilation_hsync),   // 输出的行同步信号
    .post_frame_clken  (dilation_de),      // 输出的数据使能信号
    .post_img_Bit      (dilation_bit)      // 输出的膨胀处理结果
);

//
// 1.6 水平投影 & 垂直投影
// 利用水平和垂直投影方法来确定车牌的边界。
// 水平投影用于检测车牌的上下边界，垂直投影用于检测左右边界。

// 水平投影
VIP_horizon_projection # (
    .IMG_HDISP(10'd640),    // 图像的水平分辨率为640
    .IMG_VDISP(10'd480)     // 图像的垂直分辨率为480
) u1_VIP_horizon_projection (
    .clk               (clk),               // 时钟信号
    .rst_n             (rst_n),             // 复位信号
    .per_frame_vsync   (dilation_vsync),    // 膨胀处理后的场同步信号
    .per_frame_href    (dilation_hsync),    // 膨胀处理后的行同步信号
    .per_frame_clken   (dilation_de),       // 膨胀处理后的数据使能信号
    .per_img_Bit       (dilation_bit),      // 膨胀处理后的二值化图像
    .post_frame_vsync  (projection_vsync),  // 输出的场同步信号
    .post_frame_href   (projection_hsync),  // 输出的行同步信号
    .post_frame_clken  (projection_de),     // 输出的数据使能信号
    .post_img_Bit      (projection_bit),    // 投影处理结果
    .max_line_up       (max_line_up),       // 水平投影结果的上边界
    .max_line_down     (max_line_down),     // 水平投影结果的下边界
    .horizon_start     (10'd10),            // 投影起始列
    .horizon_end       (10'd630)            // 投影结束列
);

// 垂直投影
VIP_vertical_projection # (
    .IMG_HDISP(10'd640),    // 图像的水平分辨率为640
    .IMG_VDISP(10'd480)     // 图像的垂直分辨率为480
) u1_VIP_vertical_projection (
    .clk               (clk),               // 时钟信号
    .rst_n             (rst_n),             // 复位信号
    .per_frame_vsync   (dilation_vsync),    // 膨胀处理后的场同步信号
    .per_frame_href    (dilation_hsync),    // 膨胀处理后的行同步信号
    .per_frame_clken   (dilation_de),       // 膨胀处理后的数据使能信号
    .per_img_Bit       (dilation_bit),      // 膨胀处理后的二值化图像
    .max_line_left     (max_line_left),     // 垂直投影结果的左边界
    .max_line_right    (max_line_right),    // 垂直投影结果的右边界
    .vertical_start    (10'd10),            // 投影起始行
    .vertical_end      (10'd470)            // 投影结束行
);

//---------------------- 第二部分：字符区域检测 ----------------------
// 第二部分用于检测车牌内每个字符的区域，依次进行二值化、腐蚀、膨胀，以及水平和垂直投影。

// 2.1 字符二值化
// 在车牌边界内，对RGB中的红色分量进行二值化，车牌边界外的区域不处理。
char_binarization # (
    .BIN_THRESHOLD   (8'd160)  // 二值化的阈值
) u2_char_binarization (
    .clk               (clk),                     // 时钟信号
    .rst_n             (rst_n),                   // 复位信号
    .per_frame_vsync   (pre_frame_vsync),         // 输入的场同步信号
    .per_frame_href    (pre_frame_hsync),         // 输入的行同步信号
    .per_frame_clken   (pre_frame_de),            // 输入的数据使能信号
    .per_frame_Red     ({pre_rgb[15:11], 3'b111}),// 提取输入的红色分量
    .plate_boarder_up  (max_line_up + 10'd10),    // 车牌上边界（加偏移）
    .plate_boarder_down(max_line_down - 10'd10),  // 车牌下边界（减偏移）
    .plate_boarder_left(max_line_left + 10'd10),  // 车牌左边界（加偏移）
    .plate_boarder_right(max_line_right - 10'd10),// 车牌右边界（减偏移）
    .plate_exist_flag  (1'b1),                    // 表示车牌存在
    .post_frame_vsync  (char_bin_vsync),          // 输出的场同步信号
    .post_frame_href   (char_bin_hsync),          // 输出的行同步信号
    .post_frame_clken  (char_bin_de),             // 输出的数据使能信号
    .post_frame_Bit    (char_bin_bit)             // 输出的二值化结果
);

// 2.2 字符腐蚀
// 通过腐蚀去除字符中的小噪声区域。
VIP_Bit_Erosion_Detector # (
    .IMG_HDISP(10'd640),    // 图像的水平分辨率为640
    .IMG_VDISP(10'd480)     // 图像的垂直分辨率为480
) u2_VIP_Bit_Erosion_Detector (
    .clk               (clk),                // 时钟信号
    .rst_n             (rst_n),              // 复位信号
    .per_frame_vsync   (char_bin_vsync),     // 字符二值化后的场同步信号
    .per_frame_href    (char_bin_hsync),     // 字符二值化后的行同步信号
    .per_frame_clken   (char_bin_de),        // 字符二值化后的数据使能信号
    .per_img_Bit       (char_bin_bit),       // 字符二值化后的图像数据
    .post_frame_vsync  (char_ero_vsync),     // 输出的场同步信号
    .post_frame_href   (char_ero_hsync),     // 输出的行同步信号
    .post_frame_clken  (char_ero_de),        // 输出的数据使能信号
    .post_img_Bit      (char_ero_bit)        // 输出的腐蚀结果
);

// 2.3 字符膨胀
// 膨胀操作用于增强字符的结构，填补字符内部的空隙。
VIP_Bit_Dilation_Detector # (
    .IMG_HDISP(10'd640),    // 图像的水平分辨率为640
    .IMG_VDISP(10'd480)     // 图像的垂直分辨率为480
) u2_VIP_Bit_Dilation_Detector (
    .clk               (clk),               // 时钟信号
    .rst_n             (rst_n),             // 复位信号
    .per_frame_vsync   (char_ero_vsync),    // 字符腐蚀后的场同步信号
    .per_frame_href    (char_ero_hsync),    // 字符腐蚀后的行同步信号
    .per_frame_clken   (char_ero_de),       // 字符腐蚀后的数据使能信号
    .per_img_Bit       (char_ero_bit),      // 字符腐蚀后的图像数据
    .post_frame_vsync  (char_dila_vsync),   // 输出的场同步信号
    .post_frame_href   (char_dila_hsync),   // 输出的行同步信号
    .post_frame_clken  (char_dila_de),      // 输出的数据使能信号
    .post_img_Bit      (char_dila_bit)      // 输出的膨胀结果
);

// 2.4 字符水平和垂直投影
// 通过水平投影和垂直投影确定字符的上、下、左、右边界。
char_horizon_projection # (
    .IMG_HDISP(10'd640),    // 图像的水平分辨率为640
    .IMG_VDISP(10'd480)     // 图像的垂直分辨率为480
) u2_char_horizon_projection (
    .clk               (clk),               // 时钟信号
    .rst_n             (rst_n),             // 复位信号
    .per_frame_vsync   (char_dila_vsync),   // 字符膨胀后的场同步信号
    .per_frame_href    (char_dila_hsync),   // 字符膨胀后的行同步信号
    .per_frame_clken   (char_dila_de),      // 字符膨
    .per_img_Bit       (char_dila_bit),      // 字符膨胀后的二值化图像数据
    .post_frame_vsync  (char_proj_vsync),    // 输出的场同步信号
    .post_frame_href   (char_proj_hsync),    // 输出的行同步信号
    .post_frame_clken  (char_proj_de),       // 输出的数据使能信号
    .post_img_Bit      (char_proj_bit),      // 输出的水平投影结果
    .max_line_up       (char_line_up),       // 水平投影确定的上边界
    .max_line_down     (char_line_down),     // 水平投影确定的下边界
    .horizon_start     (10'd10),             // 水平投影的起始列
    .horizon_end       (10'd630)             // 水平投影的结束列
);

// 2.4.2 字符垂直投影
// 垂直投影用于确定每个字符的左右边界。
char_vertical_projection # (
    .IMG_HDISP(10'd640),    // 图像的水平分辨率为640
    .IMG_VDISP(10'd480)     // 图像的垂直分辨率为480
) u2_char_vertical_projection (
    .clk               (clk),                 // 时钟信号
    .rst_n             (rst_n),               // 复位信号
    .per_frame_vsync   (char_dila_vsync),     // 字符膨胀后的场同步信号
    .per_frame_href    (char_dila_hsync),     // 字符膨胀后的行同步信号
    .per_frame_clken   (char_dila_de),        // 字符膨胀后的数据使能信号
    .per_img_Bit       (char_dila_bit),       // 字符膨胀后的图像数据
    .vertical_start    (10'd10),              // 垂直投影的起始行
    .vertical_end      (10'd630),             // 垂直投影的结束行
    // 输出每个字符的左右边界
    .char1_line_left   (char1_line_left),     // 第1个字符的左边界
    .char1_line_right  (char1_line_right),    // 第1个字符的右边界
    .char2_line_left   (char2_line_left),     // 第2个字符的左边界
    .char2_line_right  (char2_line_right),    // 第2个字符的右边界
    .char3_line_left   (char3_line_left),     // 第3个字符的左边界
    .char3_line_right  (char3_line_right),    // 第3个字符的右边界
    .char4_line_left   (char4_line_left),     // 第4个字符的左边界
    .char4_line_right  (char4_line_right),    // 第4个字符的右边界
    .char5_line_left   (char5_line_left),     // 第5个字符的左边界
    .char5_line_right  (char5_line_right),    // 第5个字符的右边界
    .char6_line_left   (char6_line_left),     // 第6个字符的左边界
    .char6_line_right  (char6_line_right),    // 第6个字符的右边界
    .char7_line_left   (char7_line_left),     // 第7个字符的左边界
    .char7_line_right  (char7_line_right)     // 第7个字符的右边界
);

//---------------------- 第三部分：字符识别 ----------------------
// 第三部分进行模板匹配识别每个字符，并添加边框和显示字符。

// 3.1 提取特征值
// 将字符图像分割为若干个区域，提取每个字符的特征值。
Get_EigenValue # (
    .HOR_SPLIT(8),  // 水平切割成8个区域
    .VER_SPLIT(5)   // 垂直切割成5个区域
) u3_Get_EigenValue (
    .clk               (clk),                 // 时钟信号
    .rst_n             (rst_n),               // 复位信号
    .per_frame_vsync   (char_dila_vsync),     // 输入的场同步信号
    .per_frame_href    (char_dila_hsync),     // 输入的行同步信号
    .per_frame_clken   (char_dila_de),        // 输入的数据使能信号
    .per_frame_bit     (char_dila_bit),       // 输入的字符膨胀后的图像
    // 字符的边界
    .char_line_up      (char_line_up),        // 字符的上边界
    .char_line_down    (char_line_down),      // 字符的下边界
    .char1_line_left   (char1_line_left),     // 第1个字符的左边界
    .char1_line_right  (char1_line_right),    // 第1个字符的右边界
    .char2_line_left   (char2_line_left),     // 第2个字符的左边界
    .char2_line_right  (char2_line_right),    // 第2个字符的右边界
    .char3_line_left   (char3_line_left),     // 第3个字符的左边界
    .char3_line_right  (char3_line_right),    // 第3个字符的右边界
    .char4_line_left   (char4_line_left),     // 第4个字符的左边界
    .char4_line_right  (char4_line_right),    // 第4个字符的右边界
    .char5_line_left   (char5_line_left),     // 第5个字符的左边界
    .char5_line_right  (char5_line_right),    // 第5个字符的右边界
    .char6_line_left   (char6_line_left),     // 第6个字符的左边界
    .char6_line_right  (char6_line_right),    // 第6个字符的右边界
    .char7_line_left   (char7_line_left),     // 第7个字符的左边界
    .char7_line_right  (char7_line_right),    // 第7个字符的右边界
    // 输出特征值
    .char1_eigenvalue  (char1_eigenvalue),    // 第1个字符的特征值
    .char2_eigenvalue  (char2_eigenvalue),    // 第2个字符的特征值
    .char3_eigenvalue  (char3_eigenvalue),    // 第3个字符的特征值
    .char4_eigenvalue  (char4_eigenvalue),    // 第4个字符的特征值
    .char5_eigenvalue  (char5_eigenvalue),    // 第5个字符的特征值
    .char6_eigenvalue  (char6_eigenvalue),    // 第6个字符的特征值
    .char7_eigenvalue  (char7_eigenvalue)     // 第7个字符的特征值
);

// 3.2 模板匹配
// 通过模板匹配识别每个字符。
template_matching # (
    .HOR_SPLIT(8),  // 水平切割成8个区域
    .VER_SPLIT(5)   // 垂直切割成5个区域
) u3_template_matching (
    .clk               (clk),                 // 时钟信号
    .rst_n             (rst_n),               // 复位信号
    .per_frame_vsync   (cal_eigen_vsync),     // 特征值计算后的场同步信号
    .per_frame_href    (cal_eigen_hsync),     // 特征值计算后的行同步信号
    .per_frame_clken   (cal_eigen_de),        // 特征值计算后的数据使能信号
    .per_frame_bit     (cal_eigen_bit),       // 特征值计算后的图像数据
    .plate_boarder_up  (max_line_up),         // 车牌的上边界
    .plate_boarder_down(max_line_down),       // 车牌的下边界
    .plate_boarder_left(max_line_left),       // 车牌的左边界
    .plate_boarder_right(max_line_right),     // 车牌的右边界
    .plate_exist_flag  (1'b1),                // 表示车牌存在
    // 输入特征值
    .char1_eigenvalue  (char1_eigenvalue),    // 第1个字符的特征值
    .char2_eigenvalue  (char2_eigenvalue),    // 第2个字符的特征值
    .char3_eigenvalue  (char3_eigenvalue),    // 第3个字符的特征值
    .char4_eigenvalue  (char
    .char4_eigenvalue  (char4_eigenvalue),    // 第4个字符的特征值
    .char5_eigenvalue  (char5_eigenvalue),    // 第5个字符的特征值
    .char6_eigenvalue  (char6_eigenvalue),    // 第6个字符的特征值
    .char7_eigenvalue  (char7_eigenvalue),    // 第7个字符的特征值
    // 输出识别结果
    .match_index_char1 (match_index_char1),   // 第1个字符匹配结果
    .match_index_char2 (match_index_char2),   // 第2个字符匹配结果
    .match_index_char3 (match_index_char3),   // 第3个字符匹配结果
    .match_index_char4 (match_index_char4),   // 第4个字符匹配结果
    .match_index_char5 (match_index_char5),   // 第5个字符匹配结果
    .match_index_char6 (match_index_char6),   // 第6个字符匹配结果
    .match_index_char7 (match_index_char7)    // 第7个字符匹配结果
);

//---------------------- 第四部分：显示和边框添加 ----------------------
// 将识别出的字符边框和车牌区域边框添加到图像中。

// 4.1 添加车牌和字符的边框
add_grid # (
    .PLATE_WIDTH(10'd5),    // 车牌边框的宽度
    .CHAR_WIDTH (10'd2)     // 字符边框的宽度
) u4_add_grid (
    .clk                (clk),               // 时钟信号
    .rst_n              (rst_n),             // 复位信号
    .per_frame_vsync    (pre_frame_vsync),   // 输入的场同步信号
    .per_frame_href     (pre_frame_hsync),   // 输入的行同步信号
    .per_frame_clken    (pre_frame_de),      // 输入的数据使能信号
    .per_frame_rgb      (pre_rgb),           // 输入的RGB图像数据
    .plate_boarder_up   (max_line_up),       // 车牌上边界
    .plate_boarder_down (max_line_down),     // 车牌下边界
    .plate_boarder_left (max_line_left),     // 车牌左边界
    .plate_boarder_right(max_line_right),    // 车牌右边界
    .plate_exist_flag   (1'b1),              // 车牌存在标志
    .char_line_up       (char_line_up),      // 字符上边界
    .char_line_down     (char_line_down),    // 字符下边界
    .char1_line_left    (char1_line_left),   // 第1个字符的左边界
    .char1_line_right   (char1_line_right),  // 第1个字符的右边界
    .char2_line_left    (char2_line_left),   // 第2个字符的左边界
    .char2_line_right   (char2_line_right),  // 第2个字符的右边界
    .char3_line_left    (char3_line_left),   // 第3个字符的左边界
    .char3_line_right   (char3_line_right),  // 第3个字符的右边界
    .char4_line_left    (char4_line_left),   // 第4个字符的左边界
    .char4_line_right   (char4_line_right),  // 第4个字符的右边界
    .char5_line_left    (char5_line_left),   // 第5个字符的左边界
    .char5_line_right   (char5_line_right),  // 第5个字符的右边界
    .char6_line_left    (char6_line_left),   // 第6个字符的左边界
    .char6_line_right   (char6_line_right),  // 第6个字符的右边界
    .char7_line_left    (char7_line_left),   // 第7个字符的左边界
    .char7_line_right   (char7_line_right),  // 第7个字符的右边界
    // 输出视频流
    .post_frame_vsync   (add_grid_vsync),    // 输出的场同步信号
    .post_frame_href    (add_grid_href),     // 输出的行同步信号
    .post_frame_clken   (add_grid_de),       // 输出的数据使能信号
    .post_frame_rgb     (add_grid_rgb)       // 输出的带边框的图像
);

// 4.2 添加识别出的字符到图像中
add_char u4_add_char (
    .clk                (clk),               // 时钟信号
    .rst_n              (rst_n),             // 复位信号
    .per_frame_vsync    (add_grid_vsync),    // 输入的场同步信号
    .per_frame_href     (add_grid_href),     // 输入的行同步信号
    .per_frame_clken    (add_grid_de),       // 输入的数据使能信号
    .per_frame_rgb      (add_grid_rgb),      // 输入的带边框的RGB图像
    .plate_boarder_up   (max_line_up),       // 车牌上边界
    .plate_boarder_down (max_line_down),     // 车牌下边界
    .plate_boarder_left (max_line_left),     // 车牌左边界
    .plate_boarder_right(max_line_right),    // 车牌右边界
    .plate_exist_flag   (1'b1),              // 车牌存在标志
    .match_index_char1  (match_index_char1), // 第1个字符识别结果
    .match_index_char2  (match_index_char2), // 第2个字符识别结果
    .match_index_char3  (match_index_char3), // 第3个字符识别结果
    .match_index_char4  (match_index_char4), // 第4个字符识别结果
    .match_index_char5  (match_index_char5), // 第5个字符识别结果
    .match_index_char6  (match_index_char6), // 第6个字符识别结果
    .match_index_char7  (match_index_char7), // 第7个字符识别结果
    // 输出最终结果的图像
    .post_frame_vsync   (post_frame_vsync),  // 输出的场同步信号
    .post_frame_href    (post_frame_hsync),  // 输出的行同步信号
    .post_frame_clken   (post_frame_de),     // 输出的数据使能信号
    .post_frame_rgb     (post_rgb)           // 输出的带字符识别结果的RGB图像
);

endmodule
