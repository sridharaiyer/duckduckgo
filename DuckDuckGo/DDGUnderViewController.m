//
//  DDGUnderViewController.m
//  DuckDuckGo
//
//  Created by Ishaan Gulrajani on 8/14/12.
//
//

#import "DDGUnderViewController.h"
#import "ECSlidingViewController.h"
#import "DDGSettingsViewController.h"
#import "DDGWebViewController.h"
#import "DDGHistoryProvider.h"
#import "DDGBookmarksViewController.h"
#import "DDGStoriesViewController.h"
#import "DDGDuckViewController.h"
#import "DDGUnderViewControllerCell.h"
#import "DDGStory.h"
#import "DDGStoryFeed.h"
#import "DDGHistoryItem.h"
#import "DDGPlusButton.h"

NSString * const DDGViewControllerTypeTitleKey = @"title";
NSString * const DDGViewControllerTypeTypeKey = @"type";
NSString * const DDGViewControllerTypeControllerKey = @"viewController";
NSString * const DDGSavedViewLastSelectedTabIndex = @"saved tab index";

@interface DDGUnderViewController ()
@property (nonatomic, strong) NSArray *viewControllerTypes;
@property (nonatomic, strong) DDGHistoryProvider *historyProvider;
@property (nonatomic, readwrite, strong) NSManagedObjectContext *managedObjectContext;
@end

@implementation DDGUnderViewController

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)moc {
    self = [super initWithStyle:UITableViewStylePlain];
    if(self) {
        self.managedObjectContext = moc;        
        
        [self setupViewControllerTypes];        
        
        self.tableView.scrollsToTop = YES;
        
        self.tableView.backgroundColor = [UIColor colorWithRed:0.161 green:0.173 blue:0.196 alpha:1.000];
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        
        self.clearsSelectionOnViewWillAppear = NO;
		
		self.tableView.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.historyProvider = [[DDGHistoryProvider alloc] initWithManagedObjectContext:self.managedObjectContext];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
    if (![self isViewLoaded] || nil == self.view.superview) {
        self.historyProvider = nil;
    }
}

- (void)setupViewControllerTypes {
    
    DDGViewControllerType selectedType = DDGViewControllerTypeHome;
    if (menuIndex < [self.viewControllerTypes count]) {
        selectedType = [[[self.viewControllerTypes objectAtIndex:menuIndex] valueForKey:DDGViewControllerTypeTypeKey] integerValue];
    }
    
    NSMutableArray *types = [NSMutableArray array];
    
    [types addObject:[@{DDGViewControllerTypeTitleKey : @"Home",
                      DDGViewControllerTypeTypeKey: @(DDGViewControllerTypeHome)
                      } mutableCopy]];
    [types addObject:[@{DDGViewControllerTypeTitleKey : @"Saved",
                      DDGViewControllerTypeTypeKey: @(DDGViewControllerTypeSaved)
                      } mutableCopy]];

//    if ([[DDGCache objectForKey:DDGSettingHomeView inCache:DDGSettingsCacheName] isEqual:DDGSettingHomeViewTypeDuck]) {
//        [types addObject:[@{DDGViewControllerTypeTitleKey : @"Stories",
//                          DDGViewControllerTypeTypeKey: @(DDGViewControllerTypeStories)
//                          } mutableCopy]];
//    }
    
    [types addObject:[@{DDGViewControllerTypeTitleKey : @"Settings",
                      DDGViewControllerTypeTypeKey: @(DDGViewControllerTypeSettings)
                      } mutableCopy]];
    
    self.viewControllerTypes = types;
    
    for (NSDictionary *typeInfo in types) {
        if ([[typeInfo valueForKey:DDGViewControllerTypeTypeKey] integerValue] == selectedType) {
            menuIndex = [types indexOfObject:typeInfo];
        }
    }
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self setupViewControllerTypes];
    [self.tableView reloadData];
}

-(void)configureViewController:(UIViewController *)viewController {
    [viewController.view addGestureRecognizer:self.slidingViewController.panGesture];
    
    viewController.view.layer.shadowOpacity = 0.75f;
    viewController.view.layer.shadowRadius = 10.0f;
    viewController.view.layer.shadowColor = [UIColor blackColor].CGColor;
}

-(void)loadSelectedViewController; {
    CGRect frame = self.slidingViewController.topViewController.view.frame;
    
    UIViewController *viewController = [self viewControllerForIndexPath:[NSIndexPath indexPathForRow:menuIndex inSection:0]];
    
    self.slidingViewController.topViewController = viewController;
    viewController.view.frame = frame;
    [self configureViewController:viewController];
}

