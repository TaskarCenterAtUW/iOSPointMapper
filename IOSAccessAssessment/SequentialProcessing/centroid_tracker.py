from collections import OrderedDict
import numpy as np


class CentroidTracker:
    def __init__(self, maxDisappeared=5):
        # initialize the next unique object ID along with two ordered
        # dictionaries used to keep track of mapping a given object
        # ID to its centroid and number of consecutive frames it has
        # been marked as "disappeared", respectively
        self.nextObjectID = 0
        self.objects = OrderedDict()
        self.object_class_and_distance = OrderedDict()
        self.disappeared = OrderedDict()

        # store the number of maximum consecutive frames a given
        # object is allowed to be marked as "disappeared" until we
        # need to deregister the object from tracking
        self.maxDisappeared = maxDisappeared

    def register(
        self,
        object_name,
        object_centroid,
        object_poly,
        object_distance,
        object_width,
        object_heading,
    ):
        # when registering an object we use the next available object
        # ID to store the centroid

        # self.objects[self.nextObjectID] = centroid
        object_dict = {}
        object_dict["object_name"] = object_name
        object_dict["object_centroid"] = object_centroid
        object_dict["object_poly"] = object_poly
        object_dict["object_distance"] = object_distance
        object_dict["object_width"] = object_width
        object_dict["object_heading"] = object_heading

        self.objects[self.nextObjectID] = object_dict
        self.disappeared[self.nextObjectID] = 0
        self.nextObjectID += 1

    def deregister(self, objectID):
        # to deregister an object ID we delete the object ID from
        # both of our respective dictionaries
        del self.objects[objectID]
        del self.disappeared[objectID]

    def update(self, object_list_dict):
        inputCentroids = object_list_dict["object_centroids"]
        inputPolys = object_list_dict["object_polys"]
        inputNames = object_list_dict["object_names"]
        inputDistances = object_list_dict["object_distances"]
        inputWidths = object_list_dict["object_widths"]
        inputHeadings = object_list_dict["headings"]

        # check to see if the list of input bounding box rectangles
        # is empty
        if len(inputCentroids) == 0:
            # loop over any existing tracked objects and mark them
            # as disappeared
            for objectID in list(self.disappeared.keys()):
                self.disappeared[objectID] += 1

                # if we have reached a maximum number of consecutive
                # frames where a given object has been marked as
                # missing, deregister it
                if self.disappeared[objectID] > self.maxDisappeared:
                    self.deregister(objectID)

            # return early as there are no centroids or tracking info
            # to update
            return self.objects, self.disappeared

        # if we are currently not tracking any objects take the input
        # centroids and register each of them
        if len(self.objects) == 0:
            for i in range(0, len(inputCentroids)):
                self.register(
                    inputNames[i],
                    inputCentroids[i],
                    inputPolys[i],
                    inputDistances[i],
                    inputWidths[i],
                    inputHeadings[i],
                )

        # otherwise, are are currently tracking objects so we need to
        # try to match the input centroids to existing object
        # centroids
        else:
            # grab the set of object IDs and corresponding centroids
            objectIDs = list(self.objects.keys())
            objectCentroids = list(
                object_dict["object_centroid"] for object_dict in self.objects.values()
            )

            # compute the distance between each pair of object
            # centroids and input centroids, respectively -- our
            # goal will be to match an input centroid to an existing
            # object centroid

            # Convert centroids to NumPy arrays
            objectCentroids = np.array(objectCentroids)
            inputCentroids = np.array(inputCentroids)

            # Compute the Euclidean distance between each pair of centroids
            D = np.linalg.norm(
                objectCentroids[:, np.newaxis, :] - inputCentroids[np.newaxis, :, :],
                axis=2,
            )

            # in order to perform this matching we must (1) find the
            # smallest value in each row and then (2) sort the row
            # indexes based on their minimum values so that the row
            # with the smallest value as at the *front* of the index
            # list
            rows = D.min(axis=1).argsort()

            # next, we perform a similar process on the columns by
            # finding the smallest value in each column and then
            # sorting using the previously computed row index list
            cols = D.argmin(axis=1)[rows]

            # in order to determine if we need to update, register,
            # or deregister an object we need to keep track of which
            # of the rows and column indexes we have already examined
            usedRows = set()
            usedCols = set()

            # loop over the combination of the (row, column) index
            # tuples
            for row, col in zip(rows, cols):
                # (existing object, input object)

                # threshold D to prevent merging far objects
                if D[row, col] > 50:
                    continue

                # if we have already examined either the row or
                # column value before, ignore it
                if row in usedRows or col in usedCols:
                    continue

                # otherwise, grab the object ID for the current row,
                # set its new centroid, and reset the disappeared
                # counter
                objectID = objectIDs[row]
                self.objects[objectID]["object_centroid"] = inputCentroids[col]
                self.objects[objectID]["object_name"] = inputNames[col]
                self.objects[objectID]["object_poly"] = inputPolys[col]
                self.objects[objectID]["object_distance"] = inputDistances[col]
                self.objects[objectID]["object_width"] = inputWidths[col]
                self.objects[objectID]["object_heading"] = inputHeadings[col]

                self.disappeared[objectID] = 0

                # indicate that we have examined each of the row and
                # column indexes, respectively
                usedRows.add(row)
                usedCols.add(col)

            # compute both the row and column index we have NOT yet
            # examined
            unusedRows = set(range(0, D.shape[0])).difference(usedRows)
            unusedCols = set(range(0, D.shape[1])).difference(usedCols)

            # in the event that the number of object centroids is
            # equal or greater than the number of input centroids
            # we need to check and see if some of these objects have
            # potentially disappeared
            if D.shape[0] >= D.shape[1]:
                # loop over the unused row indexes
                for row in unusedRows:
                    # grab the object ID for the corresponding row
                    # index and increment the disappeared counter
                    objectID = objectIDs[row]
                    self.disappeared[objectID] += 1

                    # check to see if the number of consecutive
                    # frames the object has been marked "disappeared"
                    # for warrants deregistering the object
                    if self.disappeared[objectID] > self.maxDisappeared:
                        self.deregister(objectID)

            # otherwise, if the number of input centroids is greater
            # than the number of existing object centroids we need to
            # register each new input centroid as a trackable object
            else:
                for col in unusedCols:
                    self.register(
                        inputNames[col],
                        inputCentroids[col],
                        inputPolys[col],
                        inputDistances[col],
                        inputWidths[col],
                        inputHeadings[col],
                    )

        # return the set of trackable objects
        return self.objects, self.disappeared
