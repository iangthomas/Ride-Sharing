//
//  PageViewDemo
//
//  Created by Simon on 24/11/13.
//  Copyright (c) 2013 Appcoda. All rights reserved.
//

//  Code Modifications © 2017 Geodex Systems
//  All Rights Reserved.

#import <UIKit/UIKit.h>

@interface TutPageContentViewController : UIViewController
@property (weak, nonatomic) IBOutlet UIImageView *backgroundImageView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *bottomLabel;

@property (strong, nonatomic) IBOutlet UIButton *skipLogin;

@property (strong, nonatomic) IBOutlet UIButton *getStartedButton;
//@property (weak, nonatomic) IBOutlet UILabel *swipeToContinueLabel;
//@property (weak, nonatomic) IBOutlet UIButton *notificationsButton;
@property (weak, nonatomic) IBOutlet UIButton *nextButton;
@property (strong, nonatomic) IBOutlet UIButton *skipTutorialButton;


- (IBAction)nextButton:(id)sender;
- (IBAction)getStarted:(id)sender;

@property NSUInteger pageIndex;
@property NSString *titleText;
@property NSString *imageFile;
@property NSString *pageType;

@end
