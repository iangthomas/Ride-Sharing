//
//  Constants.m
//
//  Created by Ian Thomas on 7/15/15.
//
//
//  Copyright © 2016 Geodex Systems. All rights reserved.
//  

#import <Foundation/Foundation.h>
//#import <Crashlytics/Crashlytics.h>

#import "Constants.h"
#include <sys/types.h>
#include <sys/sysctl.h>

//static int methodCallCount = 0;
static NSString* theLog;
static NSString* idInfo;


@implementation Constants


+(void) debug: (NSNumber*) level withContent:(NSString*) content {
    
#warning re-enable crashlytics later
    /*
    NSInteger temp = debugLvl;
    if (level.integerValue >= temp) {
        CLS_LOG(@"%@", content);
        // Level 3 Very Little (Warnings Only)
        // Level 2 Some (Debug)
        // Level 1 Everything (Verbose)
    }
    
    if (theLog == nil) {
        theLog = content;
    } else {
        theLog = [theLog stringByAppendingString:[NSString stringWithFormat:@"%@\n", content]];
    }
    
    idInfo = [[NSUserDefaults standardUserDefaults] objectForKey:kAppIDNumber];
    if ([idInfo isEqualToString:@""]) {
        
        NSNumber * randNumber = [NSNumber numberWithFloat: (arc4random()%10000000)+1];
        idInfo = [NSString stringWithFormat:@"%i", randNumber.intValue];
        
        [[NSUserDefaults standardUserDefaults] setObject:idInfo forKey:kAppIDNumber];
    }
     */
}


+(NSString *) platform {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithUTF8String:machine];
    free(machine);
    return platform;
}


+(void)makeErrorReportWithDescription:(NSString*) theDescription {

    FIRDatabaseReference *errorDir = [[[FIRDatabase database] reference] child:@"errorReports"];
    
    NSMutableDictionary *theError = [[NSMutableDictionary alloc] init];
        
    UIDevice *currentDevice = [UIDevice currentDevice];
    theError[@"description"] = theDescription;
    theError[@"AppVersion"] = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    theError[@"BuildNumber"] = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBuildNumber"];
    theError[@"Device_Type"] = [currentDevice model];
    theError[@"System_Version"] = [currentDevice systemVersion];
    theError[@"platform"] = [self platform];
    
#if DEBUG == 1
    theError[@"is_DeveloperViaDebug"] = @YES;
#else
    theError[@"is_DeveloperViaDebug"] = @NO;
#endif

    
    theError[@"debugLog"] = theLog;

    theError[@"appUserID"] = [[NSUserDefaults standardUserDefaults] objectForKey:kAppUserID];
    
    theError[@"numTimesAppLaunched"] = [[NSUserDefaults standardUserDefaults] objectForKey:kNumLaunchesKey];
    
    
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    if (state == UIApplicationStateBackground) {
        theError[@"UIApplicationStateCurrently"] = @"UIApplicationStateBackground";
    } else if (state == UIApplicationStateInactive) {
        theError[@"UIApplicationStateCurrently"] = @"UIApplicationStateInactive";
    } else if (state == UIApplicationStateActive) {
        theError[@"UIApplicationStateCurrently"] = @"UIApplicationStateActive";
    }
    
    [Constants debug:@3 withContent:@"Attempting to Send Error Report"];

    [[errorDir childByAutoId] setValue:theError withCompletionBlock:^(NSError * error, FIRDatabaseReference * ref) {
        
        if (!error) {
            [Constants debug:@2 withContent:@"Error Report Successfully Sent"];
        } else {
            [Constants debug:@3 withContent:@"ERROR: Failed to send Error Report"];
            [Constants makeErrorReportWithDescription:error.localizedDescription];
        }
    }];
}


+(UIColor*)flockGreen {
    return [UIColor colorWithRed:0.29 green:0.78 blue:0.69 alpha:1.0];
}


+(UIColor*)flockOrange {
    return [UIColor colorWithRed:0.93 green:0.51 blue:0.23 alpha:1.0];
}


+(NSDateFormatter*) internetTimeDateFormatter {

    NSDateFormatter* formatter  = [[NSDateFormatter alloc] init];
    
    // these two lines solve an insane bug: one that causes the all the dates and times to fail if the date is in 24 hour time while the device is in 12 hour time
    [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    [formatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];

    return formatter;
}


@end


