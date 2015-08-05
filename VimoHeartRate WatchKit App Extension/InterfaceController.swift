//
//  InterfaceController.swift
//  VimoHeartRate WatchKit App Extension
//
//  Created by Ethan Fan on 6/25/15.
//  Copyright © 2015 Vimo Lab. All rights reserved.
//

import Foundation
import HealthKit
import WatchKit


class InterfaceController: WKInterfaceController, HKWorkoutSessionDelegate {
    
    @IBOutlet private weak var label: WKInterfaceLabel!
    @IBOutlet private weak var deviceLabel : WKInterfaceLabel!
    @IBOutlet private weak var heart: WKInterfaceImage!
    
    let healthStore = HKHealthStore()
    
    // define the activity type and location
    let workoutSession = HKWorkoutSession(activityType: HKWorkoutActivityType.CrossTraining, locationType: HKWorkoutSessionLocationType.Indoor)
    let heartRateUnit = HKUnit(fromString: "count/min")
    var anchor = 0
    
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        workoutSession.delegate = self
    }
    
    override func willActivate() {
        super.willActivate()
        
        guard HKHealthStore.isHealthDataAvailable() == true else {
            label.setText("not available")
            print("HealthStore data is not available");
            return
        }
        print("HealthStore data is available");
    
        guard let quantityType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate) else {
            displayNotAllowed()
            return
        }
        
        let dataTypes = Set(arrayLiteral: quantityType)
        healthStore.requestAuthorizationToShareTypes(nil, readTypes: dataTypes) { (success, error) -> Void in
            if success == false {
                self.displayNotAllowed()
                print("Authorizatin allowed");
            }
        }
    }
    
    func displayNotAllowed() {
        label.setText("not allowed")
        print("Authorization not allowed");
    }
    
    func workoutSession(workoutSession: HKWorkoutSession, didChangeToState toState: HKWorkoutSessionState, fromState: HKWorkoutSessionState, date: NSDate) {
        switch toState {
        case .Running:
            workoutDidStart(date)
            print("Workout State : Running. Workout Start");
        case .Ended:
            workoutDidEnd(date)
            print("Workout State : Ended. Workout End");
        default:
            print("Unexpected state \(toState)")
        }
    }
    
    func workoutSession(workoutSession: HKWorkoutSession, didFailWithError error: NSError) {
        // Do nothing for now
    }
    
    func workoutDidStart(date : NSDate) {
        if let query = createHeartRateStreamingQuery(date) {
            healthStore.executeQuery(query)
        } else {
            label.setText("cannot start")
        }
    }
    
    func workoutDidEnd(date : NSDate) {
        if let query = createHeartRateStreamingQuery(date) {
            healthStore.stopQuery(query)
            label.setText("Stop")
        } else {
            label.setText("cannot stop")
        }
    }
    
    // MARK: - Actions
    @IBAction func startBtnTapped() {
        print("Start workout Session \(workoutSession)")
        healthStore.startWorkoutSession(workoutSession)
    }
    
    @IBAction func stopBtnTapped() {
        healthStore.endWorkoutSession(workoutSession)
    }
    
    func createHeartRateStreamingQuery(workoutStartDate: NSDate) -> HKQuery? {
        // adding predicate will not work
        // let predicate = HKQuery.predicateForSamplesWithStartDate(workoutStartDate, endDate: nil, options: HKQueryOptions.None)
        
        var anchorValue = Int(HKAnchoredObjectQueryNoAnchor)
        print("*****AnchorValue from NoAnchor \(anchorValue)")
        print("*****Anchor \(anchor)")
        if anchor != 0 {
            anchorValue = anchor
        }
        
        guard let quantityType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate) else { return nil }
        
        
        let heartRateQuery = HKAnchoredObjectQuery(type: quantityType, predicate: nil, anchor: anchorValue, limit: 0) { (query, sampleObjects, deletedObjects, newAnchor, error) -> Void in
            
            self.anchor = anchorValue
            print("*****Received Anchored Obj : \(anchorValue)")
            self.updateHeartRate(sampleObjects)
        }
        
        //print("Heart Rate Samples : \(heartRateSamples)")
        
        heartRateQuery.updateHandler = {(query, samples, deleteObjects, newAnchor, error) -> Void in
            self.anchor = newAnchor
            print("*****Update Handler : \(newAnchor)")
            self.updateHeartRate(samples)
        }
        return heartRateQuery
    }
    
    func updateHeartRate(samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample] else {return}
        
        print("Update Heart Rate")
        //print("Heart Rate Samples : \(heartRateSamples)")
        
        dispatch_async(dispatch_get_main_queue()) {
            guard let sample = heartRateSamples.first else{return}
            let value = sample.quantity.doubleValueForUnit(self.heartRateUnit)
            print("Qty from first object of sample : \(value)")
            
            self.label.setText(String(UInt16(value)))
            
            // retrieve source from sample
            let name = sample.sourceRevision.source.name
            self.updateDeviceName(name)
            self.animateHeart()
        }
    }
    
    func updateDeviceName(deviceName: String) {
        deviceLabel.setText(deviceName)
    }
    
    func animateHeart() {
        self.animateWithDuration(0.5) {
            self.heart.setWidth(60)
            self.heart.setHeight(90)
        }
        
        let when = dispatch_time(DISPATCH_TIME_NOW, Int64(0.5 * double_t(NSEC_PER_SEC)))
        let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
        dispatch_after(when, queue) {
            dispatch_async(dispatch_get_main_queue(), {
                self.animateWithDuration(0.5, animations: {
                    self.heart.setWidth(50)
                    self.heart.setHeight(80)
                })
            })
        }
    }
}
