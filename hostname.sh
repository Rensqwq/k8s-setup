#!/bin/bash

# 确保脚本以root权限运行
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# 请求用户输入数字，并存储在变量中
read -p "请输入数字以更改hostname为jcjy-ai-xxx，其中xxx是你的数字: " number

# 定义新的hostname
new_hostname="jcjy-ai-$number"

# 更改/etc/hostname文件
echo $new_hostname > /etc/hostname

# 更改/etc/hosts文件
sed -i "s/jcjy-ai-installing/$new_hostname/g" /etc/hosts

# 应用新的hostname
hostname $new_hostname

echo "Hostname已更改为$new_hostname"
