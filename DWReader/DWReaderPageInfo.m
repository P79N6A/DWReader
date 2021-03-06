//
//  DWReaderPageInfo.m
//  DWReader
//
//  Created by Wicky on 2019/2/13.
//  Copyright © 2019 Wicky. All rights reserved.
//

#import "DWReaderPageInfo.h"

NSInteger const DWReaderPageUndefined = -1;
@interface DWReaderPageInfo ()

@property (nonatomic ,assign) BOOL needsReloadFlag;

@end

@implementation DWReaderPageInfo

+(instancetype)pageInfoWithChapter:(DWReaderChapter *)chapter {
    return [[[self class] alloc] initWithChapter:chapter];
}

-(instancetype)initWithChapter:(DWReaderChapter *)chapter {
    if (self = [super init]) {
        _chapter = chapter;
        _page = DWReaderPageUndefined;
    }
    return self;
}

-(void)setNeedsReload {
    self.needsReloadFlag = YES;
}

#pragma mark --- override ---
-(instancetype)init {
    NSAssert(NO, @"DWReader can't initialize pageInfo with -init.Please use -pageInfoWithChapter: instead.");
    return nil;
}

-(NSString *)description {
    return [NSString stringWithFormat:@"Page range is %@,index is %lu,pageContent is %@",NSStringFromRange(self.range),(unsigned long)self.page,self.pageContent.string];
}
 
@end