- (IBAction)plus:(id)sender {
    UIButton *button = nil;
    if ([sender isKindOfClass:[UIButton class]])
        button = (UIButton *)sender;
    
    if (button) {
        CGPoint tappedPoint = [self.tableView convertPoint:button.center fromView:button.superview];
        NSIndexPath *tappedIndex = [self.tableView indexPathForRowAtPoint:tappedPoint];
        DDGHistoryItem *item = [[self.historyProvider allHistoryItems] objectAtIndex:tappedIndex.row];
        
        UIViewController *topViewController = self.slidingViewController.topViewController;
        if ([topViewController isKindOfClass:[DDGSearchController class]]) {
            DDGSearchController *searchController = (DDGSearchController *)topViewController;
            [self.slidingViewController resetTopViewWithAnimations:nil onComplete:^{
                [searchController.searchField becomeFirstResponder];
                searchController.searchField.text = item.title;
            }];
        } else {
            [self loadQueryOrURL:item.title];
        }
    }
}

#pragma mark - DDGSearchHandler

- (void)prepareForUserInput {
    DDGWebViewController *webVC = [[DDGWebViewController alloc] initWithNibName:nil bundle:nil];
    DDGSearchController *searchController = [[DDGSearchController alloc] initWithSearchHandler:webVC managedObjectContext:self.managedObjectContext];
    webVC.searchController = searchController;
    
    [searchController pushContentViewController:webVC animated:NO];
    searchController.state = DDGSearchControllerStateWeb;    
    
    CGRect frame = self.slidingViewController.topViewController.view.frame;
    self.slidingViewController.topViewController = searchController;
    self.slidingViewController.topViewController.view.frame = frame;
    [self configureViewController:searchController];
    
    [searchController.searchField becomeFirstResponder];
}

-(void)searchControllerLeftButtonPressed {
    [self.slidingViewController anchorTopViewTo:ECRight];
}

-(void)loadStory:(DDGStory *)story readabilityMode:(BOOL)readabilityMode {
    DDGWebViewController *webVC = [[DDGWebViewController alloc] initWithNibName:nil bundle:nil];
    DDGSearchController *searchController = [[DDGSearchController alloc] initWithSearchHandler:webVC managedObjectContext:self.managedObjectContext];
    webVC.searchController = searchController;
    
    [searchController pushContentViewController:webVC animated:NO];
    searchController.state = DDGSearchControllerStateWeb;    
    
    [webVC loadStory:story readabilityMode:readabilityMode];
    
    CGRect frame = self.slidingViewController.topViewController.view.frame;
    self.slidingViewController.topViewController = searchController;
    self.slidingViewController.topViewController.view.frame = frame;
    [self configureViewController:searchController];
}

-(void)loadQueryOrURL:(NSString *)queryOrURL {
    DDGWebViewController *webVC = [[DDGWebViewController alloc] initWithNibName:nil bundle:nil];
    DDGSearchController *searchController = [[DDGSearchController alloc] initWithSearchHandler:webVC managedObjectContext:self.managedObjectContext];
    webVC.searchController = searchController;
    
    [searchController pushContentViewController:webVC animated:NO];
    searchController.state = DDGSearchControllerStateWeb;    
    
    [webVC loadQueryOrURL:queryOrURL];
    
    CGRect frame = self.slidingViewController.topViewController.view.frame;
    self.slidingViewController.topViewController = searchController;
    self.slidingViewController.topViewController.view.frame = frame;
    [self configureViewController:searchController];
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return self.viewControllerTypes.count;
        case 1:
		{
            return ([[NSUserDefaults standardUserDefaults] boolForKey:DDGSettingRecordHistory]) ? [self.historyProvider allHistoryItems].count : 1;
		}
        default:
            return 0;
    };
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"DDGUnderViewControllerCell";
    
    DDGUnderViewControllerCell *cell = (DDGUnderViewControllerCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if(!cell)
        cell = [[DDGUnderViewControllerCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    
    cell.active = (indexPath.section == 0 && indexPath.row == menuIndex);
    
	cell.imageView.image = nil;
    cell.imageView.highlightedImage = nil;
    
	UILabel *lbl = cell.textLabel;
    if(indexPath.section == 0)
	{
        cell.cellMode = DDGUnderViewControllerCellModeNormal;        
        lbl.text = [[self.viewControllerTypes objectAtIndex:indexPath.row] objectForKey:DDGViewControllerTypeTitleKey];

        NSDictionary *typeInfo = [self.viewControllerTypes objectAtIndex:indexPath.row];
        DDGViewControllerType type = [[typeInfo objectForKey:DDGViewControllerTypeTypeKey] integerValue];        
        
		switch (type)
		{
			case DDGViewControllerTypeHome:
			{
				cell.imageView.image = [UIImage imageNamed:@"icon_home"];
                cell.imageView.highlightedImage = [UIImage imageNamed:@"icon_home_selected"];
			}
				break;
			case DDGViewControllerTypeSaved:
			{
				cell.imageView.image = [UIImage imageNamed:@"icon_saved-pages"];
                cell.imageView.highlightedImage = [UIImage imageNamed:@"icon_saved-pages_selected"];
			}
				break;
			case DDGViewControllerTypeStories:
			{
				cell.imageView.image = [UIImage imageNamed:@"icon_stories"];
                cell.imageView.highlightedImage = [UIImage imageNamed:@"icon_stories_selected"];
			}
				break;
			case DDGViewControllerTypeSettings:
			{
				cell.imageView.image = [UIImage imageNamed:@"icon_settings"];
                cell.imageView.highlightedImage = [UIImage imageNamed:@"icon_settings_selected"];
			}
				break;
		}
    } else {
        cell.cellMode = DDGUnderViewControllerCellModeRecent;
        
		if ([[NSUserDefaults standardUserDefaults] boolForKey:DDGSettingRecordHistory]) {
			// we have history and it is enabled
			DDGHistoryItem *item = [[self.historyProvider allHistoryItems] objectAtIndex:indexPath.row];
			DDGStory *story = item.story;
            
			if (nil != story) {
				cell.imageView.image = story.feed.image;
                cell.accessoryView = nil;                
			} else {
                cell.imageView.image = [UIImage imageNamed:@"search_icon"];
                cell.accessoryView = [DDGPlusButton plusButton];
			}
			lbl.text = item.title;
		} else {
			cell.imageView.image = [UIImage imageNamed:@"icon_notification"];
			lbl.text = @"Saving recents is disabled.\nYou can enable it in settings.";
            cell.imageView.contentMode = UIViewContentModeCenter;
            cell.accessoryView = nil;
		}
    }
    
    return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return (section == 0 ? 0 : 23);
}

-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return (section == 0 ? 0 : 1);
}

-(UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 23)];
    [headerView setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"bg_divider.png"]]];
    
    if (section == 1)
	{
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, tableView.bounds.size.width-10, 20)];
        title.text = @"Recent";
        title.textColor = [UIColor whiteColor];
        title.opaque = NO;
        title.backgroundColor = [UIColor clearColor];
        title.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:13.0];
        [headerView addSubview:title];
    }
    
    return headerView;
}

