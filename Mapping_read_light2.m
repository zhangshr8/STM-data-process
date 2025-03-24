% mapping_read_light2是对mapping_read_light的升级版本，优化了文件读取，支持python输出的无表头文件和Rev9Daw输出的有表头文件，为目前最新的稳定版本
% last update: 2025.3.24 张圣儒
function readfiles
    % 定义持久化变量，避免重复读取数据
    persistent data_loaded data_list file_ids;

    % 仅在第一次加载数据
    if isempty(data_loaded)
        disp('读取数据中...');

        % 定义文件路径和文件 IDs
        basePath = "D:\系统默认\文档\实验数据\STM\TbMnSn\mapping";
        file_ids = ["0068", "0419"]; % 文件 ID 列表
        num_files = length(file_ids);
        data_list = cell(1, num_files); % 初始化存储数据的 cell 数组

        % 遍历文件 ID，读取每个文件的数据
        for i = 1:num_files
            % 构造完整文件路径
            filePath = fullfile(basePath, sprintf('TbMnSn_%s.txt', file_ids(i)));

            % 打开文件
            fid = fopen(filePath, 'r');
            if fid == -1
                error('无法打开文件: %s', filePath);
            end

            % 查找数据起始部分（兼容有表头和无表头的情况）
            foundData = false;
            while ~feof(fid)
                line = fgetl(fid);
                if contains(line, 'DATA TABLE')
                    foundData = true;
                    fgetl(fid);  % 跳过横坐标行（仅在有表头的情况下）
                    break;
                end
            end

            % 如果没找到 "DATA TABLE"，从头开始读取所有行（无表头文件）
            if ~foundData
                fseek(fid, 0, 'bof');
            end

            % 读取数据部分
            data_raw = [];
            while ~feof(fid)
                line = fgetl(fid);
                % 跳过空行或非数据行
                if isempty(line) || contains(line, 'ASCII Data Listing') || ~contains(line, '-')
                    continue;
                end
                % 将数据行转换为数字数组
                row = sscanf(line, '%f');
                % 确保数据格式一致
                if isempty(row)
                    continue;
                elseif isempty(data_raw)
                    data_raw = row';
                else
                    try
                        data_raw = [data_raw; row'];
                    catch
                        warning('行数据长度不一致，跳过该行。');
                    end
                end
            end

            % 关闭文件
            fclose(fid);

            % 打印 data_raw 形状，调试用
            fprintf('File: %s, Size of data_raw: [%d, %d]\n', file_ids(i), size(data_raw, 1), size(data_raw, 2));

            % 根据文件类型进行分支处理
            if foundData
                % 有表头的情况：去掉第一列（横坐标）
                if size(data_raw, 2) > 1
                    data_raw = data_raw(:, 2:end);
                    fprintf('Detected extra column, removed the first column. New size: [%d, %d]\n', size(data_raw));
                end
            end

            % 重新 reshape（假设为方阵）
            n_points = sqrt(size(data_raw, 2));
            if mod(n_points, 1) ~= 0
                error('数据列数无法整形成方阵！文件：%s', filePath);
            end

            % 存储到 data_list 中
            data_list{i} = reshape(data_raw, [size(data_raw, 1), n_points, n_points]);

            % 打印数据形状信息
            fprintf('File: %s, Shape: [%d, %d, %d]\n', file_ids(i), size(data_list{i}, 1), size(data_list{i}, 2), size(data_list{i}, 3));
        end

        disp('数据加载完成！');
        data_loaded = true;  % 设置标志，指示数据已加载
    else
        disp('使用缓存数据...');
    end






    global layer 
    global min_caxis_ax4 max_caxis_ax4 min_caxis_ax2 max_caxis_ax2 min_caxis_ax1 max_caxis_ax1
    global r1 r2 angle_increment rlim_value zoom_value step_value current_file_idx
    % 创建按钮句柄作为全局变量
    global btn_plusX btn_minusX btn_plusY btn_minusY ;
    
   
        % 初始化图形界面
    fig = figure('Name', 'Image Viewer', 'NumberTitle', 'off', 'Position', [100, 100, 1200, 500]);
    ax1 = subplot(2,2,1);  % 左上：原图
    ax2 = subplot(2,2,2);  % 右上：局部 FFT 图像
    ax3 = subplot(2,2,3);  % 左下：FFT图像，可缩放
    ax4 = subplot(2,2,4);  % 右下：完整 FFT 图像，带圆环
    current_file_idx = 1;
    
    set(ax1, 'Position', [0.05, 0.35, 0.6, 0.6]);  % 调整第一个子图
%     set(ax2, 'Position', [0.45, 0.55, 0.4, 0.4]);   % 调整第二个子图
    set(ax2, 'Position', [0.55, 0.55, 0.4, 0.4]);   % 调整第二个子图
    set(ax3, 'Position', [0.05, 0.03, 0.3, 0.3]);   % 调整第三个子图
    set(ax4, 'Position', [0.45, 0.1, 0.4, 0.4]); % 调整第四个子图

    % 显示第一个文件的原图
    img_ax1 = imagesc(ax1, squeeze(data_list{current_file_idx}(1,:,:)));
    
    colormap(ax1, mymap('pink'));
    colorbar;
    title(ax1, sprintf('Image %s', file_ids(current_file_idx)));
    axis(ax1, 'image');

    min_caxis_ax4 = 0; max_caxis_ax4 = 200;
    min_caxis_ax2 = 0; max_caxis_ax2 = 200; min_caxis_ax1 = 0; max_caxis_ax1 = 20;
    r1 = 2.5; r2 = 25;
    angle_increment = 5;
    rlim_value = 20;
    zoom_value = 1;
    step_value = 5;
    layer = 1;

    % 创建框选区域
    h_rect = imrect(ax1, [10, 10, 50, 50]);
    addNewPositionCallback(h_rect, @(pos) add_callback(pos));
    
    hrect_pos_label = uicontrol('Style', 'text', 'Position', [500, 60, 200, 20], 'String', sprintf('hrect pos&size: %.1f %.1f %.1f %.1f', 10, 10, 50, 50));
    [output1, output2, output3, output4, output5, output6] = calculateFFT(getPosition(h_rect));
    img_ax3 = imagesc(ax3, output1);
    axis(ax3, 'equal');  % 保证像素尺寸比例
    axis(ax3, 'tight');  % 紧贴图像边界
    % 绘制交互式线段，固定中心点
    axes(ax3); 
    len = 40;
    hLine = drawline('Position', [output3-len/2, output4; output3+len/2, output4], ...
                     'Color', 'w', 'LineWidth', 1.5);
    img_ax2 = updateLinecut(hLine, img_ax3, output3, output4); 
    addlistener(hLine, 'MovingROI', @(src, evt) updateLinePosition(src, img_ax2, img_ax3));
    img_ax4 = imagesc(ax4, output2);
    axis(ax4, 'equal');  % 保证像素尺寸比例
    axis(ax4, 'tight');  % 紧贴图像边界
    
    
    % max_fft显示
    max_fft_label = uicontrol('Style', 'text', 'Position', [520, 90, 100, 20], 'String', sprintf('max_fft: %.1f', 0));
    
    % 创建图层滑动条
    layer_slider = uicontrol('Style', 'slider', ...
                        'Min', 1, 'Max', 121, ...
                        'Value', 1, ...
                        'SliderStep', [1/120 1/10], ...
                        'Units', 'pixels', ...
                        'Position', [450 0 242 20], ...
                        'Callback', @(src, event) updateImage(src, img_ax1, data_list{current_file_idx}));
    layer_label = uicontrol('Style', 'text', 'Units','pixels', ...
                              'Position', [450, 20, 80, 20], 'String', sprintf('layer: %.1f', 1));                          
    % 更新图像的回调函数
    function updateImage(slider, img, data)
        layer = round(slider.Value); % 获取当前滑动条数值
        set(img, 'CData', squeeze(data(layer, :, :))); % 更新图像
        set(layer_label, 'String', sprintf('layer: %.1f', layer));
        [fft_data, zoomed_fft, centerX, centerY, centerX_zoomed, centerY_zoomed] = calculateFFT(getPosition(h_rect));
        updateFFTImage(img_ax3, img_ax4, fft_data, zoomed_fft);
        updateLinePosition(hLine, img_ax2, img_ax3);
    %     title(sprintf('Voltage Layer: %d', layer));
    end


    % 创建滑条来控制缩放大小（以图像中心为基准）
    zoom_slider = uicontrol('Style', 'slider', 'Min', 0.1, 'Max', 1, ...
        'Value', zoom_value, 'Position', [20, 370, 100, 20], 'Callback', @update_zoom);
    % 显示当前的缩放比例
    zoom_label = uicontrol('Style', 'text', 'Position', [20, 390, 50, 20], 'String', sprintf('zoom: %.1f', 1));
    
    % 设置固定的XLim和YLim，防止图像缩放
    xlim(ax1, [1, size(squeeze(data_list{current_file_idx}(layer,:,:)), 2)]);  % 固定x轴范围
    ylim(ax1, [1, size(squeeze(data_list{current_file_idx}(layer,:,:)), 1)]);  % 固定y轴范围

       
    % 创建框的位置、大小输入框和按钮
    uicontrol('Style', 'text', 'Position', [440, 120, 100, 20], 'String', 'Rect Position');
    RectPosition_input = uicontrol('Style', 'edit', 'Position', [440, 100, 80, 20], ...
                                 'String', num2str(max_caxis_ax4), 'Callback', @update_RectPosition);
    % 框的位置、大小回调函数
    function update_RectPosition(hObject, ~)
        user_input = get(hObject, 'String');  % 获取用户输入的字符串
        numbers = str2num(user_input);  % 将字符串按空格分割并转换为数值数组

        % 检查输入是否为4个有效数字
        if numel(numbers) ~= 4 || any(isnan(numbers)) || any(numbers <= 0)
            warndlg('请输入4个有效的正数（以空格分隔），如: 20 10 50 50');
            return;
        end

        % 提取坐标和尺寸
        x = numbers(1);
        y = numbers(2);
        width = numbers(3);
        height = numbers(4);

        % 获取数据尺寸 (行, 列)
        data_size = size(squeeze(data_list{current_file_idx}(1, :, :))); 
        max_x = data_size(2);  % 最大 x 坐标（列数）
        max_y = data_size(1);  % 最大 y 坐标（行数）

        % 边界检测：确保矩形框不超出数据边界
        if x < 1 || y < 1 || x + width - 1 > max_x || y + height - 1 > max_y
            warndlg(sprintf('矩形超出边界！\n允许范围: x = [1, %d], y = [1, %d]', max_x, max_y));
            return;
        end

        % 更新矩形的位置和大小
        pos = getPosition(h_rect);  % 获取当前矩形的位置
        pos = [x, y, width, height];
        setPosition(h_rect, pos);   % 设置矩形的新位置和尺寸

        % 更新 FFT 和极坐标角分布
        [fft_data, zoomed_fft, centerX, centerY, centerX_zoomed, centerY_zoomed] = calculateFFT(getPosition(h_rect));
        updateFFTImage(img_ax3, img_ax4, fft_data, zoomed_fft);
        updateLinePosition(hLine, img_ax2, img_ax3);
    end
    
    
    % 添加切换按钮
    uicontrol('Style', 'pushbutton', 'String', '上一张', 'Position', [1050, 20, 60, 25], ...
              'Callback', @(src, event) switch_image('prev'));
    uicontrol('Style', 'pushbutton', 'String', '下一张', 'Position', [1120, 20, 60, 25], ...
              'Callback', @(src, event) switch_image('next'));
          
    % 创建 caxis_ax4 调整的滑块  
    min_caxis_ax4_slider = uicontrol('Style', 'slider', 'Min', 0, 'Max', 2, 'Value', 0, ...
        'Position', [0, 20, 200, 20], 'Callback', @adjust_caxis_ax3ax4);
    max_caxis_ax4_slider = uicontrol('Style', 'slider', 'Min', 0, 'Max', 20, 'Value', 10, ...
        'Position', [0, 0, 200, 20], 'Callback', @adjust_caxis_ax3ax4);
%     uicontrol('Style', 'text', 'Position', [580, 50, 50, 20], 'String', 'Adjust Caxis');
    
    min_caxis_ax4_label = uicontrol('Style', 'text', 'Position', [0, 60, 80, 20], 'String', sprintf('min_ax4: %.1f', 0));
    max_caxis_ax4_label = uicontrol('Style', 'text', 'Position', [0, 40, 80, 20], 'String', sprintf('max_ax4: %.1f', 10));
    
    
    % 创建 r1 和 r2 调节滑块
    r1_slider = uicontrol('Style', 'slider', 'Min', 0, 'Max', 50, 'Value', 2.5, ...
        'Position', [700, 20, 200, 20], 'Callback', @adjust_r_values);
    r2_slider = uicontrol('Style', 'slider', 'Min', 0, 'Max', 100, 'Value', 25, ...
        'Position', [700, 0, 200, 20], 'Callback', @adjust_r_values);
%     uicontrol('Style', 'text', 'Position', [620, 70, 50, 30], 'String', 'Adjust R');
    
    r1_label = uicontrol('Style', 'text', 'Position', [700, 60, 50, 20], 'String', sprintf('r1: %.1f', 2.5));
    r2_label = uicontrol('Style', 'text', 'Position', [700, 40, 50, 20], 'String', sprintf('r2: %.1f', 25));
    
          
    % 添加新回调的函数: 使框的位置一旦改变就刷新fft图像
    function add_callback(pos)
        img = squeeze(data_list{current_file_idx}(layer,:,:));
        [fft_data, zoomed_fft, centerX, centerY, centerX_zoomed, centerY_zoomed] = calculateFFT(pos);
        updateFFTImage(img_ax3, img_ax4, fft_data, zoomed_fft);
        updateLinePosition(hLine, img_ax2, img_ax3);      
    end
          
    function update_zoom(~, ~)
        zoom_value = get(zoom_slider, 'Value');
        set(zoom_label, 'String', sprintf('zoom: %.1f', zoom_value));
        % 更新 FFT 和极坐标角分布
        [fft_data, zoomed_fft, centerX, centerY, centerX_zoomed, centerY_zoomed] = calculateFFT(getPosition(h_rect));
        updateFFTImage(img_ax3, img_ax4, fft_data, zoomed_fft);
    end

    function adjust_caxis_ax3ax4(~, ~)        
        min_caxis_ax4 = get(min_caxis_ax4_slider, 'Value');  % 获取最小值滑块的位置
        max_caxis_ax4 = get(max_caxis_ax4_slider, 'Value');  % 获取最大值滑块的位置
        if min_caxis_ax4 >= max_caxis_ax4 
            warndlg('Min value must be less than Max value!');  % 如果设置错误则显示警告
        else
            caxis_ax4_limits = [min_caxis_ax4 max_caxis_ax4];  % 保存caxis的上下限            
            
            caxis(ax4, caxis_ax4_limits);          
            set(min_caxis_ax4_label, 'String', sprintf('min_ax4: %.3f', min_caxis_ax4));  % 更新显示标签
            set(max_caxis_ax4_label, 'String', sprintf('max_ax4: %.3f', max_caxis_ax4)); 
            caxis(ax3, caxis_ax4_limits);          
        end
        % 更新 FFT 和极坐标角分布
        [fft_data, zoomed_fft, centerX, centerY, centerX_zoomed, centerY_zoomed] = calculateFFT(getPosition(h_rect));
        updateFFTImage(img_ax3, img_ax4, fft_data, zoomed_fft);
    end
    
    % 函数: 调整 r1 和 r2 的回调函数
    function adjust_r_values(~, ~)
        r1 = get(r1_slider, 'Value');
        r2 = get(r2_slider, 'Value');
        set(r1_label, 'String', sprintf('r1: %.1f', r1));  % 更新显示标签
        set(r2_label, 'String', sprintf('r2: %.1f', r2));
        % 确保 r1 小于 r2
        if r1 >= r2
            warndlg('R1 must be less than R2!');
            return;
        end

        % 更新当前模式的显示
        % 更新 FFT 和极坐标角分布
        [fft_data, zoomed_fft, centerX, centerY, centerX_zoomed, centerY_zoomed] = calculateFFT(getPosition(h_rect));
        updateFFTImage(img_ax3, img_ax4, fft_data, zoomed_fft);
        
    end
    
    
    % 切换图片函数
    function switch_image(direction)
        if strcmp(direction, 'next')
            current_file_idx = mod(current_file_idx, num_files) + 1;
        else
            current_file_idx = mod(current_file_idx - 2, num_files) + 1;
        end
        img_ax1.CData = squeeze(data_list{current_file_idx}(layer,:,:));
        title(ax1, sprintf('Image %s', file_ids(current_file_idx)));
        
        [fft_data, zoomed_fft, centerX, centerY, centerX_zoomed, centerY_zoomed] = calculateFFT(getPosition(h_rect));
        updateFFTImage(img_ax3, img_ax4, fft_data, zoomed_fft);
    end
    
    % 更新Linecut图片
    function img_ax2 = updateLinecut(hLine, img, centerX, centerY)
        [xAxis, values] = extractLinecut(hLine.Position, img);
        axes(ax2);
        img_ax2 = plot(xAxis, values);
        xlabel('Distance along line (pixels)');
        ylabel('Intensity');
        title('Linecut Profile');
    end
    % 更新FFT图片
    function updateFFTImage(img1, img2, fftdata, zoomed_fft)
         set(img1, 'CData', fftdata); % 更新图像
         set(img2, 'CData', zoomed_fft); % 更新图像
    end

    % 更新 FFT 图像及角分布
    function [fft_data, zoomed_fft, centerX, centerY, centerX_zoomed, centerY_zoomed] = calculateFFT(pos)
        
        img = squeeze(data_list{current_file_idx}(layer,:,:));
        
        % 提取框选区域的图像数据
        x_start = round(pos(1));
        y_start = round(pos(2));
        width = round(pos(3));
        height = round(pos(4));
        selected_region = img(y_start:y_start+height, x_start:x_start+width);
        % 计算 FFT
        fft_data = abs(fftshift(fft2(selected_region)));      
        
        [rows, cols] = size(fft_data);
        [X, Y] = meshgrid(1:cols, 1:rows);
        % 根据 rows 和 cols 设置中心位置
        centerY = (rows - mod(rows, 2) + 2) / 2;
        centerX = (cols - mod(cols, 2) + 2) / 2;
        fft_data(centerY, centerX) = 0; % 把中心亮点赋零
        
        set(hrect_pos_label, 'String', sprintf('hrect pos&size: %.1f %.1f %.1f %.1f', x_start, y_start, width, height));
        % zoom坐标范围
        % 根据缩放比例重新计算显示区域的大小
        zoom_width = round(size(fft_data, 2) * zoom_value);
        zoom_height = round(size(fft_data, 1) * zoom_value);
        
        % 计算显示区域的边界，确保它不会超出图像边界
        x_zoom_start = max(1, round(centerX - zoom_width / 2));
        x_zoom_end = min(size(fft_data, 2), x_zoom_start + zoom_width - 1);
        y_zoom_start = max(1, round(centerY - zoom_height / 2));
        y_zoom_end = min(size(fft_data, 1), y_zoom_start + zoom_height - 1);
        
        zoomed_fft = fft_data(y_zoom_start:y_zoom_end, x_zoom_start:x_zoom_end);
        
        % 计算zoom区域的中心与尺寸
        [rows_zoomed, cols_zoomed] = size(zoomed_fft);
        % 根据 rows 和 cols 设置中心位置
        centerY_zoomed = (rows_zoomed - mod(rows_zoomed, 2) + 2) / 2;
        centerX_zoomed = (cols_zoomed - mod(cols_zoomed, 2) + 2) / 2;
    end

        % 按钮：保存 linecut 数据
    uicontrol('Style', 'pushbutton', 'String', '保存 Linecut 数据', ...
              'Units', 'pixels', 'Position', [1150 200 80 20], ...
              'Callback', @(src, event) saveFFTLinecutDataFast(hLine, data_list{current_file_idx}));

end


function [xAxis, values] = extractLinecut(linePos, img)
    % 根据线段长度确定采样点数
    len = round(sqrt(diff(linePos(:, 1))^2 + diff(linePos(:, 2))^2));
    if len < 1
        len = 1;
    end
    x = round(linspace(linePos(1, 1), linePos(2, 1), len));
    y = round(linspace(linePos(1, 2), linePos(2, 2), len));
    values = arrayfun(@(i) img.CData(y(i), x(i)), 1:length(x));
    xAxis = linspace(0, len, len); % 横轴为线段的像素长度
end

% **保持线段中点固定**
function updateLinePosition(line, hPlot, img)
    [rows, cols] = size(img.CData);
    [X, Y] = meshgrid(1:cols, 1:rows);
    % 根据 rows 和 cols 设置中心位置
    centerY = (rows - mod(rows, 2) + 2) / 2;
    centerX = (cols - mod(cols, 2) + 2) / 2;
    centerPos = [centerX, centerY];
    pos = line.Position;
    len = sqrt(diff(pos(:,1))^2 + diff(pos(:,2))^2); % 计算线段长度
    dx = (pos(2,1) - pos(1,1)) / len;
    dy = (pos(2,2) - pos(1,2)) / len;

    % 重新计算使中点固定在 centerPos
    newPos = [centerPos(1) - dx*len/2, centerPos(2) - dy*len/2;
              centerPos(1) + dx*len/2, centerPos(2) + dy*len/2];
    line.Position = newPos;

    % 更新 linecut
    [xAxis, values] = extractLinecut(newPos, img);
    set(hPlot, 'XData', xAxis, 'YData', values);
end

function saveFFTLinecutDataFast(line, data)
    % ========= 📌 预处理 Linecut 坐标 =========
    len = round(sqrt(diff(line.Position(:, 1))^2 + diff(line.Position(:, 2))^2));
    if len < 1
        len = 1;
    end
    x = round(linspace(line.Position(1, 1), line.Position(2, 1), len));
    y = round(linspace(line.Position(1, 2), line.Position(2, 2), len));
    
    % ========= ⚡ 快速计算所有层的 FFT =========
    numLayers = size(data, 1);
    imgSize = size(data, 2:3);

    if canUseGPU()
        data = gpuArray(data); % 使用 GPU 加速 FFT
    end

    fftData = zeros(numLayers, len, 'like', data); % 存储 linecut 的 FFT 数据

    % FFT 中心索引（MATLAB 索引从 1 开始）
    centerX = floor(imgSize(2) / 2) + 1;
    centerY = floor(imgSize(1) / 2) + 1;

    for i = 1:numLayers
        layer = squeeze(data(i, :, :));

        % **计算 FFT 并将中心置零**
        fftLayer = fftshift(fft2(layer));
        fftLayer(centerY-1:centerY+1, centerX-1:centerX+1) = 0; % 将 FFT 中心元素置零
        fftLayer = abs(fftLayer);

        % 提取 linecut 数据
        fftData(i, :) = fftLayer(sub2ind(imgSize, y, x));
        
    end

    if isa(fftData, 'gpuArray')
        fftData = gather(fftData); % 将 GPU 数据移回 CPU
    end

    % ========= 💾 保存 Linecut 数据 =========
    assignin('base', 'fft_linecut_data', fftData);
    disp('FFT Linecut 数据已保存至变量 fft_linecut_data。');

    % ========= 📊 新窗口绘制 =========
    figure('Name', 'FFT Linecut Profile', 'NumberTitle', 'off'); 
    xAxis = linspace(-len/2, len/2, len); % x 轴以 linecut 中心为零
    yAxis = 1:numLayers;
 
    imagesc(xAxis, yAxis, fftData);
    colormap('turbo');
    colorbar;
    xlabel('k /Gm-1');
    % 修改 x 轴标签
    xt = xticks();                   % 获取当前 x 轴刻度
    xticklabels(xt * 0.02);          % 将标签乘以 0.02
    % 修改 Y 轴标签 
    yticks(linspace(1, numLayers, 7));  % 例如设置 7 个刻度
    yticklabels(linspace(30, -30, 7)); % 标签改为 -30 到 30
    ylabel('E /meV');
    title('E-k');
    axis image;
%     axis normal;         % 允许横向拉伸
%     pbaspect([2 1 1]);   % 宽高比 = 3:1

end