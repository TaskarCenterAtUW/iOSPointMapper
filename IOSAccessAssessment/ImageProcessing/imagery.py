import numpy as np


def compute_centroid(mask, depth_map, sidewalk_label=1):
    """
    Compute the centroid of the sidewalk mask.

    :param mask: 2D numpy array, the sidewalk mask
    :param depth_map: 2D numpy array, depth values in meters
    :param sidewalk_label: int, the label of the sidewalk in the mask
    :return: tuple (X, Y) of the centroid location in pixels
    """

    assert mask.shape == depth_map.shape

    indices = np.where(mask == sidewalk_label)
    X = indices[1]
    Y = indices[0]
    Z = depth_map[Y, X]

    centroid = (np.median(X), np.median(Y))

    return centroid


def compute_sidewalk_width(mask, depth_map, centroid):
    """
    Compute the physical width of the sidewalk at the centroid location.

    :param mask: 2D numpy array, the sidewalk mask
    :param depth_map: 2D numpy array, depth values in meters
    :param centroid: tuple (X, Y) of the centroid location in pixels
    :return: physical width in meters
    """
    centroid_x, centroid_y = int(centroid[0]), int(centroid[1])

    # Find the leftmost and rightmost sidewalk pixels
    sidewalk_row = mask[centroid_y, :]
    sidewalk_indices = np.where(sidewalk_row > 0)[0]

    if len(sidewalk_indices) < 2:
        print("Cannot find sidewalk edges at the centroid location")
        return 0

    side = depth_map[centroid_y, centroid_x]

    left_pixel = sidewalk_indices[0]
    right_pixel = sidewalk_indices[-1]
    left_estimate = np.sqrt(depth_map[centroid_y, left_pixel] ** 2 - side**2)
    right_estimate = np.sqrt(depth_map[centroid_y, right_pixel] ** 2 - side**2)

    width = (right_estimate + left_estimate) / 2

    return width
