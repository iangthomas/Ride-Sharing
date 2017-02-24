//
//  PageViewDemo
//
//  Created by Simon on 24/11/13.
//  Copyright (c) 2013 Appcoda. All rights reserved.
//

//  Code Modifications © 2017 Geodex Systems
//  All Rights Reserved.

#import <UIKit/UIKit.h>
#import "TutPageContentViewController.h"

@interface TutViewController : UIViewController <UIPageViewControllerDataSource>

@property (strong, nonatomic) UIPageViewController *pageViewController;
@property (strong, nonatomic) NSArray *pageTitles;
@property (strong, nonatomic) NSArray *pageImages;
@property (strong, nonatomic) NSArray *pageTypes;

@property (nonatomic, assign) BOOL showHiddenStuff;


@end
