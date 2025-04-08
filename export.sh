#!/bin/bash

# 定义导出目录路径
EXPORT_DIR="export"

# 创建导出目录（如果不存在）
mkdir -p "$EXPORT_DIR"

# 获取所有镜像的列表
IMAGES=$(ctr -n k8s.io images list -q)

# 遍历每个镜像并导出
for IMAGE in $IMAGES; do
    # 生成适合的文件名
    FILENAME=$(echo $IMAGE | tr '/' '-' | tr ':' '-')

    echo "正在导出镜像: $IMAGE 到 $EXPORT_DIR/${FILENAME}.tar"

    # 导出镜像
    ctr -n k8s.io images export "$EXPORT_DIR/${FILENAME}.tar" "$IMAGE"

    echo "导出完成: $EXPORT_DIR/${FILENAME}.tar"
done

echo "所有镜像导出完成。"

