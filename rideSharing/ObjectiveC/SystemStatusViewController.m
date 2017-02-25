//
//  SystemStatusViewController.m
//  Nimbus
//
//  Created by Ian Thomas on 11/7/15.
//  Code Modifications © 2017 Geodex Systems. All Rights Reserved.
//
//

#import "SystemStatusViewController.h"
#import "Constants.h"
#include "Reachability.h"
#import <CoreLocation/CoreLocation.h>
#import <FirebaseAuth/FirebaseAuth.h>


@import Firebase;


@interface SystemStatusViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UIButton *LocationImageButton;
@property (weak, nonatomic) IBOutlet UIButton *SocialImageButton;
@property (weak, nonatomic) IBOutlet UIButton *GetStartedImageButton;
@property (weak, nonatomic) IBOutlet UIButton *NotificationsImageButton;

@property (weak, nonatomic) IBOutlet UIButton *loginWithEmailButton;
@property (weak, nonatomic) IBOutlet UIButton *loginWithFacebook;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView * activityView;
@property (weak, nonatomic) IBOutlet UITextField *emailTextBox;
@property (weak, nonatomic) IBOutlet UIButton *SocialTextButton;

@property (assign, nonatomic) bool isPinReady;
@property (weak, nonatomic) NSString* theUniquePin;

@end

@implementation SystemStatusViewController
@synthesize emailTextBox;

-(void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [Constants debug:@2 withContent:@"SystemStatusViewController Appearing"];
}


-(void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [Constants debug:@2 withContent:@"SystemStatusViewController Disappearing"];
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    _isPinReady = NO;
    
    [self generateAPin];
    
    // this makes it blank
    UIBarButtonItem *barButton = [[UIBarButtonItem alloc] init];
    barButton.title = @"";
    self.navigationController.navigationBar.topItem.backBarButtonItem = barButton;
    
    
    self.navigationController.navigationBar.tintColor = [Constants flockGreen];
    [self.navigationController.navigationBar
     setTitleTextAttributes:@{NSForegroundColorAttributeName : [Constants flockGreen]}];
    
    // self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"title"]];
    
    
    
    // [self.navigationController.navigationBar setBarTintColor:[Constants flockGreen]];
    
    self.view.backgroundColor = [Constants flockGreen];
    
    
    _LocationImageButton.tintColor = [UIColor whiteColor];
    _SocialImageButton.tintColor = [UIColor whiteColor];
    _NotificationsImageButton.tintColor = [UIColor whiteColor];
    
    
    [self updateGetStartedButton:nil];
    
    
    emailTextBox.delegate = self;
    
    emailTextBox.hidden = YES;
    //passwordTextBox.delegate = self;
    
    
    // self.navigationController.navigationBar.topItem.title = @"Status";
    
    [self startLocationServicesMonitoring];
    
    [self updateSocialButton];
    
    
    _loginWithEmailButton.hidden = YES;
    _loginWithFacebook.hidden = YES;
    
    /*
    if (_showHiddenStuff) {
        
        UIImage *image = [[UIImage imageNamed:@"close"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(closeTutorialView:)];
        
        self.navigationItem.leftBarButtonItem = button;
        
        self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
        [self.navigationController.navigationBar
         setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor whiteColor]}];
        
    } else {
        self.navigationItem.leftBarButtonItem = nil;
    }
     */
}

- (void) generateAPin {
    
   // NSNumber * randNumber = [NSNumber numberWithFloat: (arc4random()%90)+10];
    FIRDatabaseReference *potentialPinRef = [[[[FIRDatabase database] reference] child:@"users"] childByAutoId];
    
    [potentialPinRef observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot * _Nonnull snapshot) {
        // if it is successful then that pin in taken.
      
       
            // else, the pin is free
            _isPinReady = YES;
            _theUniquePin = snapshot.key;

    }];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


-(BOOL) docentProfileEmpty {
    NSString* theName = [[NSUserDefaults standardUserDefaults] stringForKey:kAppUserID];
    
    if ([theName isEqualToString:@""] || theName == nil || [theName isEqualToString:@"0"]) {
        return YES;
    } else {
        return NO;
    }
}


-(void) updateSocialButton {
    if ([self docentProfileEmpty] == NO) {
        [self setButton:_SocialImageButton toColor:@"Green"];
    } else if (emailTextBox.hidden == NO) {
        [self setButton:_SocialImageButton toColor:@"Cyan"];
    } else {
        [self setButton:_SocialImageButton toColor:@"Red"];
    }
}


