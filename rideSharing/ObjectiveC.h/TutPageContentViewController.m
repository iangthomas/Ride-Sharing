//
//  PageViewDemo
//
//  Created by Simon on 24/11/13.
//  Copyright (c) 2013 Appcoda. All rights reserved.
//

//  Code Modifications © 2017 Geodex Systems
//  All Rights Reserved.


// From Nimbus / Geodex 1.3 ish

#import "TutPageContentViewController.h"
//#import <Parse/Parse.h>
//#import "AppDelegate.h"
#import "Constants.h"
//#import "SWRevealViewController.h"
//#import <Crashlytics/Crashlytics.h>
//#import "SystemStatusViewController.h"

@interface TutPageContentViewController ()

@end

@implementation TutPageContentViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}


-(void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [Constants debug:@2 withContent:@"TutPageContentViewController Appearing"];
}


-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [Constants debug:@2 withContent:@"TutPageContentViewController Disappearing"];
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    _nextButton.tintColor = [UIColor whiteColor];
    
    self.view.backgroundColor = [Constants flockGreen];
    
    
    self.titleLabel.text = self.titleText;
        
    if ([self.pageType isEqualToString:@"Welcome"]) {
        
        self.getStartedButton.hidden = YES;
     //   self.nextButton.hidden = NO;
      //  self.bottomLabel.text = @"Lets Get Started.";
        
        self.nextButton.hidden = YES;
        self.skipTutorialButton.hidden = NO;

       // [self.backgroundImageView removeFromSuperview];
        
       // border
        self.backgroundImageView.image = [UIImage imageNamed:self.imageFile];


        
    } else if ([self.pageType isEqualToString:@"Map"]) {
        
        self.getStartedButton.hidden = YES;
      //  self.nextButton.hidden = NO;
     //   self.bottomLabel.text = @"You can tap to see deal details.";
        //self.bottomLabel.text = @"";
        self.nextButton.hidden = YES;
        self.skipTutorialButton.hidden = NO;

        self.backgroundImageView.image = [UIImage imageNamed:self.imageFile];
        
    } else if ([self.pageType isEqualToString:@"Deal"]) {

        self.getStartedButton.hidden = YES;
     //   self.nextButton.hidden = NO;
       // self.bottomLabel.text = @"When a deal unlocks, tap status circle to redeem.";
        self.backgroundImageView.image = [UIImage imageNamed:self.imageFile];
        self.nextButton.hidden = YES;
        self.skipTutorialButton.hidden = NO;

        
    } else if ([self.pageType isEqualToString:@"Ready"]) {
        
        self.getStartedButton.hidden = YES;
        self.nextButton.hidden = NO;
      //  self.bottomLabel.text = @"Login and prepare to unlock great deals.";
        self.backgroundImageView.image = [UIImage imageNamed:self.imageFile];
        
        self.skipTutorialButton.hidden = YES;

    }
       else if ([self.pageType isEqualToString:@"More"]) {

        self.getStartedButton.hidden = YES;
      //  self.bottomLabel.text = @"Login and prepare to unlock great deals.";

           
        self.nextButton.hidden = YES;
        self.skipTutorialButton.hidden = NO;
           
        self.backgroundImageView.image = [UIImage imageNamed:self.imageFile];
    }
    
    
    /*
     self.facebookButton.hidden = YES;
     self.emailLogin.hidden = YES;
     self.skipLogin.hidden = YES;
     self.requestLocation.hidden = YES;
     self.backgroundImageView.alpha = 0.5;
     self.getStartedButton.hidden = NO;
     self.swipeToContinueLabel.hidden = NO;
     self.swipeToContinueLabel.text = @"Tap Get Started to Continue";
     */
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
/*
-(void) advNotificationPage {
    
    if ([self notificationsAllowed]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"nextPage" object:nil];
    } else {
        [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(advNotificationPage) userInfo:nil repeats:NO];
    }
}*/