-(UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 1)];
    [footerView setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"end_of_list_highlight.png"]]];
    
    return footerView;
}


#pragma mark - Table view delegate

- (NSIndexPath*)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 1 && ![[NSUserDefaults standardUserDefaults] boolForKey:DDGSettingRecordHistory])
		return nil;
	
    if (indexPath.section == 0) {
        DDGUnderViewControllerCell *oldMenuCell;
        DDGUnderViewControllerCell *newMenuCell;
        
        oldMenuCell = (DDGUnderViewControllerCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:menuIndex inSection:0]];
        oldMenuCell.active = NO;
        
        newMenuCell = (DDGUnderViewControllerCell *)[self.tableView cellForRowAtIndexPath:indexPath];
        newMenuCell.active = YES;
    }
    
	return indexPath;
}

- (UIViewController *)viewControllerForType:(DDGViewControllerType)type {
    UIViewController *viewController = nil;
    
    switch (type) {
        case DDGViewControllerTypeSaved:
        {
            DDGBookmarksViewController *bookmarks = [[DDGBookmarksViewController alloc] initWithNibName:@"DDGBookmarksViewController" bundle:nil];
            bookmarks.title = NSLocalizedString(@"Saved Searches", @"View controller title: Saved Searches");
            
            DDGSearchController *searchController = [[DDGSearchController alloc] initWithSearchHandler:self managedObjectContext:self.managedObjectContext];
            searchController.state = DDGSearchControllerStateHome;

            DDGStoriesViewController *stories = [[DDGStoriesViewController alloc] initWithSearchHandler:searchController managedObjectContext:self.managedObjectContext];
            stories.savedStoriesOnly = YES;
            stories.title = NSLocalizedString(@"Saved Stories", @"View controller title: Saved Stories");
            
            DDGTabViewController *tabViewController = [[DDGTabViewController alloc] initWithViewControllers:@[bookmarks, stories]];            
            [searchController pushContentViewController:tabViewController animated:NO];            
            
            bookmarks.searchController = searchController;
            bookmarks.searchHandler = self;
            
            tabViewController.controlViewPosition = DDGTabViewControllerControlViewPositionBottom;
            tabViewController.controlView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
            tabViewController.controlView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"saved_header_background"]];
            [tabViewController.segmentedControl sizeToFit];

            CGRect controlBounds = tabViewController.controlView.bounds;
            CGSize segmentSize = tabViewController.segmentedControl.frame.size;
            segmentSize.width = controlBounds.size.width - 10.0;
            CGRect controlRect = CGRectMake(controlBounds.origin.x + ((controlBounds.size.width - segmentSize.width) / 2.0),
                                            controlBounds.origin.y + ((controlBounds.size.height - segmentSize.height) / 2.0),
                                            segmentSize.width,
                                            segmentSize.height);
            tabViewController.segmentedControl.frame = CGRectIntegral(controlRect);
            tabViewController.segmentedControl.autoresizingMask = (UIViewAutoresizingFlexibleWidth);
            
            [tabViewController.controlView addSubview:tabViewController.segmentedControl];
            tabViewController.currentViewControllerIndex = [[NSUserDefaults standardUserDefaults] integerForKey:DDGSavedViewLastSelectedTabIndex];
            tabViewController.delegate = self;
            
            viewController = searchController;
        }
            
            break;
        case DDGViewControllerTypeStories: {
            DDGSearchController *searchController = [[DDGSearchController alloc] initWithSearchHandler:self managedObjectContext:self.managedObjectContext];
            searchController.state = DDGSearchControllerStateHome;
            DDGStoriesViewController *stories = [[DDGStoriesViewController alloc] initWithSearchHandler:searchController managedObjectContext:self.managedObjectContext];
            [searchController pushContentViewController:stories animated:NO];
            viewController = searchController;
        }
            break;
        case DDGViewControllerTypeSettings: {
            DDGSettingsViewController *settings = [[DDGSettingsViewController alloc] initWithDefaults];
            settings.managedObjectContext = self.managedObjectContext;
            viewController = [[UINavigationController alloc] initWithRootViewController:settings];
            break;            
        }
        case DDGViewControllerTypeHome:
        {
            DDGSearchController *searchController = [[DDGSearchController alloc] initWithSearchHandler:self managedObjectContext:self.managedObjectContext];
//            if ([[DDGCache objectForKey:DDGSettingHomeView inCache:DDGSettingsCacheName] isEqual:DDGSettingHomeViewTypeDuck]) {
//                searchController.contentController = [DDGDuckViewController duckViewController];
//            } else {
            DDGStoriesViewController *stories = [[DDGStoriesViewController alloc] initWithSearchHandler:searchController managedObjectContext:self.managedObjectContext];            
            [searchController pushContentViewController:stories animated:NO];
//            }
            searchController.state = DDGSearchControllerStateHome;
            viewController = searchController;
        }
        default:
            break;
    }
    
    return viewController;
}