-(void) startLocationServicesMonitoring {
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLocServices:) name:@"locationServicesDenied" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLocServices:) name:@"locationServicesAllowedInUse" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLocServices:) name:@"locationServicesAllowed" object:nil];
    
    [self getInitialLocationAuthStatus];
}

//#warning perhaps replace me with the more general method
-(void)getInitialLocationAuthStatus {
    
    switch ([CLLocationManager authorizationStatus]) {
        case kCLAuthorizationStatusAuthorizedAlways:
            [self setButton:_LocationImageButton toColor:@"Green"];
            // [self setButton:_GetStartedImageButton toColor:@"Cyan"];
            [Constants debug:@1 withContent:@"Location Detection is Authorized Always"];
            
            break;
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            
            [self setButton:_LocationImageButton toColor:@"Green"];
            // [self setButton:_GetStartedImageButton toColor:@"Cyan"];
            [Constants debug:@3 withContent:@"Location Detection Authorized when in use"];
            
            break;
            
        case kCLAuthorizationStatusDenied:
            [Constants debug:@3 withContent:@"Location Detection Denied"];
            [self setButton:_LocationImageButton toColor:@"Red"];
            //  [self setButton:_GetStartedImageButton toColor:@"Grey"];
            
            break;
            
        case kCLAuthorizationStatusNotDetermined:
            [Constants debug:@3 withContent:@"Location Detection Not determined"];
            [self setButton:_LocationImageButton toColor:@"Red"];
            //[self setButton:_GetStartedImageButton toColor:@"Grey"];
            
            break;
        case kCLAuthorizationStatusRestricted:
            [Constants debug:@3 withContent:@"Location Detection Restricted"];
            [self setButton:_LocationImageButton toColor:@"Red"];
            //  [self setButton:_GetStartedImageButton toColor:@"Grey"];
            
            break;
        default:
            break;
    }
}


-(void) updateLocServices:(NSNotification*) theNotification {
    
    if ([theNotification.name isEqualToString:@"locationServicesDenied"]) {
        [self setButton:_LocationImageButton toColor:@"Red"];
        
    } else if ([theNotification.name isEqualToString:@"locationServicesAllowed"]) {
        [self setButton:_LocationImageButton toColor:@"Green"];
        
    }  else if ([theNotification.name isEqualToString:@"locationServicesAllowedInUse"]) {
        [self setButton:_LocationImageButton toColor:@"Green"];
    }
    
    [self updateGetStartedButton:nil];
}


-(void)alreadyEnabledAlert {
    [Constants debug:@1 withContent:@"Showing location already enabled Alert View"];
    
    
    [Constants debug:@1 withContent:@"Location Detection is Authorized Always"];
    
    
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Already Enabled"
                                                                   message:@"Location Services have already been enabled."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {}];
    
    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];
    
}



-(void)deniedAlert {
    [Constants debug:@1 withContent:@"Showing denied location enabled Alert View"];
    
    
    UIAlertController* alert3 = [UIAlertController alertControllerWithTitle:@"Turn on Location Services"
                                                                    message:@"1. Tap Settings\n2. Tap Location\n3. Tap Always"
                                                             preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction3 = [UIAlertAction actionWithTitle:@"Not Now" style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * action) {
                                                           }];
    
    UIAlertAction* settings = [UIAlertAction actionWithTitle:@"Settings" style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * action) {
                                                         
                                                         [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
                                                         
                                                     }];
    
    
    [alert3 addAction:defaultAction3];
    [alert3 addAction:settings];
    [self presentViewController:alert3 animated:YES completion:nil];
    
    
}



-(void) requestLocServ {
    [Constants debug:@1 withContent:@"Showing location request services Alert View"];
    
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Request Location Services"
                                                                   message:@"Hey! We are about to ask you about location services. We use this to show your “fuzzy” location to only your friends. The App only knows your location to a within 40 miles and only updates your location when the app is open. You can also disable location services later."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"Got it, ask me!" style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              
                                                              
                                                              [Constants debug:@1 withContent:@"requested location"];
                                                              [[NSNotificationCenter defaultCenter] postNotificationName:@"requestLocation" object:nil];
                                                              
                                                          }];
    
    UIAlertAction* dontAsk = [UIAlertAction actionWithTitle:@"Don't ask me" style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * action) {}];
    
    [alert addAction:defaultAction];
    [alert addAction:dontAsk];
    
    [self presentViewController:alert animated:YES completion:nil];
}


