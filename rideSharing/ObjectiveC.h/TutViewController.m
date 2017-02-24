//
//  PageViewDemo
//
//  Created by Simon on 24/11/13.
//  Copyright (c) 2013 Appcoda. All rights reserved.
//

//  Code Modifications © 2017 Geodex Systems
//  All Rights Reserved.

#import "TutViewController.h"
#import "Constants.h"

@interface TutViewController ()

@end

@implementation TutViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
  //  self.title = @"Tutorial";
    
    
    /*
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    [self.navigationController.navigationBar
     setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor whiteColor]}];
    
    self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"title"]];
     */
    
    [self.navigationController.navigationBar setBarTintColor:[Constants flockGreen]];
    
    
    self.view.backgroundColor = [Constants flockGreen];

    
    
	// Create the data model

  //  _pageTitles = @[@"With Squad it's easy to connect with nearby friends", @"Check the map to find your friends", @"Once a deal has enough people, everyone can unlock", @"Just show the cashier or waiter, the Flock App to enjoy your savings", @"That's all you need to know!"];
    
    _pageTitles = @[@"With Squad it's easy to stay connected to friends near and far"];
    
    
  //  _pageImages = @[@"example", @"tutMapImage", @"tutDealImage", @"tutClaimImage", @"example"];
    //_pageImages = @[@"tutImage1", @"tutImage2", @"tutImage3", @"tutImage4", @"tutImage1"];
    _pageImages = @[@"tutImage2"];

  //  _pageTypes = @[@"Welcome", @"Map", @"Deal", @"Claim", @"Ready"];
    _pageTypes = @[@"Ready"];

    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nextPage:) name:@"nextPage" object:nil];
 
    
    // Create page view controller
    self.pageViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"PageViewController"];
    self.pageViewController.dataSource = self;
    
    TutPageContentViewController *startingViewController = [self viewControllerAtIndex:0];
    NSArray *viewControllers = @[startingViewController];
    [self.pageViewController setViewControllers:viewControllers direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
    
    // Change the size of page view controller
    self.pageViewController.view.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    
    [self addChildViewController:_pageViewController];
    [self.view addSubview:_pageViewController.view];
    [self.pageViewController didMoveToParentViewController:self];
    
    
    [self setupPageControlAppearance];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)setupPageControlAppearance {
    UIPageControl *pageControl = [UIPageControl appearance];
    pageControl.pageIndicatorTintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5];
    pageControl.currentPageIndicatorTintColor = [UIColor whiteColor];
    pageControl.backgroundColor = [Constants flockGreen];
}


-(void) nextPage:(NSNotification *) notification {
    
    TutPageContentViewController *currentVC = self.pageViewController.viewControllers.firstObject;
    
    // this way it will only advance if the tut is on a particular page
    if ([currentVC.pageType isEqualToString:@"Map"] || [currentVC.pageType isEqualToString:@"Claim"] || [currentVC.pageType isEqualToString:@"Deal"] || [currentVC.pageType isEqualToString:@"Welcome"]) {
       
        TutPageContentViewController *nextVC = [self viewControllerAtIndex:currentVC.pageIndex+1];
        
        NSArray *viewControllers = @[nextVC];
        [self.pageViewController setViewControllers:viewControllers direction:UIPageViewControllerNavigationDirectionForward animated:YES completion:nil];
    }
}

// not currently used, this resets the page views to the first one
/*
- (IBAction)startWalkthrough:(id)sender {
    TutPageContentViewController *startingViewController = [self viewControllerAtIndex:0];
    NSArray *viewControllers = @[startingViewController];
    [self.pageViewController setViewControllers:viewControllers direction:UIPageViewControllerNavigationDirectionReverse animated:NO completion:nil];
}
 */

- (TutPageContentViewController *)viewControllerAtIndex:(NSUInteger)index {
    if (([self.pageTitles count] == 0) || (index >= [self.pageTitles count])) {
        return nil;
    }
    
    // Create a new view controller and pass suitable data.
    TutPageContentViewController *pageContentViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"TutPageContentViewController"];
    pageContentViewController.imageFile = self.pageImages[index];
    pageContentViewController.titleText = self.pageTitles[index];
    pageContentViewController.pageType = self.pageTypes[index];
    pageContentViewController.pageIndex = index;
    
    return pageContentViewController;
}

#pragma mark - Page View Controller Data Source

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController
{
    NSUInteger index = ((TutPageContentViewController*) viewController).pageIndex;
    
    if ((index == 0) || (index == NSNotFound)) {
        return nil;
    }
    
    index--;
    return [self viewControllerAtIndex:index];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController
{
    NSUInteger index = ((TutPageContentViewController*) viewController).pageIndex;
    
    if (index == NSNotFound) {
        return nil;
    }
    
    index++;
    if (index == [self.pageTitles count]) {
        return nil;
    }
    return [self viewControllerAtIndex:index];
}

- (NSInteger)presentationCountForPageViewController:(UIPageViewController *)pageViewController
{
    return [self.pageTitles count];
}


// This not handles when the pages are changed (forward or backward) programmatically!
- (NSInteger)presentationIndexForPageViewController:(UIPageViewController *)pageViewController {
    TutPageContentViewController *currentVC = self.pageViewController.viewControllers.firstObject;
    return currentVC.pageIndex;
}


@end
