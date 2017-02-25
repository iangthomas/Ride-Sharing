//
//  Constants.h
//
//  Created by Ian Thomas on 7/1/15.
//  Copyright © 2016 Geodex Systems. All rights reserved.
//

#import <Firebase.h>

#ifndef nimbustest_Constants_h
#define nimbustest_Constants_h

// Device Size Vaiables
#define IS_IPAD (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
#define IS_IPHONE (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
#define IS_IPHONE_5 (IS_IPHONE && [[UIScreen mainScreen] bounds].size.height == 568.0f)
#define IS_RETINA ([[UIScreen mainScreen] scale] == 2.0f)


#define kauto_crash_reporting @"auto_crash_reporting"
#define kauto_anonymous_stats @"auto_anonymous_stats"
#define kUserStatusMode @"userStatusMode"
#define kNumLaunchesKey @"numTimesAppLaunched"

// Unique User Variables
#define kAppUserID @"appUserID"

// Standard Server Communication Variables.
#define kDriverCancelled @"driverCancelled"
#define kPassengerCancelled @"passengerCancelled"
#define kPickedUpPassenger @"pickedUpPassenger"
#define kStatus @"status"
#define kAccepted @"accepted"
#define kPassed @"passed"
#define kPassengerDroppedOff @"passengerDroppedOff"
#define kNoAvailableDrivers @"noAvailableDrivers"
#define kEveryonePassed @"everyonePassed"
#define kNoResponse @"noResponse"
#define kLatitude @"latitude"
#define kLongitude @"longitude"

// On Device Communication Variables.
#define KmodePassanger 0
#define KmodeDriver 1

#define debugLvl 3
// Level 1 Everything (Verbose)
// Level 2 Some (Debug)
// Level 3 Very Litte (Warnings)

#endif


@interface Constants: NSObject

+(void) debug: (NSNumber*) level withContent:(NSString*) content;
+(void)makeErrorReportWithDescription:(NSString*) theDescription;
+(NSString *) platform;


+(UIColor*)flockGreen;
+(UIColor*)flockOrange;

+(NSDateFormatter*) internetTimeDateFormatter;


@end