- (IBAction)requestLocation:(id)sender {
    
    switch ([CLLocationManager authorizationStatus]) {
        case kCLAuthorizationStatusAuthorizedAlways:
            
            [self alreadyEnabledAlert];
            break;
            
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            
            [Constants debug:@3 withContent:@"Location Detection Authorized when in use"];
            [self alreadyEnabledAlert];
            break;
            
        case kCLAuthorizationStatusDenied:
            
            [Constants debug:@3 withContent:@"Location Detection Denied"];
            [self deniedAlert];
            break;
            
        default:
            [self requestLocServ];
            break;
    }
}


- (IBAction)enableNotifications:(id)sender {
    
    UIUserNotificationSettings *grantedSettings = [[UIApplication sharedApplication] currentUserNotificationSettings];
    if (grantedSettings.types == UIUserNotificationTypeNone) {
        
     
        
        /*
         if ([[UIApplication sharedApplication] respondsToSelector:@selector(isRegisteredForRemoteNotifications)])
         {
         // iOS 8 Notifications
         [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge) categories:nil]];
         [[UIApplication sharedApplication] registerForRemoteNotifications];
         }
         */
        [self checkUserEnabledNotifications];
        
        
        //   [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(checkUserEnabledNotifications) userInfo:nil repeats:NO];
        
        
    } else {
        
        [Constants debug:@1 withContent:@"Showing notifications already allowed Alert View"];
        
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Already Enabled"
                                                                       message:@"Notifications have already been enabled."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {}];
        
        [alert addAction:defaultAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
}


-(void) checkUserEnabledNotifications {
    
    UIUserNotificationSettings *grantedSettings = [[UIApplication sharedApplication] currentUserNotificationSettings];
    
    if (grantedSettings.types == UIUserNotificationTypeNone) {
        [self setButton:_NotificationsImageButton toColor:@"Orange"];
        
        [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(checkUserEnabledNotifications) userInfo:nil repeats:NO];
    }
    else if (grantedSettings.types & UIUserNotificationTypeAlert ){
        [self setButton:_NotificationsImageButton toColor:@"Green"];
    }
}


- (IBAction)getStarted:(id)sender {
    
    switch ([CLLocationManager authorizationStatus]) {
        case kCLAuthorizationStatusAuthorizedAlways:
            
            if ([self docentProfileEmpty] == NO) {
                [self closeTutorialView:nil];
            }
            break;
            
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            
            if ([self docentProfileEmpty] == NO) {
                [self closeTutorialView:nil];
            }
            break;
            
        default:
            break;
    }
}


-(IBAction)socialButtonTapped:(id)sender {
    
    if ([self docentProfileEmpty]) {
        
        if (emailTextBox.hidden == NO) { // if the user is entering an email address, have the button act like a continue button
            [self prepForEmailSignup];
            
        } else {
            [self showAllLoginOptions];
        }
        
    } else {
        [self showSocialAlreadyEnabled];
    }
}


-(void) showAllLoginOptions {
    
    if (_loginWithEmailButton.hidden == YES) {
        
        _loginWithEmailButton.hidden = NO;
        
        //facebook disabled
        //_loginWithFacebook.hidden = NO;
        
        _loginWithEmailButton.alpha = 0.0;
        //   _loginWithFacebook.alpha = 0.0;
        
        
        [UIView animateWithDuration:0.70f
                              delay:0.0f
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             _loginWithEmailButton.alpha = 1.0;
                             //  _loginWithFacebook.alpha = 1.0;
                         }
                         completion:^(BOOL finished){
                         }];
    }
}


-(void) hideAllLoginOptions {
    
    if (_loginWithEmailButton.hidden == NO) {
        
        _loginWithEmailButton.hidden = YES;
        _loginWithFacebook.hidden = YES;
        
        [UIView animateWithDuration:0.70f
                              delay:0.0f
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             _loginWithEmailButton.alpha = 0.0;
                             _loginWithFacebook.alpha = 0.0;
                         }
                         completion:^(BOOL finished){
                         }];
    }
}


