//
//  Team.swift
//  Hackathon
//
//  Created by John Gallaugher on 4/11/20.
//  Copyright © 2020 John Gallaugher. All rights reserved.
//

import Foundation
import CoreLocation
import Firebase
import MapKit

class Team: NSObject, MKAnnotation {
    var teamName: String
    var university: String
    var coordinate: CLLocationCoordinate2D
    var projectName: String
    var projectDescription: String
    var appImage: UIImage
    var appImageUUID: String
    var createdOn: Date
    var postingUserID: String
    var documentID: String

    var latitude: CLLocationDegrees {
        return coordinate.latitude
    }

    var longitude: CLLocationDegrees {
        return coordinate.longitude
    }
    
    var title: String? {
        return teamName
    }
    
    var subtitle: String? {
        return university
    }
    
    var dictionary: [String: Any] {
        // Convert from Apple date to a TimeInterval
        let timeIntervalDate = createdOn.timeIntervalSince1970
        return ["teamName": teamName, "university": university, "latitude": latitude, "longitude": longitude, "projectName": projectName, "projectDescription": projectDescription, "appImageUUID": appImageUUID, "createdOn": timeIntervalDate, "postingUserID": postingUserID, "documentID":documentID]
    }
    
    init(teamName: String, university: String, coordinate: CLLocationCoordinate2D, projectName: String, projectDescription: String, appImage: UIImage, appImageUUID: String, createdOn: Date, postingUserID: String, documentID: String) {
        self.teamName = teamName
        self.university = university
        self.coordinate = coordinate
        self.projectName = projectName
        self.projectDescription = projectDescription
        self.appImage = appImage
        self.appImageUUID = appImageUUID
        self.createdOn = createdOn
        self.postingUserID = postingUserID
        self.documentID = documentID
    }
    
    convenience init(dictionary: [String: Any]) {
        let teamName = dictionary["teamName"] as! String? ?? ""
        let university = dictionary["university"] as! String? ?? ""
        let latitude = dictionary["latitude"] as! CLLocationDegrees? ?? 0.0
        let longitude = dictionary["longitude"] as! CLLocationDegrees? ?? 0.0
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let projectName = dictionary["projectName"] as! String? ?? ""
        let projectDescription = dictionary["projectDescription"] as! String? ?? ""
        let appImageUUID = dictionary["appImageUUID"] as! String? ?? ""
        let timeIntervalDate = dictionary["createdOn"] as! TimeInterval? ?? TimeInterval()
        let createdOn = Date(timeIntervalSince1970: timeIntervalDate)
        let postingUserID = dictionary["postingUserID"] as! String? ?? ""
        self.init(teamName: teamName, university: university, coordinate: coordinate, projectName: projectName, projectDescription: projectDescription, appImage: UIImage(), appImageUUID: appImageUUID, createdOn: createdOn, postingUserID: postingUserID, documentID: "")
    }
    
    convenience override init() {
        self.init(teamName: "", university: "", coordinate: CLLocationCoordinate2D(), projectName: "", projectDescription: "", appImage: UIImage(), appImageUUID: "", createdOn: Date(), postingUserID: "", documentID: "")
    }
    
        // NOTE: If you keep the same programming conventions (e.g. a calculated property .dictionary that converts class properties to String: Any pairs, the name of the document stored in the class as .documentID) then the only thing you'll need to change is the document path (i.e. the lines containing "teams" below.
    func saveData(completion: @escaping (Bool) -> ())  {
        let db = Firestore.firestore()
        // Grab the user ID
        guard let postingUserID = (Auth.auth().currentUser?.uid) else {
            print("*** ERROR: Could not save data because we don't have a valid postingUserID")
            return completion(false)
        }
        self.postingUserID = postingUserID
        // Create the dictionary representing data we want to save
        let dataToSave: [String: Any] = self.dictionary
        // if we HAVE saved a record, we'll have an ID
        if self.documentID != "" {
            let ref = db.collection("teams").document(self.documentID)
            ref.setData(dataToSave) { (error) in
                if let error = error {
                    print("ERROR: updating document \(error.localizedDescription)")
                    completion(false)
                } else { // It worked!
                    completion(true)
                }
            }
        } else { // Otherwise create a new document via .addDocument
            var ref: DocumentReference? = nil // Firestore will creat a new ID for us
            ref = db.collection("teams").addDocument(data: dataToSave) { (error) in
                if let error = error {
                    print("ERROR: adding document \(error.localizedDescription)")
                    completion(false)
                } else { // It worked! Save the documentID in Team's documentID property
                    self.documentID = ref!.documentID
                    completion(true)
                }
            }
        }
    }
    
    func saveImage(completed: @escaping (Bool) -> ()) {
        let db = Firestore.firestore()
        let storage = Storage.storage()
        // convert appImage to a Data type so it can be saved by Firebase Storage
        guard let imageToSave = self.appImage.jpegData(compressionQuality: 0.5) else {
            print("😡 ERROR: could not convert image to data format.")
            return
        }
        
        let uploadMetaData = StorageMetadata()
        uploadMetaData.contentType = "image/jpeg"
        if appImageUUID == "" {
            // if there's no UUID, then create one
            appImageUUID = UUID().uuidString
        }
        // create a ref to upload storage with the uuID we created
        let storageRef = storage.reference().child(documentID).child(self.appImageUUID)
        let uploadTask = storageRef.putData(imageToSave, metadata: uploadMetaData) { (metadata, error) in
            guard error == nil else {
                print("😡 ERROR: during .putData storage upload for reference \(storageRef). Error = \(error?.localizedDescription)")
                completed(false)
                return
            }
            print("😎 Upload worked! Metadata is \(metadata)")
        }
        
        uploadTask.observe(.success) { (snapshot) in
            // Create the dictionary representing the data we want to save
            let dataToSave = self.dictionary// This will either create a new doc at documentUUID or update the existing doc with that name
            let ref = db.collection("teams").document(self.documentID)
            ref.setData(dataToSave) { (error) in
                if let error = error {
                    print("ERROR: updating doc \(self.appImageUUID) in documentID \(self.documentID). Error = \(error.localizedDescription)")
                    completed(false)
                } else {
                    print("👍🏽 Docuent updated with ref ID \(ref.documentID)")
                    completed(true)
                }
            }
        }
        
        uploadTask.observe(.failure) { (snapshot) in
            if let error = snapshot.error {
                print("ERROR: \(error.localizedDescription) upload task for file \(self.appImageUUID) failed in document \(self.documentID)")
            }
            return completed(false)
        }
    }
}
