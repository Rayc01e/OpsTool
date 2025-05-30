#-----------------------------
#    作者：raycole
#    文件名：auto_sshcopyid.sh
#    最后编辑时间： 25/5/30           
#-----------------------------
#!/bin/bash
# AutoSSH.sh
KEY_DIR=~/.ssh
mkdir -p $KEY_DIR
rpm -qa | grep sshpass > /dev/null
if [ $? -ne 0 ];then
    echo "没有安装sshpass,自动安装"
    dnf install sshpass -y
else
    echo "查询到已安装sshpass"
fi
echo "+=============================================================+"
echo "|  #请选择：                                                  |"
echo "|  1单主机配置免密登录                                         |"
echo "|  2多主机配置免密登录                                         |"
echo "|  3从文件批量配置免密登陆(需要sshpass)                         |"
echo "|  4固定用户名和密码后从文件批量配置免密登陆(需要sshpass)         |"
echo "+=============================================================+"
read -p "输入选项 (1,2,3,4): " num1

# 初始化变量
remote_hosts=()  # 存储所有主机地址
remote_users=()  # 存储所有用户名
remote_passes=() # 存储所有密码的数组
exit_code=()     # 储存返回结果的数组

case $num1 in
    # 单主机配置免密登录
    1)
        read -p "输入主机地址: " remote_host
        remote_hosts=("$remote_host")
        ping -c 1 -W 1 $remote_host
        if [ $? -ne 0 ]; then
            echo "无法与 $remote_host 通信"
            exit 1
        fi
        read -p "输入远程用户名: " remote_user
        remote_users=("$remote_user")
        read -p "输入远程密码：" passwd
        remote_passes=("$passwd")
        ;;
    
    # 多主机配置免密登录
    2) 
        echo "你选择了多主机配置免密登录"
        read -p "输入主机数量: " dev_num
        i=1
        while [ $i -le $dev_num ]; do
            read -p "输入第 $i 台主机的地址: " host
            echo "---->测试与主机连接中....."
            ping -c 1 -W 1 $host > /dev/null
            if [ $? -ne 0 ]; then
                echo "无法与 $host 通信"
                i=$((i + 1))
                continue
            fi
            read -p "输入第 $i 台主机的用户名: " user
            read -s -p "输入第 $i 台主机的密码：" passwd
            echo
            # 向数组追加元素
            remote_hosts+=("$host")
            remote_users+=("$user")
            remote_passes+=("$passwd")
            i=$((i + 1))
        done
        ;;
    3)
        echo "你选择了从文件批量配置免密登陆"
        # 你可以通过更改host_file后面的路径来达到修改路径的效果
        host_file=~/auto_ssh_host.txt 
        echo "@@@@@@@@@@@@@@@ 读取 $host_file @@@@@@@@@@@@@@@@@@@@@@"
        echo "@@@@@@@@@@@@@@@ 请确保存在路径有对应文件 @@@@@@@@@@@@@@@@@@@@@@@@"
        echo -e "[\e[32m测试连接中...\e[0m]"
        if [ ! -f "$host_file" ]; then
            echo "文件不存在！程序退出"
            sleep 1
        exit 1
        fi
        while read -r host user password; do
            ping -c 2 -W 1 $host > /dev/null
            if [ $? -ne 0 ]; then
                echo "无法连接 $host，跳过..."
            continue
            fi
            remote_hosts+=("$host")
            remote_users+=("$user")
            remote_passes+=("$password")
        done < "$host_file"
        ;;
    4)
        echo "你选择了固定用户名和密码后批量配置免密登陆"
        read -p "输入主机用户名: " host_user
        remote_users=("$host_user")
        read -s -p "输入密码(不显示)" host_pass
        echo
        remote_passes=("$host_pass")
        echo "----------------------------------"
        echo "| 1.从文件读取IP                  |"
        echo "| 2.手动输入IP范围                |"
        echo "| 3.Exit                         |"
        echo "----------------------------------"
        read -p "输入选项" num2
        case $num2 in
            1)
                echo "你选择了 从文件读取IP "
                host_file=~/auto_ssh_host.txt
                if [ ! -f "$host_file" ]; then
                    echo "主机文件不存在: $host_file"
                    exit 1
                fi
                while read -r host user password; do
                    ping -c 2 -W 1 "$host" > /dev/null
                    if [ $? -ne 0 ]; then
                        echo "无法连接 $host，跳过..."
                        continue
                    fi
                    remote_hosts+=("$host")
                done < "$host_file"
                ;;
            2)
                echo "你选择了 手动输入IP范围 "
                read -p "请输入IP范围（格式如 192.168.1.100-110）: " ip_range
                if ! [[ "$ip_range" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-[0-9]+$ ]]; then
                    echo "IP范围格式不正确！应形如 192.168.1.100-110"
                    exit 1
                fi
                # 提取 IP 段的前三部分（192.168.1）
                ip_base=$(echo "$ip_range" | cut -d'.' -f1-3)

                # 提取最后一段的起止范围（如 100-110）
                start_end=$(echo "$ip_range" | cut -d'.' -f4)
                start=$(echo "$start_end" | cut -d'-' -f1)
                end=$(echo "$start_end" | cut -d'-' -f2)
                for ((i=start; i<=end; i++)); do
                    ip="$ip_base.$i"
                    echo "正在测试 $ip ..."
                    ping -c 1 -W 1 "$ip" >/dev/null 2>&1
                    if [ $? -ne 0 ]; then
                        echo "无法连接 $ip，跳过..."
                        continue
                    fi
                    remote_hosts+=("$ip") #保存到数组
                done
                ;;
            3)
                echo "退出程序"
                exit 1
                ;;
            *)
                echo "无效选项"
                exit 1
                ;;
            esac
        ;;
    *)
        echo "无效选项!"
        exit 1
        ;;
