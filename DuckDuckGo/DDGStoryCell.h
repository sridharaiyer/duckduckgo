//
//  DDGStoryCell.h
//  DuckDuckGo
//
//  Created by Johnnie Walker on 12/02/2013.
//
//

#import <UIKit/UIKit.h>
#import "DDGStory.h"

extern NSString *const DDGStoryCellIdentifier;

CGFloat const DDGTitleBarHeight = 57.0f;
CGFloat const DDGTitleBarHeightRatio = 240.0f/740.0f; // 240/740 == 0.324324324 == mosaicmode,    114/475 == 0.24 == normalmode   other: 114/360

@protocol DDGStoryCellDelegate <NSObject>

-(void)shareStory:(DDGStory*)story fromView:(UIView*)sourceView;
-(void)toggleStorySaved:(DDGStory*)story;
-(void)openStoryInBrowser:(DDGStory*)story;
-(void)removeHistoryItem:(DDGHistoryItem*)historyItem;
-(void)toggleCategoryPressed:(NSString*)categoryName onStory:(DDGStory*)story;

@end


@interface DDGStoryCell : UICollectionViewCell

@property (nonatomic, assign) BOOL displaysDropShadow;
@property (nonatomic, assign) BOOL displaysInnerShadow;
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) DDGStory* story;
@property (nonatomic, strong) DDGHistoryItem* historyItem;
@property (nonatomic, weak) id<DDGStoryCellDelegate> storyDelegate;

-(void)toggleSavedState;
-(void)share;
-(void)openInBrowser;
-(void)removeHistoryItem;

@end
