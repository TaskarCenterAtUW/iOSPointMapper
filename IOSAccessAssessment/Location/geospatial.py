from typing import Tuple
from math import radians, sin, cos

import numpy as np
from pyproj import CRS, Transformer


def move_point(
    lat0: float, lon0: float, delta_north_m: float, delta_east_m: float
) -> Tuple[float, float]:
    """
    Move a point from the given latitude and longitude by specified distances in meters.

    Parameters:
    - lat0: float, starting latitude in degrees.
    - lon0: float, starting longitude in degrees.
    - delta_north_m: float, distance to move northward in meters.
    - delta_east_m: float, distance to move eastward in meters.

    Returns:
    - lat1: float, new latitude in degrees after moving.
    - lon1: float, new longitude in degrees after moving.
    """
    # Define a local Transverse Mercator projection centered at the starting point
    proj_string = (
        f"+proj=tmerc +lat_0={lat0} +lon_0={lon0} " "+k=1 +x_0=0 +y_0=0 +ellps=WGS84"
    )
    local_crs = CRS.from_proj4(proj_string)
    wgs84_crs = CRS.from_epsg(4326)

    # Create transformers for forward and inverse transformations
    transformer_to_local = Transformer.from_crs(wgs84_crs, local_crs)
    transformer_to_wgs84 = Transformer.from_crs(local_crs, wgs84_crs)

    # Transform the starting point to local coordinates (meters)
    x0, y0 = transformer_to_local.transform(lon0, lat0)

    # Apply the movement in meters
    x1 = x0 + delta_east_m
    y1 = y0 + delta_north_m

    # Transform back to geographic coordinates
    lon1, lat1 = transformer_to_wgs84.transform(x1, y1)

    return lat1, lon1


def get_location(
    depth_map: np.ndarray,
    center: Tuple[int, int],
    yaw: float,
    observer_latitude: float,
    observer_longitude: float,
    hfov: float = 90,
) -> Tuple[float, float]:
    """
    Get the latitude and longitude of a point in the depth map knowing
    the observer's location and orientation.

    :param depth_map: 2D numpy array, depth values in meters
    :param center: tuple (X, Y) of the point location in pixels
    :param yaw: float, yaw of the camera relative to the north clockwise, in degrees
    :param observer_latitude: float, latitude of the camera, in degrees
    :param observer_longitude: float, longitude of the camera, in degrees
    :param hfov: float, horizontal field of view of the camera, in degrees
    :return: tuple (latitude, longitude) of the point location in degrees
    """
    yaw = yaw % 360
    X, Y = center
    depth = depth_map[int(Y), int(X)]
    height, width = depth_map.shape

    in_camera_angle = (X / width - 0.5) * hfov
    object_angle = yaw + in_camera_angle
    radians_object_angle = radians(object_angle)

    longitudal_distance = depth * cos(radians_object_angle)
    latitudal_distance = depth * sin(radians_object_angle)

    lat, lon = move_point(
        observer_latitude, observer_longitude, latitudal_distance, longitudal_distance
    )

    return lat, lon
