import numpy as np


def erosion(image, kernel):
    """
    Perform morphological erosion on a binary image using the given kernel.

    :param image: 2D numpy array, binary input image
    :param kernel: 2D numpy array, structuring element
    :return: 2D numpy array, eroded image
    """
    k_h, k_w = kernel.shape
    pad_h, pad_w = k_h // 2, k_w // 2

    # Pad the image to handle borders
    image_padded = np.pad(
        image, ((pad_h, pad_h), (pad_w, pad_w)), mode="constant", constant_values=0
    )

    eroded_image = np.zeros_like(image)
    for i in range(eroded_image.shape[0]):
        for j in range(eroded_image.shape[1]):
            # Extract the region of interest
            region = image_padded[i : i + k_h, j : j + k_w]
            # Apply erosion (minimum operation)
            if np.all(region[kernel == 1] == 1):
                eroded_image[i, j] = 1
            else:
                eroded_image[i, j] = 0
    return eroded_image


def dilation(image, kernel):
    """
    Perform morphological dilation on a binary image using the given kernel.

    :param image: 2D numpy array, binary input image
    :param kernel: 2D numpy array, structuring element
    :return: 2D numpy array, dilated image
    """
    k_h, k_w = kernel.shape
    pad_h, pad_w = k_h // 2, k_w // 2

    # Pad the image to handle borders
    image_padded = np.pad(
        image, ((pad_h, pad_h), (pad_w, pad_w)), mode="constant", constant_values=0
    )

    dilated_image = np.zeros_like(image)
    for i in range(dilated_image.shape[0]):
        for j in range(dilated_image.shape[1]):
            # Extract the region of interest
            region = image_padded[i : i + k_h, j : j + k_w]
            # Apply dilation (maximum operation)
            if np.any(region[kernel == 1] == 1):
                dilated_image[i, j] = 1
            else:
                dilated_image[i, j] = 0
    return dilated_image


def opening(image, kernel):
    """
    Perform morphological opening on a binary image using the given kernel.

    :param image: 2D numpy array, binary input image
    :param kernel: 2D numpy array, structuring element
    :return: 2D numpy array, image after opening
    """
    return dilation(erosion(image, kernel), kernel)


def closing(image, kernel):
    """
    Perform morphological closing on a binary image using the given kernel.

    :param image: 2D numpy array, binary input image
    :param kernel: 2D numpy array, structuring element
    :return: 2D numpy array, image after closing
    """
    return erosion(dilation(image, kernel), kernel)


def clean_mask(mask, kernel_size: int = 5):
    """
    Clean the mask using morphological opening and closing operations.

    :param mask: 2D numpy array, the mask
    :param kernel_size: int, the size of the structuring element
    :return: 2D numpy array, the cleaned mask
    """
    kernel = np.ones((kernel_size, kernel_size), dtype=np.uint8)
    # Ensure the mask is binary
    mask = (mask > 0).astype(np.uint8)
    # Apply morphological operations
    mask_cleaned = opening(mask, kernel)
    mask_cleaned = closing(mask_cleaned, kernel)
    return mask_cleaned


def depth_clean_mask(mask, depth_map, sidewalk_label=1, depth_threshold=0.25):
    """
    Remove the parts of the mask that have depth values significantly different from the rest of the sidewalk.

    :param mask: 2D numpy array, the mask
    :param depth_map: 2D numpy array, the depth map
    :param depth_threshold: float, the depth threshold for removing parts of the mask
    :param sidewalk_label: int, the label of the sidewalk in the mask
    :return: 2D numpy array, the cleaned mask
    """
    mean_depth = np.mean(depth_map[mask == sidewalk_label])
    mask_cleaned = mask.copy()
    mask_cleaned = np.where(
        np.abs(depth_map - mean_depth) > depth_threshold, 0, mask_cleaned
    )

    return mask_cleaned