-(void)closeTutorialView: (NSNotification *) notification {
    
    [[self presentingViewController] dismissViewControllerAnimated:YES completion:nil];
}


-(void) setButton:(UIButton*) theButton toColor:(NSString*)theColor {
    
    if ([theColor isEqualToString:@"Red"]) {
        [theButton setBackgroundImage:[UIImage imageNamed:@"SystemRed"] forState:UIControlStateNormal];
        
    } else if ([theColor isEqualToString:@"Orange"]) {
        [theButton setBackgroundImage:[UIImage imageNamed:@"SystemOrange"] forState:UIControlStateNormal];
        
    } else if ([theColor isEqualToString:@"Green"]) {
        [theButton setBackgroundImage:[UIImage imageNamed:@"SystemGreen"] forState:UIControlStateNormal];
        
    } else if ([theColor isEqualToString:@"Grey"]){
        [theButton setBackgroundImage:[UIImage imageNamed:@"SystemGrey"] forState:UIControlStateNormal];
        
    } else if ([theColor isEqualToString:@"Cyan"]) {
        [theButton setBackgroundImage:[UIImage imageNamed:@"SystemCyan"] forState:UIControlStateNormal];
    }
}


-(void)showSocialAlreadyEnabled {
    [Constants debug:@1 withContent:@"Showing social already enabeled alert view"];
    
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Already Enabled"
                                                                   message:@"You are already logged in."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {}];
    
    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];
}


- (IBAction)facebookLogin:(id)sender {
    [Constants debug:@1 withContent:@"facebook location button pressed"];
    
    [_activityView startAnimating];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateGetStartedButton:)
                                                 name:@"FBLoginSucessful"
                                               object:nil];
    [self hideEmailButton];
    
}



-(void) appEnteredForeground:(NSNotification*) theNotification {
    
    [_activityView stopAnimating];
    
    [self updateGetStartedButton:nil];
    [self updateSocialButton];
}


-(void) showEmailBox {
    
    emailTextBox.alpha = 0.0;
    emailTextBox.hidden = NO;
    
    [emailTextBox becomeFirstResponder];
    
    [UIView animateWithDuration:0.70f
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         
                         emailTextBox.alpha = 1.0;
                     }
                     completion:^(BOOL finished){
                     }];
}


-(void) hideEmailBox {
    
    [UIView animateWithDuration:0.70f
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         emailTextBox.alpha = 0.0;
                     }
                     completion:^(BOOL finished){
                         
                         [emailTextBox resignFirstResponder];
                         emailTextBox.hidden = YES;
                     }];
}


-(void) hideSocialButton {
    
    _SocialTextButton.alpha = 1.0;
    
    [UIView animateWithDuration:0.70f
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         _SocialTextButton.alpha = 0.0;
                     }
                     completion:^(BOOL finished){
                         
                     }];
}


-(void) showSocialButton {
    
    _SocialTextButton.alpha = 0.0;
    
    [UIView animateWithDuration:0.70f
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         _SocialTextButton.alpha = 1.0;
                     }
                     completion:^(BOOL finished){
                     }];
}



-(void) hideEmailButton {
    _loginWithEmailButton.alpha = 1.0;
    
    [UIView animateWithDuration:0.70f
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         _loginWithEmailButton.alpha = 0.0;
                     }
                     completion:^(BOOL finished){
                     }];
    
}


- (IBAction)emailLogin:(id)sender {
    [self showEmailBox];
    [self hideSocialButton];
    [self hideAllLoginOptions];
    [self updateSocialButton];
}


-(void) updateGetStartedButton:(NSNotification*) notification {
    
    if ([self docentProfileEmpty] == NO) {
        
        switch ([CLLocationManager authorizationStatus]) {
            case kCLAuthorizationStatusAuthorizedAlways:
                
                [self enableGetStartedButton];
                // this next line starts everything
                [[NSNotificationCenter defaultCenter] postNotificationName:@"onDutySwitchChanged" object:nil];
                
                break;
                
            case kCLAuthorizationStatusAuthorizedWhenInUse:
                
                [self enableGetStartedButton];
                // this next line starts everything
                [[NSNotificationCenter defaultCenter] postNotificationName:@"onDutySwitchChanged" object:nil];
                
                break;
                
            default:
                [self disableGetStartedButton];
                break;
        }
        
    } else {
        [self disableGetStartedButton];
    }
}


