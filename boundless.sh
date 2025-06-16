#!/bin/bash

# 主菜单函数
function main_menu() {
    while true; do
        clear
        echo "================================================================"
        echo "脚本由哈哈哈哈编写，推特 @ferdie_jhovie，免费开源，请勿相信收费"
        echo "如有问题，可联系推特，仅此只有一个号"
        echo "================================================================"
        echo "退出脚本，请按键盘 Ctrl + C"
        echo "请选择要执行的操作:"
        echo "1) 安装部署节点"
        echo "2) 查看质押余额"
        echo "3) 查看 broker 日志"
        echo "4) 删除节点"
        echo "5) 多GPU版本使用（暂不可用）"
        echo "q) 退出脚本"
        echo "================================================================"
        read -p "请输入选项 [1/2/3/4/5/q]: " choice
        case $choice in
            1)
                install_node
                ;;
            2)
                check_stake_balance
                ;;
            3)
                view_broker_logs
                ;;
            4)
                remove_node
                ;;
            5)
                multi_gpu_setup
                ;;
            q|Q)
                echo "感谢使用，再见！"
                exit 0
                ;;
            *)
                echo "无效选项，请重新选择"
                sleep 2
                ;;
        esac
    done
}

# 安装部署节点函数
function install_node() {
    clear
    echo "开始安装部署节点..."
    
    # 检查是否以 root 权限运行
    if [ "$EUID" -ne 0 ]; then 
        echo "请使用 sudo 运行此脚本"
        exit 1
    fi

    echo "检查 Docker 安装状态..."
    if ! command -v docker &> /dev/null; then
        echo "正在安装 Docker..."
        apt-get update
        apt-get install -y ca-certificates curl gnupg
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        usermod -aG docker $SUDO_USER
        echo "Docker 安装完成，请注销并重新登录以使组成员身份生效"
    fi

    echo "检查 NVIDIA Docker 支持..."
    if ! command -v nvidia-docker &> /dev/null; then
        echo "正在安装 NVIDIA Container Toolkit..."
        distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
        curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
        curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list
        apt-get update
        apt-get install -y nvidia-container-toolkit
        systemctl restart docker
        echo "NVIDIA Container Toolkit 安装完成"
    fi

    echo "检查 screen 安装状态..."
    if ! command -v screen &> /dev/null; then
        echo "正在安装 screen..."
        apt-get update
        apt-get install -y screen
        if [ $? -ne 0 ]; then
            echo "screen 安装失败，请手动安装"
            exit 1
        fi
        echo "screen 安装完成"
    fi

    echo "检查 just 安装状态..."
    if ! command -v just &> /dev/null; then
        echo "正在安装 just..."
        curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin
        if [ $? -ne 0 ]; then
            echo "just 安装失败，请手动安装"
            exit 1
        fi
        echo "just 安装完成"
    fi

    echo "开始克隆仓库..."
    if [ ! -d "boundless" ]; then
        git clone https://github.com/boundless-xyz/boundless
        if [ $? -ne 0 ]; then
            echo "克隆失败，请检查网络连接或仓库地址是否正确"
            exit 1
        fi
    fi

    cd boundless
    echo "切换到 release-0.9 分支..."
    git checkout release-0.9
    if [ $? -ne 0 ]; then
        echo "切换分支失败，请检查分支名称是否正确"
        exit 1
    fi

    echo "安装 Rust 和相关工具链..."
    echo "正在安装 rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    if [ $? -ne 0 ]; then
        echo "rustup 安装失败，请检查网络连接或手动安装"
        exit 1
    fi
    echo "rustup 安装完成"

    echo "正在更新 rustup..."
    rustup update
    if [ $? -ne 0 ]; then
        echo "rustup 更新失败，请检查网络连接或手动更新"
        exit 1
    fi
    echo "rustup 更新完成"

    echo "正在安装 Rust 工具链..."
    apt-get update
    apt-get install -y cargo
    if [ $? -ne 0 ]; then
        echo "Rust 工具链安装失败，请手动安装"
        exit 1
    fi
    echo "Rust 工具链安装完成"

    echo "验证 Cargo 安装..."
    cargo --version
    if [ $? -ne 0 ]; then
        echo "Cargo 验证失败，请检查安装"
        exit 1
    fi
    echo "Cargo 验证通过"

    echo "正在安装 rzup..."
    curl -L https://risczero.com/install | bash
    source ~/.bashrc
    if [ $? -ne 0 ]; then
        echo "rzup 安装失败，请检查网络连接或手动安装"
        exit 1
    fi
    echo "rzup 安装完成"

    echo "验证 rzup 安装..."
    rzup --version
    if [ $? -ne 0 ]; then
        echo "rzup 验证失败，请检查安装"
        exit 1
    fi
    echo "rzup 验证通过"

    echo "正在安装 RISC Zero Rust 工具链..."
    rzup install rust
    if [ $? -ne 0 ]; then
        echo "RISC Zero Rust 工具链安装失败，请手动安装"
        exit 1
    fi
    echo "RISC Zero Rust 工具链安装完成"

    echo "正在安装 cargo-risczero..."
    cargo install cargo-risczero
    rzup install cargo-risczero
    if [ $? -ne 0 ]; then
        echo "cargo-risczero 安装失败，请检查网络连接或手动安装"
        exit 1
    fi
    echo "cargo-risczero 安装完成"

    echo "再次更新 rustup..."
    rustup update
    if [ $? -ne 0 ]; then
        echo "rustup 更新失败，请检查网络连接或手动更新"
        exit 1
    fi
    echo "rustup 更新完成"

    echo "正在安装 bento-client..."
    cargo install --git https://github.com/risc0/risc0 bento-client --bin bento_cli
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
    if [ $? -ne 0 ]; then
        echo "bento-client 安装失败，请检查网络连接或手动安装"
        exit 1
    fi
    echo "bento-client 安装完成"

    echo "验证 bento-client 安装..."
    bento_cli --version
    if [ $? -ne 0 ]; then
        echo "bento-client 验证失败，请检查安装"
        exit 1
    fi
    echo "bento-client 验证通过"

    echo "正在安装 boundless-cli..."
    cargo install --locked boundless-cli
    export PATH=$PATH:/root/.cargo/bin
    source ~/.bashrc
    if [ $? -ne 0 ]; then
        echo "boundless-cli 安装失败，请检查网络连接或手动安装"
        exit 1
    fi
    echo "boundless-cli 安装完成"

    echo "验证 boundless-cli 安装..."
    boundless -h
    if [ $? -ne 0 ]; then
        echo "boundless-cli 验证失败，请检查安装"
        exit 1
    fi
    echo "boundless-cli 验证通过"

    echo "执行 setup.sh 脚本..."
    chmod +x ./scripts/setup.sh
    ./scripts/setup.sh
    if [ $? -ne 0 ]; then
        echo "执行 setup.sh 失败，请检查脚本权限或手动执行"
        exit 1
    fi

    echo "所有依赖安装完成！"
    echo "请注销并重新登录以使 Docker 组成员身份生效"

    # 获取用户输入并写入 .env.eth-sepolia 文件
    echo "请设置您的环境变量："
    echo "提示：请使用 Ethereum Sepolia 测试网的 Alchemy RPC URL"
    echo "格式：https://eth-sepolia.g.alchemy.com/v2/YOUR-API-KEY"
    echo "您可以在 https://www.alchemy.com/ 注册并获取 API KEY"
    echo "注意：请确保选择 Sepolia 网络"
    echo "----------------------------------------"

    read -p "请输入您的 PRIVATE_KEY: " PRIVATE_KEY
    read -p "请输入您的 Sepolia RPC_URL: " RPC_URL

    # 检查 RPC_URL 是否包含 sepolia
    if [[ "$RPC_URL" != *"sepolia"* ]]; then
        echo "警告：您使用的不是 Sepolia 网络的 RPC URL，这可能会导致连接问题"
        read -p "是否继续使用当前 RPC URL？(y/n): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "已取消设置，请重新运行脚本"
            exit 1
        fi
    fi

    # 验证输入是否为空
    if [ -z "$PRIVATE_KEY" ] || [ -z "$RPC_URL" ]; then
        echo "错误：请输入有效的 PRIVATE_KEY 和 RPC_URL"
        exit 1
    fi

    # 避免重复写入，移除旧的 PRIVATE_KEY 和 RPC_URL（如果存在）
    sed -i '/^PRIVATE_KEY=/d' .env.eth-sepolia 2>/dev/null
    sed -i '/^RPC_URL=/d' .env.eth-sepolia 2>/dev/null

    # 追加环境变量到 .env.eth-sepolia 文件
    echo "正在将环境变量写入 .env.eth-sepolia..."
    echo "PRIVATE_KEY=$PRIVATE_KEY" >> .env.eth-sepolia
    echo "RPC_URL=$RPC_URL" >> .env.eth-sepolia

    # 验证是否写入成功
    if grep -q "PRIVATE_KEY=$PRIVATE_KEY" .env.eth-sepolia && grep -q "RPC_URL=$RPC_URL" .env.eth-sepolia; then
        echo "环境变量已成功写入 .env.eth-sepolia 文件！"
        # 加载 .env.eth-sepolia 文件
        echo "正在加载环境变量..."
        source .env.eth-sepolia
        # 验证环境变量是否加载成功
        if [ -z "$PRIVATE_KEY" ] || [ -z "$RPC_URL" ]; then
            echo "错误：加载 .env.eth-sepolia 文件失败，请检查文件内容"
            exit 1
        fi
        echo "环境变量加载成功！"
    else
        echo "错误：写入 .env.eth-sepolia 文件失败，请检查文件权限"
        exit 1
    fi

    # 提示用户运行 bento 服务
    echo "请在新终端中运行以下命令以启动 bento 服务："
    echo "cd $(pwd) && just bento"
    echo "完成后，按回车键继续..."
    read

    # 等待 5 秒
    echo "等待 5 秒后启动 bento_cli..."
    sleep 5

    # 启动 bento_cli 并将输出保存到日志文件
    echo "正在启动 bento_cli..."
    RUST_LOG=info bento_cli -c 32 | tee /tmp/bento_cli_output.log &
    BENTO_CLI_PID=$!

    # 等待 image_id 显示
    echo "等待 image_id 显示..."
    while ! grep -q "image_id" /tmp/bento_cli_output.log; do
        sleep 1
    done

    # 显示测试成功信息并退出
    echo "image_id 已显示，测试证明成功！"
    echo "正在清理并退出..."
    kill $BENTO_CLI_PID 2>/dev/null
    rm /tmp/bento_cli_output.log 2>/dev/null
    sleep 3
    exit 0

    # 注意：以下代码因早期退出而不可达，保留以备后续扩展
    # 设置 testnet 环境
    echo "正在设置 testnet 环境..."
    source <(just env testnet)
    if [ $? -ne 0 ]; then
        echo "设置 testnet 环境失败，请检查网络连接或手动设置"
        exit 1
    fi
    echo "testnet 环境设置完成！"

    # 获取用户存款数量并执行存款
    echo "----------------------------------------"
    echo "请设置存款数量（USDC）："
    echo "注意：请确保您的账户中有足够的 USDC"
    echo "----------------------------------------"

    while true; do
        read -p "请输入要存入的 USDC 数量: " USDC_AMOUNT
        # 检查输入是否为数字
        if [[ "$USDC_AMOUNT" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            break
        else
            echo "错误：请输入有效的数字"
        fi
    done

    echo "正在执行存款操作..."
    echo "存款数量: $USDC_AMOUNT USDC"
    boundless account deposit-stake "$USDC_AMOUNT"

    if [ $? -ne 0 ]; then
        echo "存款操作失败，请检查："
        echo "1. 账户余额是否充足"
        echo "2. 网络连接是否正常"
        echo "3. 环境变量是否正确设置"
        exit 1
    fi

    echo "存款操作完成！"

    # 提示用户运行 broker 服务
    echo "请在新终端中运行以下命令以启动 broker 服务："
    echo "cd $(pwd) && just broker"
    echo "完成后，按回车键继续..."
    read

    echo "脚本执行完成！"

    # 安装完成后返回主菜单
    echo "按回车键返回主菜单..."
    read
}

# 查看质押余额函数
function check_stake_balance() {
    clear
    echo "查看质押余额"
    echo "----------------------------------------"
    
    # 检查环境变量是否设置
    if [ ! -f "boundless/.env.eth-sepolia" ]; then
        echo "错误：未找到 .env.eth-sepolia 文件"
        echo "请先运行选项 1 完成安装部署"
        echo "按回车键返回主菜单..."
        read
        return
    fi

    # 加载环境变量
    cd boundless
    source .env.eth-sepolia
    if [ -z "$PRIVATE_KEY" ] || [ -z "$RPC_URL" ]; then
        echo "错误：环境变量未正确加载"
        echo "请检查 .env.eth-sepolia 文件内容"
        echo "按回车键返回主菜单..."
        read
        return
    fi

    # 获取钱包地址
    read -p "请输入要查询的钱包地址: " WALLET_ADDRESS
    
    # 验证钱包地址格式
    if [[ ! "$WALLET_ADDRESS" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        echo "错误：无效的钱包地址格式"
        echo "请确保输入的是有效的以太坊地址"
        echo "按回车键返回主菜单..."
        read
        return
    fi

    echo "正在查询质押余额..."
    echo "钱包地址: $WALLET_ADDRESS"
    echo "----------------------------------------"
    
    # 执行查询命令
    boundless account stake-balance "$WALLET_ADDRESS"
    
    if [ $? -ne 0 ]; then
        echo "查询失败，请检查："
        echo "1. 钱包地址是否正确"
        echo "2. 网络连接是否正常"
        echo "3. 环境变量是否正确设置"
    fi
    
    echo "----------------------------------------"
    echo "按回车键返回主菜单..."
    read
}

# 查看 broker 日志函数
function view_broker_logs() {
    clear
    echo "查看 broker 日志"
    echo "----------------------------------------"
    
    # 检查是否在 boundless 目录
    if [ ! -d "boundless" ]; then
        echo "错误：未找到 boundless 目录"
        echo "请先运行选项 1 完成安装部署"
        echo "按回车键返回主菜单..."
        read
        return
    fi

    # 切换到 boundless 目录
    cd boundless

    # 检查 broker 服务是否在运行
    if ! pgrep -f "just broker" > /dev/null; then
        echo "警告：broker 服务未运行"
        echo "是否要启动 broker 服务？(y/n)"
        read -p "请输入选项 [y/n]: " start_choice
        if [[ "$start_choice" == "y" || "$start_choice" == "Y" ]]; then
            echo "请在新终端中运行以下命令以启动 broker 服务："
            echo "cd $(pwd) && just broker"
            echo "完成后，按回车键继续..."
            read
        else
            echo "按回车键返回主菜单..."
            read
            return
        fi
    else
        echo "broker 服务已在运行中"
    fi

    echo "----------------------------------------"
    echo "日志查看说明："
    echo "1. broker 服务已在后台运行"
    echo "2. 使用 Ctrl+C 可以停止查看日志（服务会继续在后台运行）"
    echo "----------------------------------------"
    echo "按回车键开始查看日志..."
    read

    # 查看日志
    just broker logs

    echo "----------------------------------------"
    echo "日志查看已结束"
    echo "broker 服务仍在后台运行"
    echo "按回车键返回主菜单..."
    read
}

# 删除节点函数
function remove_node() {
    clear
    echo "删除节点"
    echo "----------------------------------------"
    echo "警告：此操作将完全删除节点，包括："
    echo "1. 停止 broker 服务"
    echo "2. 清理所有节点数据"
    echo "3. 删除整个 boundless 目录"
    echo "----------------------------------------"
    
    read -p "是否确定要删除节点？(y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "已取消删除操作"
        echo "按回车键返回主菜单..."
        read
        return
    fi

    # 检查是否在 boundless 目录
    if [ ! -d "boundless" ]; then
        echo "错误：未找到 boundless 目录"
        echo "按回车键返回主菜单..."
        read
        return
    fi

    # 切换到 boundless 目录
    cd boundless

    # 停止 broker 服务
    echo "正在停止 broker 服务..."
    if pgrep -f "just broker" > /dev/null; then
        just broker down
        sleep 2
        echo "broker 服务已停止"
    else
        echo "broker 服务未运行"
    fi

    # 清理数据
    echo "正在清理节点数据..."
    just broker clean
    if [ $? -ne 0 ]; then
        echo "警告：清理数据时出现错误，但将继续删除目录"
    else
        echo "节点数据已清理"
    fi

    # 返回上级目录
    cd ..

    # 删除 boundless 目录
    echo "正在删除 boundless 目录..."
    read -p "最后确认：是否要删除整个 boundless 目录？(y/n): " final_confirm
    if [[ "$final_confirm" == "y" || "$final_confirm" == "Y" ]]; then
        rm -rf boundless
        if [ $? -eq 0 ]; then
            echo "boundless 目录已删除"
        else
            echo "错误：删除目录失败，请手动删除"
        fi
    else
        echo "已取消删除目录"
    fi

    echo "----------------------------------------"
    echo "节点删除操作完成"
    echo "按回车键返回主菜单..."
    read
}

# 多GPU版本设置函数
function multi_gpu_setup() {
    clear
    echo "多GPU版本设置"
    echo "----------------------------------------"
    
    # 检查是否在 boundless 目录
    if [ ! -d "boundless" ]; then
        echo "错误：未找到 boundless 目录"
        echo "请先运行选项 1 完成安装部署"
        echo "按回车键返回主菜单..."
        read
        return
    fi

    # 切换到 boundless 目录
    cd boundless

    # 检查 NVIDIA 驱动和 CUDA 是否安装
    if ! command -v nvidia-smi &> /dev/null; then
        echo "错误：未检测到 NVIDIA 驱动"
        echo "请先安装 NVIDIA 驱动和 CUDA"
        echo "按回车键返回主菜单..."
        read
        return
    fi

    # 显示 GPU 信息
    echo "GPU 信息："
    nvidia-smi -L

    echo "----------------------------------------"
    echo "按回车键返回主菜单..."
    read
}

# 启动主菜单
main_menu
