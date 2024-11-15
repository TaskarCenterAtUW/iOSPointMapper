import numpy as np


class UnionFind:
    def __init__(self):
        self.parent = dict()

    def find(self, x):
        # Path compression
        if self.parent.get(x, x) != x:
            self.parent[x] = self.find(self.parent[x])
        return self.parent.get(x, x)

    def union(self, x, y):
        x_root = self.find(x)
        y_root = self.find(y)
        if x_root != y_root:
            # Union by smaller label for consistency
            if x_root < y_root:
                self.parent[y_root] = x_root
            else:
                self.parent[x_root] = y_root


def connected_components(mask):
    """
    Implement connected components labeling without OpenCV.

    :param mask: 2D numpy array, binary mask
    :return: num_labels, labels_im
    """
    labels_im = np.zeros_like(mask, dtype=int)
    label = 1
    uf = UnionFind()
    rows, cols = mask.shape

    # Define 8-connected neighborhood
    neighbors = [(-1, -1), (-1, 0), (-1, 1), (0, -1)]

    for i in range(rows):
        for j in range(cols):
            if mask[i, j]:
                neighbor_labels = []
                for dx, dy in neighbors:
                    x, y = i + dx, j + dy
                    if 0 <= x < rows and 0 <= y < cols and labels_im[x, y] > 0:
                        neighbor_labels.append(labels_im[x, y])
                if not neighbor_labels:
                    # Assign new label
                    labels_im[i, j] = label
                    label += 1
                else:
                    min_label = min(neighbor_labels)
                    labels_im[i, j] = min_label
                    # Union equivalent labels
                    for lbl in neighbor_labels:
                        uf.union(min_label, lbl)

    # Second pass: relabel components
    label_map = {}
    new_label = 1
    for i in range(rows):
        for j in range(cols):
            if labels_im[i, j] > 0:
                root_label = uf.find(labels_im[i, j])
                if root_label not in label_map:
                    label_map[root_label] = new_label
                    new_label += 1
                labels_im[i, j] = label_map[root_label]

    num_labels = new_label
    return num_labels, labels_im


def merge_mask(mask: np.ndarray, depth_map: np.ndarray, depth_threshold: float = 0.5):
    """
    Merge clusters in the mask based on depth similarity without using OpenCV.

    :param mask: 2D numpy array, the mask
    :param depth_map: 2D numpy array, the depth map
    :param depth_threshold: float, the depth threshold for merging clusters
    :return: 2D numpy array, the merged mask
    """

    # Get connected components
    num_labels, labels_im = connected_components((mask > 0))

    # Calculate mean depth for each label
    cluster_depths = {}
    for label in range(1, num_labels):
        cluster_mask = labels_im == label
        cluster_depth = np.mean(depth_map[cluster_mask])
        cluster_depths[label] = cluster_depth

    # Merge clusters based on depth threshold
    uf_depth = UnionFind()
    labels = list(cluster_depths.keys())
    for i in range(len(labels)):
        for j in range(i + 1, len(labels)):
            label_i, label_j = labels[i], labels[j]
            depth_i, depth_j = cluster_depths[label_i], cluster_depths[label_j]
            if abs(depth_i - depth_j) < depth_threshold:
                uf_depth.union(label_i, label_j)

    # Relabel components after merging
    label_map = {}
    new_label = 1
    for label in range(1, num_labels):
        root_label = uf_depth.find(label)
        if root_label not in label_map:
            label_map[root_label] = new_label
            new_label += 1

    # Update labels_im with merged labels
    rows, cols = labels_im.shape
    for i in range(rows):
        for j in range(cols):
            if labels_im[i, j] > 0:
                labels_im[i, j] = label_map[uf_depth.find(labels_im[i, j])]

    return labels_im