-(void) disableGetStartedButton {
    /*
     _GetStartedImageButton.tintColor = [UIColor lightGrayColor];
     [self setButton:_GetStartedImageButton toColor:@"Red"];
     */
    _GetStartedImageButton.hidden = YES;
}


-(void) enableGetStartedButton {
    _GetStartedImageButton.tintColor = [UIColor whiteColor];
    [self setButton:_GetStartedImageButton toColor:@"Cyan"];
    _GetStartedImageButton.hidden = NO;
}


-(BOOL) connectedToInternet {
    
    Reachability *networkReachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus networkStatus = [networkReachability currentReachabilityStatus];
    
    switch (networkStatus)
    {
        case NotReachable:        {
            [Constants debug:@3 withContent:@"No internet Connection"];
            
            [self showNoInternetAlert];
            return NO;
            
            break;
        }
        case ReachableViaWWAN:        {
            [Constants debug:@1 withContent:@"There IS internet via WAN (cell) connection"];
            return  YES;
            
            break;
        }
        case ReachableViaWiFi:        {
            [Constants debug:@1 withContent:@"There IS internet via Wifi connection"];
            return  YES;
            
            break;
        }
    }
}


-(void) showNoInternetAlert {
    
    [Constants debug:@1 withContent:@"Showing no internet alert view - system status"];
    
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"No Internet"
                                                                   message:@"Please connect to the internet to change duty status."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    /*
     UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
     handler:^(UIAlertAction * action) {
     
     [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(makeAppReadyToUse) userInfo:nil repeats:NO];
     
     }];
     */
    
    UIAlertAction* tryAgainAction = [UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * action) {
                                                               
                                                               /*
                                                                [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(makeAppReadyToUse) userInfo:nil repeats:NO];
                                                                */
                                                           }];
    
    // [alert addAction:defaultAction];
    [alert addAction:tryAgainAction];
    
    [alert.view setNeedsLayout];
    [alert.view layoutIfNeeded];
    
    [self presentViewController:alert animated:YES completion:nil];
}


- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    
    [self prepForEmailSignup];
    return YES;
}


-(void) prepForEmailSignup {
    
    [self hideEmailBox];
    [self showSocialButton];
    
    [self holdForPin];
}

-(void) holdForPin {
    if (_isPinReady == YES) {
        [self emailSignup];
    } else {
        [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(holdForPin) userInfo:nil repeats:NO];
    }
}