esac

# 配置免密登录
sleep 1
echo "-----------------------------------"
echo "|  #选择你使用的功能:              |"
echo "|  1已有密钥,做免密登录            |"
echo "|  2生成密钥,做免密登录            |"
echo "|  3退出程序                      |"
echo "-----------------------------------"
read -p "输入选项 (1|2|3): " num2

case $num2 in
    1)
        echo "你选择了 已有密钥,做免密登录"
        for i in "${!remote_hosts[@]}"; do
            host=${remote_hosts[$i]}
            user=${remote_users[$i]}
            echo "正在配置 $user@$host ..."
            if [ "$num1" -eq 4 ]; then
                password=${remote_passes[0]}
            fi
            if [ "$num1" -ne 4 ]; then 
                password=${remote_passes[$i]}
            fi
            sshpass -p "$password" ssh-copy-id -o StrictHostKeyChecking=no -i $KEY_DIR/id_rsa.pub $user@$host 
            if [ $? -ne 0 ]; then
                exit_code[$i]=0
                continue
            fi
            echo "密钥 $KEY_DIR/id_rsa.pub 已经成功复制到 $user@$host"
            exit_code[$i]=1
            if grep -q "$user@$host" "$KEY_DIR/host_list.txt"; then
                echo "主机已存在"
            else
                echo "$user@$host" >> "$KEY_DIR/host_list.txt"
                echo "添加 $user@$host 至 $KEY_DIR/host_list.txt 成功"
            fi
        done
        ;;
    2)
        echo "你选择了 生成密钥,做免密登录"
        read -p "输入密语(可以留空): " passphrase
        ssh-keygen -t rsa -b 4096 -f $KEY_DIR/id_rsa -N "$passphrase" -C "autossh"
        for i in "${!remote_hosts[@]}"; do
            host=${remote_hosts[$i]}
            user=${remote_users[$i]}
            echo "正在配置 $user@$host ..."
            if [ "$num1" -eq 4 ]; then
                password=${remote_passes[0]}
            fi
            if [ "$num1" -ne 4 ]; then 
                password=${remote_passes[$i]}
            fi
            sshpass -p "$password" ssh-copy-id -o StrictHostKeyChecking=no -i $KEY_DIR/id_rsa.pub $user@$host 
            if [ $? -ne 0 ]; then
                exit_code[$i]=0
                continue
            fi
            echo "密钥 $KEY_DIR/id_rsa.pub 已经成功复制到 $user@$host"
            exit_code[$i]=1
            if grep -q "$user@$host" "$KEY_DIR/host_list.txt"; then
                echo "主机已存在"
            else
                echo "$user@$host" >> "$KEY_DIR/host_list.txt"
                echo "添加 $user@$host 至 $KEY_DIR/host_list.txt 成功"
            fi
        done
        ;;
    3)
        echo "你选择了 退出程序"
        exit 0
        ;;
    *)
        echo "输入错误！必须是 1-3 之间的数字"
        exit 1
        ;;
esac
echo "---------执行结果-------------"
echo "-----------------------------"
echo -e "[\e[32mSUCCESS\e[0m]"
for i in "${!remote_hosts[@]}"; do
    if [ "${exit_code[$i]}" -ne 0 ]; then
        echo -e "\e[32m${remote_users[$i]}@${remote_hosts[$i]}\e[0m"
    fi
done
echo "-----------------------------"
echo -e "[\e[31mERROR\e[0m]"
for i in "${!remote_hosts[@]}"; do
    if [ "${exit_code[$i]}" -eq 0 ]; then
        echo -e "请检查\e[31m${remote_hosts[$i]}\e[0m 主机,IP,用户名以及密码,双方主机的SSH的服务状态及配置"
    fi
done
echo "-----------------------------"

