//
//  CentroidTracker.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/7/25.
//

import OrderedCollections

class CentroidTracker {
    
    private var nextObjectID: Int;
    private var objects: OrderedDictionary<Int, Dictionary<String, Any>>;
    private var disappearedObjects: OrderedDictionary<Int, Int>;
    
    var maxDisappeared: Int;
    
    init(maxDisappeared: Int) {
        self.nextObjectID = 0
        self.objects = OrderedDictionary()
        self.disappearedObjects = OrderedDictionary()
        self.maxDisappeared = maxDisappeared
    }
    
    func register(object_name: String, object_centroid: (Int, Int), object_polygon: Array<CGPoint>,
                  object_location: (Float, Float), object_heading: Float, object_width: Float) {
        let object: Dictionary<String, Any> = [
            "name": object_name,
            "centroid": object_centroid,
            "polygon": object_polygon,
            "location": object_location,
            "heading": object_heading,
            "width": object_width
        ]
        self.objects[nextObjectID] = object
        self.disappearedObjects[nextObjectID] = 0
        
        nextObjectID += 1
    }
    
    func deregister(objectID: Int) {
        self.objects.removeValue(forKey: objectID)
        self.disappearedObjects.removeValue(forKey: objectID)
    }
    
    func update(objects_list: Array<Dictionary<String, Any>>) ->
    (objects: OrderedDictionary<Int, Dictionary<String, Any>>, disappearedObjects: OrderedDictionary<Int, Int>) {
        return (objects: self.objects, disappearedObjects: self.disappearedObjects)
    }
    
    
}