- (UIViewController *)viewControllerForIndexPath:(NSIndexPath *)indexPath {
    UIViewController *viewController = nil;
    
    if(indexPath.section == 0)
    {
        menuIndex = indexPath.row;
        NSDictionary *typeInfo = [self.viewControllerTypes objectAtIndex:menuIndex];
        viewController = [typeInfo objectForKey:DDGViewControllerTypeControllerKey];
        
        if (nil == viewController) {
            DDGViewControllerType type = [[typeInfo objectForKey:DDGViewControllerTypeTypeKey] integerValue];
            viewController = [self viewControllerForType:type];            
        }
    }
    
    return viewController;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.slidingViewController anchorTopViewOffScreenTo:ECRight animations:nil onComplete:^{
        if(indexPath.section == 0)
		{
			menuIndex = indexPath.row;            
            UIViewController *newTopViewController = [self viewControllerForIndexPath:indexPath];
            
            if (nil != newTopViewController) {
                CGRect frame = self.slidingViewController.topViewController.view.frame;
                self.slidingViewController.topViewController = newTopViewController;
                self.slidingViewController.topViewController.view.frame = frame;
                [self.slidingViewController resetTopView];
                
                [self configureViewController:newTopViewController];                
            }
        }
		else if(indexPath.section == 1)
		{
			DDGHistoryItem *historyItem = [[self.historyProvider allHistoryItems] objectAtIndex:indexPath.row];
            [self.historyProvider relogHistoryItem:historyItem];
            DDGStory *story = historyItem.story;
			if (nil != story)
				[self loadStory:story readabilityMode:[[NSUserDefaults standardUserDefaults] boolForKey:DDGSettingStoriesReadView]];
			else
				[self loadQueryOrURL:historyItem.title];
            [self.slidingViewController resetTopView];
        }
    }];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Rotation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	CGSize sz = [[UIScreen mainScreen] bounds].size;
	CGFloat width;
	if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
		width = sz.width;
	else
		width = sz.height;
	
    [self.slidingViewController setAnchorRightRevealAmount:width - 65.0];
}

#pragma mark - DDGTabViewControllerDelegate

- (void)tabViewController:(DDGTabViewController *)tabViewController didSwitchToViewController:(UIViewController *)viewController atIndex:(NSInteger)tabIndex {
    [[NSUserDefaults standardUserDefaults] setInteger:tabIndex forKey:DDGSavedViewLastSelectedTabIndex];
}

@end