- (void)emailSignup {
    
    //
    // firebase sign up
    //
    
    NSMutableDictionary *userProfile = [[NSMutableDictionary alloc] init];
    
#if DEBUG == 1
    userProfile[@"is_Developer"] = @YES;
#else
    userProfile[@"is_Developer"] = @NO;
#endif
    
    
    
    UIDevice *currentDevice = [UIDevice currentDevice];
    
    userProfile[@"App_Version"] = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    userProfile[@"Build_Number"] = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBuildNumber"];
    userProfile[@"Device_Type"] = [currentDevice model];
    userProfile[@"System_Version"] = [currentDevice systemVersion];
    userProfile[@"Country"] = [[NSLocale currentLocale] localeIdentifier];
    userProfile[@"Num_Launches"] = [NSString stringWithFormat:@"%ld", (long)[[NSUserDefaults standardUserDefaults] integerForKey:kNumLaunchesKey]];
    userProfile[@"DeviceName"] = [Constants platform];
    
    FIRDatabaseReference *usersRef= [[[FIRDatabase database] reference] child:@"users"];
    
    userProfile[@"dateCreated"] = [[Constants internetTimeDateFormatter] stringFromDate:[NSDate date]];
    
   // userProfile[@"uniqueFirebaseId"] = [self generateUniqueId];
    
    userProfile[@"e-mail"] = emailTextBox.text;
    
 //   userProfile[@"pin"] = _theUniquePin;
    
  //  [[NSUserDefaults standardUserDefaults] setObject:userProfile[@"pin"] forKey:kPin];
    
    
    [_activityView startAnimating];
    [self setButton:_SocialImageButton toColor:@"Red"];
    
    
    NSString *temp = emailTextBox.text;
    [[FIRAuth auth] createUserWithEmail:temp
                               password:temp
                             completion:^(FIRUser *_Nullable user,
                                          NSError *_Nullable error) {
                                 
                                 if (error) {
                                     [Constants debug:@3 withContent:@"ERROR: Firebase e-mail user creation."];
                                     [Constants makeErrorReportWithDescription:error.localizedDescription];
                                     
                                     
                                     [_activityView stopAnimating];
                                     
                                     NSString *title = nil;
                                     NSString *message = nil;
                                     UIResponder *responder = nil;
                                     
                                     switch(error.code) {
                                             
                                         case FIRAuthErrorCodeInvalidEmail:
                                             
                                             message = @"The email address is invalid. Please enter a valid email.";
                                             responder = emailTextBox;
                                             
                                             break;
                                             
                                         case FIRAuthErrorCodeEmailAlreadyInUse:
                                             
                                             message = [NSString stringWithFormat:@"The username '%@' is taken. Please try choosing a different username", emailTextBox.text];
                                             responder = emailTextBox;
                                             
                                             break;
                                             
                                         default:
                                             [Constants makeErrorReportWithDescription:error.localizedDescription];
                                             break;
                                     }
                                     
                                     
                                     if (message != nil) {
                                         
                                         [responder becomeFirstResponder];
                                         
                                         
                                         UIAlertController* alert = [UIAlertController alertControllerWithTitle:title
                                                                                                        message:message
                                                                                                 preferredStyle:UIAlertControllerStyleAlert];
                                         
                                         UIAlertAction* okAction = [UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault
                                                                                          handler:^(UIAlertAction * action) {
                                                                                              [self showEmailBox];
                                                                                              [self hideSocialButton];
                                                                                              [self setButton:_SocialImageButton toColor:@"Cyan"];
                                                                                              
                                                                                          }];
                                         [alert addAction:okAction];
                                         
                                         [self presentViewController:alert animated:YES completion:nil];
                                     }
                                     
                                     
                                 } else {
                                     [Constants debug:@2 withContent:@"Successful Firebase e-mail user created."];
                                     
                                     // FIRDatabaseReference *usersRef= [[[FIRDatabase database] reference] child:@"users"];
                                     
                                     
                                     
                                     // update pin list
                                     
                                     FIRDatabaseReference *pinRef = [[[[FIRDatabase database] reference] child:@"pins"] child: userProfile[@"pin"]];
                                     
                                     [pinRef setValue:@{@"uniqueId": userProfile[@"uniqueFirebaseId"]} withCompletionBlock:^(NSError * _Nullable error, FIRDatabaseReference * _Nonnull ref) {
                                         
                                         if (error) {
                                             [Constants debug:@3 withContent:@"ERROR: Firebase Pin adding to database."];
                                             [Constants makeErrorReportWithDescription:error.localizedDescription];
                                         } else {
                                             [Constants debug:@2 withContent:@"Successful Firebase pin added to database."];
                                             
                                             
                                             
                                             // now add the user profile itself to the database
                                             
                                             FIRDatabaseReference *uniqueIdRef = [usersRef child:userProfile[@"uniqueFirebaseId"]];
                                             
                                             
                                             [uniqueIdRef setValue:userProfile withCompletionBlock:
                                              ^(NSError *error, FIRDatabaseReference *ref) {
                                                  
                                                  [_activityView stopAnimating];
                                                  
                                                  if (error) {
                                                      [Constants debug:@3 withContent:@"ERROR: Firebase e-mail adding to database."];
                                                      [Constants makeErrorReportWithDescription:error.localizedDescription];
                                                  } else {
                                                      [Constants debug:@2 withContent:@"Successful Firebase e-mail user added to database."];
                                                      [[NSNotificationCenter defaultCenter] postNotificationName:@"makeProfile" object:userProfile[@"uniqueFirebaseId"]];

                                                      
                                                      [self hideAllLoginOptions];
                                                      [self hideEmailBox];
                                                      if (_SocialTextButton.hidden == YES) {
                                                          [self showSocialButton];
                                                      }
                                                      [self updateSocialButton];
                                                      [self updateGetStartedButton:nil];
                                                  }
                                              }];
                                         }
                                     }];
                                 }
                             }];
}


-(NSString*) generateUniqueId {
    
    NSString *dateString = [[Constants internetTimeDateFormatter] stringFromDate: [NSDate date]];
    NSNumber * randNumber = [NSNumber numberWithFloat: (arc4random()%10000000)+1];
    return [NSString stringWithFormat:@"%@ - %i", dateString, randNumber.intValue];
}

@end