/*
-(void)closeTutorialView: (NSNotification *) notification {
    [[self presentingViewController] dismissViewControllerAnimated:YES completion:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"showLoginPage" object:nil];

   // [[NSNotificationCenter defaultCenter] removeObserver:self name:@"loginComplete" object:nil];
}*/

/*
- (IBAction)requestLocation:(id)sender {
    [Constants debug:@1 withContent:@"requested location"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"requestLocationAlways" object:nil];
}

- (IBAction)facebookLogin:(id)sender {
    [Constants debug:@1 withContent:@"facebook location button pressed"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"facebookLogin" object:nil];
}

- (IBAction)emailLogin:(id)sender {
    // done it storyboard
}
 */

- (IBAction)nextButton:(id)sender {

    if ([_pageType isEqualToString:@"Ready"]) {
        [self performSegueWithIdentifier:@"statusPage" sender:self];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"nextPage" object:nil];
    }
}


- (IBAction)skipButtonPressed:(id)sender {
    
    [self performSegueWithIdentifier:@"statusPage" sender:self];
}




 /*
    // check of internet
    NetworkStatus theNetworkStatus = [self connectedToInternet];
    if (theNetworkStatus == NotReachable) {
        
        if ([[NSUserDefaults standardUserDefaults] boolForKey:kauto_anonymous_stats]) {
            [[self generateUserData] saveEventually];
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"nextPage" object:nil];
        
    } else {
    
        [PFAnonymousUtils logInWithBlock:^(PFUser *user, NSError *error) {
            if (error) {
                [Constants debug:@3 withContent:@"Anonymous login failed."];
                
            } else {
                [Constants debug:@1 withContent:@"Anonymous user logged in."];
                
                [self generateUserData];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"nextPage" object:nil];
            }
        }];
    }
}
*/


- (IBAction)getStarted:(id)sender {
    
   // [self performSegueWithIdentifier:@"statusPage" sender:self];
    
   // [self closeTutorialView:nil];
}

/*
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
#warning update this breadcrumb
    [Constants debug:@1 withContent:@"mapView prepareForSegue"];
    
    if ([[segue identifier] isEqualToString:@"statusPage"]) {
        
       // Stat *progressView = [segue destinationViewController];
    }
}
*/


- (UIImage *)addBorderToImage:(UIImage *)image {
    CGImageRef bgimage = [image CGImage];
    float width = CGImageGetWidth(bgimage);
    float height = CGImageGetHeight(bgimage);
    
    // Create a temporary texture data buffer
    void *data = malloc(width * height * 4);
    
    // Draw image to buffer
    CGContextRef ctx = CGBitmapContextCreate(data,
                                             width,
                                             height,
                                             8,
                                             width * 4,
                                             CGImageGetColorSpace(image.CGImage),
                                             kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(ctx, CGRectMake(0, 0, (CGFloat)width, (CGFloat)height), bgimage);
    
    //Set the stroke (pen) color
    CGContextSetStrokeColorWithColor(ctx, [UIColor blackColor].CGColor);
    
    //Set the width of the pen mark
    CGFloat borderWidth = (float)width*0.01;
    CGContextSetLineWidth(ctx, borderWidth);
    
    //Start at 0,0 and draw a square
    CGContextMoveToPoint(ctx, 0.0, 0.0);
    CGContextAddLineToPoint(ctx, 0.0, height);
    CGContextAddLineToPoint(ctx, width, height);
    CGContextAddLineToPoint(ctx, width, 0.0);
    CGContextAddLineToPoint(ctx, 0.0, 0.0);
    
    //Draw it
    CGContextStrokePath(ctx);
    
    // write it to a new image
    CGImageRef cgimage = CGBitmapContextCreateImage(ctx);
    UIImage *newImage = [UIImage imageWithCGImage:cgimage];
    CFRelease(cgimage);
    CGContextRelease(ctx);
    
    // auto-released
    return newImage;
}


@end
