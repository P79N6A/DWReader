//
//  DWReaderPageInfo.h
//  DWReader
//
//  Created by Wicky on 2019/2/13.
//  Copyright © 2019 Wicky. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DWReaderPageInfo : NSObject

///下一页的页面信息
@property (nonatomic ,weak) DWReaderPageInfo * nextPageInfo;

///上一页的页面信息
@property (nonatomic ,weak) DWReaderPageInfo * previousPageInfo;

///绘制范围
@property (nonatomic ,assign) NSRange range;

///当前页码
@property (nonatomic ,assign) NSUInteger page;

///本页需要绘制的富文本
@property (nonatomic ,strong) NSAttributedString * pageContent;

@end

NS_ASSUME_NONNULL_END