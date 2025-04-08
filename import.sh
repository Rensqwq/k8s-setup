#!/bin/bash
# wget https://s3.frp.tiusolution.com/k8s/packages/export.tar.gz
# tar xvzf export.tar.gz

IMPORT_DIR="export"

# 切换到保存镜像的目录
cd "$IMPORT_DIR"

# 遍历所有的 tar 文件并导入
for TAR_FILE in *.tar; do
    echo "正在导入镜像: $TAR_FILE"
    
    # 导入镜像
    ctr -n k8s.io images import "$TAR_FILE"
    
    echo "导入完成: $TAR_FILE"
done

echo "所有镜像导入完成。"

