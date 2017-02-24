//
//  SystemStatusViewController.h
//  Nimbus
//
//  Created by Ian Thomas on 11/7/15.
//  Code Modifications © 2017 Geodex Systems.  All Rights Reserved.
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>


@interface SystemStatusViewController : UIViewController

@property (nonatomic) CBCentralManager *myCentralManager;
@property (nonatomic, assign) BOOL showHiddenStuff;

@end
